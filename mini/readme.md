# Mini

- [Mini](#mini)
	- [Mini Server](#mini-server)
	- [Pipeline](#pipeline)
	- [Milestones](#milestones)
	- [Known syntaxs differences](#known-syntaxs-differences)
	- [Mini Commands](#mini-commands)
	- [Mini Forth](#mini-forth)
		- [Values](#values)
		- [Common stack operations](#common-stack-operations)
		- [Misc](#misc)
		- [Arithmetic](#arithmetic)
		- [String](#string)
		- [List](#list)
		- [AST](#ast)
		- [Forth Evaluation](#forth-evaluation)
		- [Compile server commands](#compile-server-commands)
		- [Gringo grammars](#gringo-grammars)
		- [Async and the Forth standard library](#async-and-the-forth-standard-library)
		- [TODO Forth primitives](#todo-forth-primitives)
	- [AST representation of various constructs](#ast-representation-of-various-constructs)
	- [Backends](#backends)
		- [JS](#js)
		- [Flow](#flow)
- [Optimizations](#optimizations)
- [Appendix](#appendix)
	- [Last known good idea](#last-known-good-idea)
	- [Inspiration](#inspiration)
		- [Query based compilers](#query-based-compilers)
		- [Datalog for typechecking](#datalog-for-typechecking)
		- [Salsa](#salsa)
- [How to handle types in the AST](#how-to-handle-types-in-the-ast)
- [Native fallbacks](#native-fallbacks)
- [Deleted ids](#deleted-ids)
- [Switch](#switch)
- [Switch backend](#switch-backend)
- [Native runtime](#native-runtime)
- [Polymorphism](#polymorphism)

This is an experiment to build a queue-based, always live compiler.

It takes commands, and compiles the result into valid programs.

As files are changed, we can efficiently reprocess them, updating the queue
with changed ids.  It is based on having a database of definitions in memory. 
We track the dependencies between definitions, and as code is changed, we 
efficiently update only the parts that need it.

## Mini Server

The compile server is based on these different languages:

- Commands: These provide the interface to the compiler itself to support compiles,
  reading files, and such. This exposes the low-level compilation and dependency handling engine.
- Forth: This is a Forth interpreter used by the server to construct and manipulate ASTs.
  Since the grammar DSL Gringo is based on a Forth-language, this is a good fit to allow 
  interfacing the parser with the compile server.
  Think of this as the Language Server Protocol language to interface with the compiler.
- Exp: This is the AST for the program we are compiling. This is an extremely minimal
  AST, in order to keep the compiler as simple as possible. This expresses the programs
  we compile.
- Types: The language comes with type inference for a Flow-like type system.
- BProgram: This is the fully-typed statement-based backend AST suitable for lots of backends.
- Back: A mini-DSL used by the backends to produce tight object code
- Gringo: This is used to define the syntax of languages we compile

At the moment, the Mini server is a GUI program found in `mini/mini_gui.flow`.

TODO:
- Add a more traditional Mini server, with a web-based interface.

## Pipeline

This diagram illustrates the processing pipeline:

	Source file in flow or other high level language
	-> This file is read by Mini if changed
	-> This is parsed by a Gringo parser for Flow
	-> This results in a bunch of Forth commands evaluated in Mini
	-> This leads to commands that set definitions of ids in Mini (declarations, unprocessedAnnotations)
	-> Thus, we build the AST for the parsed program in the exp language (MiniPopFile updates annotations)
	-> These definitions are typed by the type inference and checker in topological order
	-> We run optimizations of the AST
	-> We lower the AST to BProgram for the backends
	-> We generate code in the backends
	-> The result is written as files, linked and processed for the final output

The key point is that we are incremental at the id level, so if there is no
change in an id, even if we parse the file again, we do not have to redo all
dependents on that id. This should hopefully speed things up.

## Milestones

The compiler is still in development, and a lot of work remains. To help guide
the development, we have defined some milestones.

- Get tools/flowc/tests examples to compile and run in JS.
  - Add mode which runs all
    - 5, 7: intersection typing
	- 6, 28: ? and ??
	- 8, 13, 14: intersection and union typing galore
	- 9, 24: double vs ?
	- 9: Implicit polymorphism for maybeMap
	- 17: mutable struct fields
	- 26, 27, 30: __construct5 is unknown
  - Figure out natives from runtime & linking

- Parse all of flow syntax. Missing:

  - string-include, quoting, string-escapes in AST
  - require, forbid
  - Optimizations possible in parser: 
    - Use && instead of nested ifs
    - Change NOT to be a sequence
	- Epsilon is probably correctly compiled to TRUE
	- Add a BExp backend for DOpCode, and add a C++ or Rust backend for BExp
      and try to use Wasm
	- Consider to make // and /* an operator in some contexts to capture them

- Get type inference to work: 
  - Fields, struct and unions
  - Improve type inference

- Rig up file reading and dependency tracking
   - Track declarations per file when file changes
   - Track imports/exports
   - Check imports/exports, undefined names

- Get error messages with locations to work

- Introduce "options" for strict polymorphism, flow-type, etc. for language variations

- Mark code in the compiler that is specific to flow somehow, so we can abstract the core
  out of the main part.

- Add jupyter-style notebook feature and "resident" icon for the compiler

## Known syntaxs differences

The grammar used in Mini is a bit different from the flow grammar. In particular,
the ";" symbol is now a binary operator, and that means it is required in more places.

Here, we need a semi-colon after the `if` in the sequence:

	if (true) 1 else { 1 + 2}	// ; required here
	c;

	if (true) { 1 }	// ; required here
	c;

Also need it after switch:

	a = switch (b) { ... }		// ; required here
	c

And after local lambdas:

	a = \ -> { ... }			// ; required here
	c

Parenthesis around types are not supported:

	a : (int); 	// a : int;

Functions with only some args named is not supported. 
We want all args to have names:

	f(int, b : int) -> {		// f(a : int, b : int)
		...
	}

Let-bindings without a body is not supported:

	foo() { a = b; }		// expect something after: a=b;a

Parenthesis required for assignment lambdas:

	fn := \ -> foo;		// fn := (\ -> foo);

Trailing top-level semi-colon after brace is not allowed:

	foo() {
		...
	};				// foo() { }

We do not support multi-strings:'

	"Hello " "World"	// "Hello World"

TODO:
- Add a mode which adds the missing semi-colons based on the error-recovery in the grammar

## Mini Commands

The compiler internally supports a range of commands (see `commands/command.flow`)
which are processed in a queue:

	// Read a file and push it on the stack and run this Forth command on it
	ReadFile(name : string, command : string);

	// Define this id to this expression (with the origin file)
	Define(file : string, name : string, value : MiniExp);

	// Infer the type of these ids, since they are new or changed
	TypeInfer(ids : Set<string>);

These are evaluated by the compile server, and used to do the raw reading
and compiling of programs. The key point about these commands is that they
understand dependency tracking, and thus do not propagate any changes unless
there is something to do.

The compile server is smart enough to know the relative priority of these
commands, so we will not do type inference if there are pending files to be
read and parsed.

TODO:
- Add ""export" checking phase
- Command to define what files to compile to what, with what options
- Command to run executables we have constructed
- Run the commands in the queue in parallel

## Mini Forth

Mini Forth is primarily used to construct the AST. The semantic actions in Gringo grammar
files are written in Mini Forth.

The values in this Forth correspond to the values in the Mini expression language.
Besides providing the stack, macros and Forth definitions, this Forth also serves 
as the interface to the compile server itself through special commands.

### Values
	
	1						- push an int on the stack
	3.141					- push a double on the stack
	"hello world"			- push a string on the stack

### Common stack operations

	nop ->
	x drop ->
	x dup -> x x
	x y swap -> y x
	x y z rot -> y z x
	x y dup2 -> x y x y

### Misc

	x print ->
	x y debug -> x y 

	// Comment is ignored

### Arithmetic

	x y + -> x+y
	x y - -> x-y
	x y * -> x*y
	x y / -> x/y
	x y % -> x%y

### String

	<string> length -> <int>
	<string> <int> getchar -> <string>
	<string> <int> getcode -> <int>
	<string> s2i -> <int>
	<int> i2s -> <string>
	<string> s2d -> <double>
	<double> d2s -> <string>
	<string> parsehex -> int
	<string> <string> + -> <string>
	<file> <ext> changeFileExt -> <string>

### List

Lists are "Cons"-based, single-linked, functional lists, a la List<> in Flow, although they
are represented in the exp language as a sequence of calls to cons and nil functions.

	nil						- push the nil token on the stack
	<list> <elm> cons		- push a list elm:list on the stack
	<elm1> list1			- push cons(elm1, nil)
	<elm1> <elm2> list2		- push cons(elm2, cons(elm1, nil))
	<list> isnil   -> 0/1   - 1 if the list is nil, 0 otherwise

### AST

These commands build up the AST for the program to compile. The idea is to construct the AST
value, and then use "define" to commit the definition to the compile server.

	<string> var			- push a var ref on the stack
	<id> <val> <body> let	- push a let-binding on the stack
	<args> <body> lambda	- push a lambda on the stack
	<fn> <args>	call		- push a call on the stack

	<id> type0				- push an named type on the stack
	<type> <id> type1		- push an named type with one arg on the stack
	<types> <return> fntype	- push a function type on the stack
	<id> <typars> typename	- push a typename on the stack

	<id> <args> structdef	- push a struct type definition on the stack
	<id> <typars> 
	  <typenames> uniondef	- push a union type definition on the stack

	<e1> <e2> <op> binop    - push call(var(op), cons(e2, cons(e1, nil))

	<scope> <annotation> <value> 
			setannotation   - defines an annotation of the id in the scope

### Forth Evaluation

	<string> evallines  	- evaluates each line in this string as a separate command
	def <id> <commands>		- defines a new word as this sequence of commands separated by space

### Compile server commands

	<file> <command> processfile
        - reads the content of the given file and once read, push it on the stack and 
          runs "command" on it. This is only done if the file is changed compared to last time
		  we read it.
    	  Notice this is "async", so whatever follows processfile will run immediately after
		  this command, WITHOUT the file content on the stack. Also, the callback command will run
		  a different stack in the second run. Use with care!

	<name> <val> define		    - define a top-level name in the program

### Gringo grammars
	<id> <grammar> prepare
    	- prepares the given Gringo grammar as a new builtin which can parse files with that grammar

	prepexp
		- prepares the expression parser "parseexp" for parsing flow

TODO: 
- Fix parsing the command line to allow spaces in strings, otherwise, it is pretty hard to test.
- Document how to write a Gringo grammar with semantic actions, maybe implement Basic?
- Consider adding other syntaxes, just to demonstrate the multi-headed nature of Mini. Maybe a
  subset of JS or Java or ML?

### Async and the Forth standard library

We have a simple standard library of useful Forth definitions defined in forth/lib/lib.forth.

It defines:

	<file> evalfile		   		- read the contents of the given file, and eval each line
	<file> readfile				- read the contents of the given file and push on the stack

Both of these are async, so only use them in the interactive context, or with care.

### TODO Forth primitives

- uncons, comparisons, and, or, not
- ifte, while, eval, map, quoting

## AST representation of various constructs

We use calls to special functions to represent various semantic constructs in Mini. The benefit of this
approach is that the MiniExp is minimal, and type inference does not need to know anything special about 
these. That makes the compiler infrastructure easier and smaller.

See `types/builtins.flow` for the list.

The following are converted to more natural constructs by the lowering phase, so backends do not have to know 
about them:

	__ifte & __ift are used for if-else and if
	; is used for sequence
	:(e,type) is used for type annotations, with the type encoded as a string of calls to __type like functions

	__native is used for defining native functions

	__cast(:(e, from-type),to-type) is used for casts. These are converted to __i2s, __i2d, __d2s & __d2i for
	those casts. The rest remain as "__cast" for the backends.

	__void is the empty value. TODO: Maybe this should disappear in the lowering?

These have to be implemented in the backends to do the right thing:

	__neg  is used for prefix negation of int/double

	__emptyarray is used for the empty array
	[ is used for array constructs, where the arguments are separated by the "," operator
	__index is used for array indexing

	__ref constructs a reference
	__deref dereferences a reference value
	:= is used to update references

	__construct0, ... N for constructing struct values with N arguments
	. is used for field access with the field name as a string
	__structname to extract the id of a struct to be able to "switch" from

TODO:
	__switch 
	__case 
	__pattern  
	__default  
	__with  
	__fieldassign

Struct definitions are represented by constructing a constructor function by the Forth
builtin structdef, that uses __construct0, ... to construct the value.

Union definitions are represented by a function, which extract the id field to switch from.
This is done by the uniondef Forth builtin.

The __type function is handled by the type inference explicitly to extract the type.

## Backends

The backends are based on the BProgram representation, which makes them minimal.

Besides working on a suitably, fully-typed AST, we also provide a mini-DSL called
Back, which can be used to implement the basic operators and simple natives.

TODO:
- Prefix operators with precedence and limited overloading
- Types
- Keyword renaming, namespace for languages that need that
- Constant propagation
- Dead-code elimination
- Lift first-order functions to top-level?
- Have first-order representation ready for C, Java, Wasm where they are needed
- Inlining
- Mangling of overloading?
- Specialization of polymorphism
- Linking
- Running the output
- Cross-calls

Languages to add:
- Java
- C
- C++
- Rust
- Wasm

### JS

We have a minimal JS backend.

- Constant lifting (JSON-like values for JS in particular to help reduce memory and startup)
- Move natives to a .js file with comments, or something, which is the processed to define
  the backends - stripping newlines and stuff?

### Flow

We have a minimal Flow backend.

# Optimizations

Memory is the most important one, it seems:

Add a warning to the compiler if we capture too big a closure. I.e.

	Foo(a : [int], b : bool);

	foo(foo : Foo) {
		timer(1000, \ -> {
				println(foo.b);
		})
	}

	main() {
		foo(Foo(generate(0, 1000000), false));
	}

Use typed arrays for ints?

# Appendix

## Last known good idea

A key idea is to preserve OLD versions of declarations at the last stages, until a new
one is ready to take over. That way, we will not accept new versions of code until all
type errors have been resolved in that part of the code.

The hope is that we will always have a continuous definition of running program.
So nomatter what state your source code is in, we in principle have a working program,
since we will keep the oldest, known good version of all that go together, and will use 
that for outputs.

The idea is to allow live coding at a new level. As you type, the outputs are continously
being recompiled and if you have no errors, the result should run. We still maintain
the property that all outputs correspond to a fully type checked program. Yes, it can be
a strange mix of code from different points in time across different files, but it will
be consistent.

Also, we still maintain the property that if all type errors are fixed, all outputs will
correspond to the current, latest version of the code.

For each item in a queue, we have a set of dependencies for it. We might have to give new 
ids for the last known good declarations, so we can juggle with multiple versions of the 
same code.

## Inspiration

### Query based compilers

https://ollef.github.io/blog/posts/query-based-compilers.html

They base the compiler on a system called Rock, which is essentially like "make".

There is cache per query of the type Key -> Task Value, where Task defines the build
system rules Key is "Parsed module", "Resolved module", "Typed module", and such.

The dependencies of each task is tracked using keys. 

It is important that dependencies are bi-directional, so when a key is changed, we
can force cache eviction of the changed queries.

Thus, the compiler is composed of functions of the form	Key -> Value, where we have
two kinds of queries: Inputs, and pure functions.

### Datalog for typechecking

https://petevilter.me/post/datalog-typechecking/
- Has a "database" of atoms.
	data Atom = Atom { _predSym :: String, _terms :: [ Term ] } deriving Eq
  which is basically structs

These can be pattern-matched using "prolog".

There is an encoding of the AST in terms of structs.
They use ids for each node, to allow references that way.
This is a way to avoid "nested" matching.

### Salsa

https://github.com/salsa-rs/salsa
https://www.youtube.com/watch?reload=9&v=_muY4HjSqVw&feature=youtu.be

Identify the "base inputs": Source files or similar.

Identify the "derived values". Pure, deterministic functions.
- AST from source file
- "Completion" from source file at given place

For derived values, track:
- What inputs did we access to calculate something?
- Which derived values did we use?

So we need to have a way to identify inputs, and another way to identify derived
values.

When an input changes:
- Propagate all the way through the dependency graph.

Key concepts:

Query:
- Functions to be continually calculated

Database:
- All the internal state

# How to handle types in the AST

We express types as expressions like this:

- void  	__type("void")
- bool		__type("bool")
- int		__type("int")
- double	__type("double")
- string	__type("string")
- flow		__type("flow")
- native	__type("native")
- ref T		__type("ref", T)
- [T]		__type("array", T)
- ?			__type("?")
- S<T, T>	__type(S(T, T))
- () -> T	__fntype(T)
- (T) -> R	__fntype(R, T)

Unions are stored in the AST in the unions field.

  a : T		 __fieldtype(a, 0, T)
  mutable a : T	__fieldtype(a, 1, T)
  { ... }    __recordtype(,,,)

The use in the grammar is isolated to a few areas:
- The ":" operator	-> :(exp, __type())
- Forward declarations of globals and functions -> Forward declarations to types in AST
- Lambda arguments   -> a ":" on the lambda
- Cast				 -> a call and ":" on the right hand side.
- Structs            -> Structs are considered as constructor function declaration.
- Unions			 -> Unions to be modelled as forward type declarations. 
					    Consider to have a function which takes a union and returns the id?

Forwards declarations can be stored in the MiniAst.types field.

We have a function, which converts an MiniExp to a type in the types/type_ast.flow file.
This encodes the convention for how to represent types as values.

Plan:
- Use "forward" in the grammar and check that it works

# Native fallbacks

Natives are registered as annotations while parsing. At post-file processing, we check
if the natives have a fallback. If so, we wrap the native definition with the fallback.
If not, we just keep the native definition.

	native i2s : (int) -> string = Native.i2s;
	i2s(i) { cast(i : int -> string); }

The backends can then provide a native implementation, and automatically pick whether to
use one of the other.

# Deleted ids

How to handle deleted ids and updated annotations?

We probably need a stack of files being processed, and some way to notice that a file has finished,
and then we can clean up old ids. Also, when we start processing a file, we should clear out the
annotations.

TODO: How to keep track of the annotations on an id, when we need to compare?
Should we have a "final" map of annotations on an id when we define it? Yeah, probably we should.

# Switch

We expand let-bindings in cases in the compile-time step by partially evaluating the __ctcase
functino accordingly.

Similarly, we expand a ?? b : c to a switch at compile time to a switch.

TODO:
- Union-match: This requires knowing the unions, as well as the entire scope of the switch
- Exaustiveness check

# Switch backend

This part is done. This is what is produced in JS by flowc:

	function(){
		var s$;
		if (s._id==0){
			s$=0
		} else {
			s$=(function(){
				var v=s.value;
				return v;
			}())
		}
		return s$;
	}()

With the BSwitch, we can produce this:

	switch(s._id) {
		case "None": println("None"); break;
		case "Some": println("Some"); break;
	}

# Native runtime

According to this benchmark:

https://jsben.ch/wY5fo

This is the fastest way to iterate an array in JS:

	var x = 0, l = arr.length;
	while (x < l) {
		dosmth = arr[x];
		++x;
	}


# Polymorphism

When we have top-level polymorphism, it is tracked by 
having a type declaration in the types with typars.

When we do inference of such a thing, we should probably
keep them as ?.

When we reference a polymorphic name, it should be instantiated.
