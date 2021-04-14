# Mini

- [Mini](#mini)
	- [Running the compiler](#running-the-compiler)
	- [Compiler Internal Languages](#compiler-internal-languages)
	- [Milestones](#milestones)
	- [Known syntaxs differences](#known-syntaxs-differences)
	- [Backends](#backends)
		- [JS](#js)
		- [Flow](#flow)
- [Internals](#internals)
	- [Pipeline](#pipeline)
	- [Gringo](#gringo)
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
	- [AST representation of control flow](#ast-representation-of-control-flow)
	- [Native fallbacks](#native-fallbacks)
	- [Switch](#switch)
	- [Switch backend](#switch-backend)
	- [How to handle types in the AST](#how-to-handle-types-in-the-ast)
- [Optimizations](#optimizations)
	- [JS runtime](#js-runtime)
- [Appendix](#appendix)
	- [Last known good idea](#last-known-good-idea)
	- [Inspiration](#inspiration)
		- [Query based compilers](#query-based-compilers)
		- [Datalog for typechecking](#datalog-for-typechecking)
		- [Salsa](#salsa)
- [Deleted ids](#deleted-ids)
- [Polymorphism](#polymorphism)
- [Editor DSL](#editor-dsl)
- [ICFP inspiration](#icfp-inspiration)
- [Partial evaluation as a core primitive](#partial-evaluation-as-a-core-primitive)
- [Use cases](#use-cases)
- [New plan](#new-plan)

This is an effort to build a queue-based, always live compiler.

It takes commands, and compiles the result into valid programs.

As files are changed, we can efficiently reprocess them, updating the queue
with changed ids.  It is based on having a database of definitions in memory. 
We track the dependencies between definitions, and as code is changed, we 
efficiently update only the parts that need it.

## Running the compiler

Run with

	flowcpp mini/mini.flow -- file=myprogram.flow

will compile myprogram to js and flow files called out.js and out.flow.

This

	flowcpp mini/mini.flow -- file=mini/tests/test.flow debug=1

will produce a debug trace of how this file goes through the compiler.

If you are interested in only one function, you can use this:

	flowcpp mini/mini.flow -- file=mini/tests/test.flow debug=main

to get a trace of how "main" goes through the compiler.

Similarly, this

	flowcpp mini/mini.flow -- file=myprogram.flow debug=myprogram,main

will debug both main as above, but also how we parse the file "myprogram".

You can limit what phases of the compilation process you want to debug-trace
using the "stages" argument:

	flowcpp mini/mini.flow -- file=mini/tests/test.flow debug=1 stages=parse

and you will only get debug info about parsing.

The stages can be separated by comma. Here is a list of the stages:

	parse     - resolution of includes and parsing
	ct 	      - compile time evaluation. Used to desugar constructs
	type      - type inference and the resulting types
	constrain - track the detailed type constraints build by the type inference
	coalesce  - track how the type constraints are resolved into final types
	lower	  - see how the lowering to typed `BExp` is done

The default stages activated are "parse,ct,type,lower".
If you are debugging type inference problems, then using

	flowcpp mini/mini.flow -- file=mini/tests/test.flow debug=1 stages=type,constrain,coalesce,lower

is a good combination with a lot of details.

TODO:
- Add stage for backend code gen

## Compiler Internal Languages

The compile server is based on these different languages:

- Commands: These provide the interface to the compiler itself to support compiles,
  reading files, and such. This exposes the low-level compilation and dependency 
  handling engine. See `mini/commands/command.flow`. These commands enter a queue
  and are handled in a prioritized way to ensure the correct "threading" of each
  action.
- Forth: This is a Forth interpreter used by the server to construct and manipulate ASTs.
  Since the grammar DSL called Gringo is based on a Forth-language, this is a good fit to 
  allow interfacing the parser with the compile server. See `mini/forth/`.
  Think of this as the Language Server Protocol language to interface with the compiler.
  This is how we can construct, query and manipulate the AST.
- Exp: This is the AST for the program we are compiling. This is an extremely minimal
  AST, in order to keep the compiler as simple as possible. This expresses the programs
  we compile. See `mini/exp/exp.flow`. It is basically the lambda calculus.
- Types: The language comes with type inference for a Flow-like type system. See `mini/types/type.flow`.
- BProgram: This is the fully-typed statement-based backend AST suitable for lots of backends.
  See `mini/backends/bprogram.flow`. This is what comes out of the type checker.
- Back: A mini-DSL used by the backends to produce tight object code. See `mini/backends/back_ast.flow`.
  This is a helping DSL to help manage things like precedence, expressions vs statements, and such.
- Gringo: This is used to define the syntax of languages we compile. See `gringo/readme.md`.

At the moment, the Mini server is a GUI program found in `mini/mini_gui.flow`, and there is a
command line version in `mini/mini.flow`.

TODO:
- Add a more traditional Mini server, with a HTTP-based interface.

## Milestones

The compiler is still in development, and a lot of work remains. To help guide
the development, we have defined some milestones.

- Get tools/flowc/tests examples to compile and run in JS.
  - You can run a set of tests using `flowcpp mini/mini.flow -- test=1-10`
    - Redo __construct to be more like record construction?
      - makerecord(), setrecord(record, id, val)?
	- Specific todos for test cases:
	- 1: Generalize unbound tyvars to typars, or figure out why typars are instantiated
	  maybeBind has wrong type.
	- lambdaarg does not capture type parameters defined in lambdas!
    - 5, 7: intersection typing. We should do a collection of requirements
	- 6, 28: ? and ??
	- 8, 13, 14: intersection and union typing galore
	- 9, 24: double vs ?, . typing
	- 9: Implicit polymorphism for maybeMap
	- 17: mutable struct fields
	- 26, 27, 30: __construct5 is unknown
	- 21: Somehow we end up with a tyvar as an upper bound.
  - Figure out natives from runtime & linking

- Parse all of flow syntax. Missing:

  - string-include, quoting, string-escapes in AST
  - types for lambda args
  - positions on if, types, ...
  - require, forbid
  - Optimizations possible in generated Gringo parser: 
    - Use && instead of nested ifs
    - Change NOT to be a sequence
	- Epsilon is probably correctly compiled to TRUE
	- Add a BExp backend for DOpCode, and add a C++ or Rust backend for BExp
      and try to use Wasm
	- Consider to make // and /* an operator in some contexts to capture them

- Get sandbox/hello.flow to type

- Get type inference to work: 
  - Fields, struct and unions
  - Improve type inference

- Rig up file reading and dependency tracking
   - Track declarations per file when file changes
   - Track imports/exports
   - Check imports/exports, undefined names

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

	nop : (() -> void); 	// nop : () -> void;

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
  Consider whether this should be a "warning" instead based on a lint-style flag?

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
- https://c9x.me/compile/ backend?

Languages to add:
- Java
- C
- C++
- Rust
- Wasm
- Rescript/Ocaml: https://medium.com/att-israel/how-i-switched-from-typescript-to-rescript-637aa5ef8d3

### JS

We have a JS backend.

TODO:
- Constant lifting (JSON-like values for JS in particular to help reduce memory and startup)
- Move builtin natives to a .js file with comments, or something, which is the processed to define
  the backends - stripping newlines and stuff?
- Add compiling & linking with Haxe runtime

### Flow

We have a minimal Flow backend. This is mostly for testing. Does not really work.

# Internals

## Pipeline

This diagram illustrates the processing pipeline in the compiler:

	Source file in flow (later, hopefully also other high level languages)
	-> This file content is read by Mini (if changed)
	-> This is parsed by a Gringo parser for Flow defined in `exp/flow.gringo` 
	-> This results in a bunch of Forth commands evaluated in Mini to build the AST
	-> These leads to commands that set definitions of ids in Mini (declarations, unprocessedAnnotations)
	-> Thus, we build the AST for the parsed program in the exp language (MiniPopFile updates annotations, result is `mini/exp/ast.flow`)
	-> Once all dependent files of a file are parsed, we partially evaluate all ids at compile time `mini/interpreter/partial.flow`
	-> The resulting definitions are typed by the type inference and checker in topological order (typecheckMiniTypes in `types/type_check.flow`)
	-> We lower the program to a fully typed BExp representation
	-> We run optimizations of the AST
	-> We lower this to BProgram with statments for the backends
	-> We generate code in the backends
	-> The result is written as files for the final output

The key point is that we are incremental at the id level, so if there is no
change in an id, even if we parse the file again, we do not have to redo all
dependents on that id. This should hopefully speed things up.

## Gringo

Gringo is a new parser, similar to Lingo, just with better performance, easier handling
of associativity and precedence. See `flow9/tools/gringo/readme.md` for now info.

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
- Add "export" checking phase
- Command to define what files to compile to what, with what options
- Command to run executables we have constructed
- Run the commands in the queue in parallel

## Mini Forth

Mini Forth is used to construct the AST. The semantic actions in Gringo grammar
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

	x y z rot -> y z x   // p231
	1 2 3 rot2 -> 3 1 2  // p312 or rot rot
	1 2 3 4 p2134 -> 2 1 3 4 // Some nice permutation

	x y dup2 -> x y x y
	x y z dup3 -> x y z x y z
	w x y z dup4 -> w x y z w x y z


### Misc

	x print ->
	x y debug -> x y 
	x y dump -> x y

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
- Consider adding other syntaxes, just to demonstrate the multi-headed nature of Mini. Maybe a
  subset of JS or Java or ML?

### Async and the Forth standard library

We have a simple standard library of useful Forth definitions defined in forth/lib/lib.forth.

It defines:

	<file> evalfile		   		- read the contents of the given file, and eval each line
	<file> readfile				- read the contents of the given file and push on the stack

Both of these are async, so only use them in the interactive context, or with care.

### TODO Forth primitives

We could add more Forth primitives if we wanted to do more advanced AST manipulation.

- uncons, comparisons, and, or, not
- ifte, while, eval, map, quoting

## AST representation of control flow

We use the `MiniCall` AST type which correspond to calls to special functions to represent various semantic 
constructs such as switch, cases, if-statements and so forth in Mini. The benefit of this approach is that 
the MiniExp is minimal, and type inference does not need to know anything special about these constructs. 
That makes the compiler infrastructure much smaller.

See `interpreter/partial.flow` and `types/builtins.flow` for the list.

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
	, is used for array constructs, with semantics like arrayPush
	__index is used for array indexing

	__ref constructs a reference
	__deref dereferences a reference value
	:= is used to update references

	__construct0, ... N for constructing struct values with N arguments
	. is used for field access with the field name as a string
	__structname to extract the id of a struct to be able to "switch" from

TODO:
	__with & __withassign
	__mutassign

Struct definitions are represented by constructing a constructor function by the Forth
builtin structdef, that uses __construct0, ... to construct the value.

Union definitions are represented by a function, which extract the id field to switch from.
This is done by the uniondef Forth builtin.

## Native fallbacks

Natives are registered as annotations while parsing. At post-file processing, we check
if the natives have a fallback. If so, we wrap the native definition with the fallback.
If not, we just keep the native definition.

	native i2s : (int) -> string = Native.i2s;
	i2s(i) { cast(i : int -> string); }

The backends can then provide a native implementation, and automatically pick whether to
use one of the other.

## Switch

We expand let-bindings in cases in the compile-time step by partially evaluating the __ctcase
function accordingly.

Similarly, we expand a ?? b : c to a switch at compile time to a switch.

TODO:
- Union-match: This requires knowing the unions, as well as the entire scope of the switch
- Exhaustiveness check of switch

## Switch backend

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

Using `BSwitch`, we produce this in Mini:

	switch(s._id) {
		case "None": return 0;
		case "Some": return s.value;
	}

## How to handle types in the AST

The "__type" function is used to represent types in the AST. This is explicitly converted to
types by the type inference as required in the ast. Type annotations are defined using the
":" function that takes a type on the right-hand side.

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

See `types/type_ast.flow` for the details.

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

We have a function, which converts an MiniExp to a type in the `types/type_ast.flow` file.
This encodes the convention for how to represent types as values.

# Optimizations

Memory is the most important one, it seems. Therefore, we would like to add some special things
to help optimize this.

TODO:
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

- Use typed arrays for arrays of ints?

## JS runtime

According to this benchmark:

https://jsben.ch/wY5fo

This is the fastest way to iterate an array in JS:

	var x = 0, l = arr.length;
	while (x < l) {
		dosmth = arr[x];
		++x;
	}

Consider to add `while` and mutable variables to BExp or Back, so we could explicitly represent this.

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

# Deleted ids

How to handle deleted ids and updated annotations?

We probably need a stack of files being processed, and some way to notice that a file has finished,
and then we can clean up old ids. Also, when we start processing a file, we should clear out the
annotations.

TODO: How to keep track of the annotations on an id, when we need to compare?
Should we have a "final" map of annotations on an id when we define it? Yeah, probably we should.

# Polymorphism

When we have top-level polymorphism, it is tracked by 
having a type declaration in the types with typars.

When we do inference of such a thing, we keep them as ?.

When we reference a polymorphic name, it should be instantiated.

# Editor DSL

Idea:

DataStructure -> SDF for structure and SDF for editing
SDF for structre -> DataStructure

Thus, the general editor is implemented to work with a pair of SDFs.
One for the view on the screen, and another for the logical structure of
the document.

Needs:
- Convert XY coordinates to logical placements.
- Move elements as sizes change.

Idea:
Make the placements expressions, and do calculations. So we have "lazy" variables
that can be calculated when needed.

OK, so the challenge is to map XYZ coordinates with variables inside to logical structures.

Use cases:

Prime:
Layers <-> max(circle, box)		<->  [0]
	Circle <-> x,y, radius, z
	Box <-> x,y, w,h, z
		Text <-> (parent.x + parent.w) / 2 - width(text) / 2,
				(parent.y + parent.h) / 2 - height(text) / 2, z

Flow:
Let
	a
	1
	+		
		var
			a
		int
			5

OK, so constraint expressions can model the coordinates.

Figure out how to model the hierarchy better, since there is a general pattern there.

http://citeseer.ist.psu.edu/viewdoc/download;jsessionid=7A46C494B2AD29E41B6E718CBE5741F0?doi=10.1.1.101.4819&rep=rep1&type=pdf

Insight: Instead of modelling each component separately, have the entire tuple as one expression.

Next insight: We can collect these in a data structure with bounds. There is a library here:

https://github.com/mourner/rbush/blob/master/index.js

TODO:
- Add hierarchy to allow decomposition. I guess we can have recursive trees, and get it that way.
- Make bounds lazy somehow
- How to use:
  - Port to flow, and compile to WASM? A lot of JS voodoo is used, so not easy
  - Wrap as natives - much easier

So we have an efficient way to just send in a bunch of rectangles, and get only those visible rendered.

Next idea:

- Using LValues and reducers, we can maybe use that as the interface for a common editor.

# ICFP inspiration

Partially invertible programs:
- Try to define a DSL of partially invertible functions, which can be used by reducers,
  and then we have invertible reducers. TODO: Figure out what constructs these are.
https://www.youtube.com/watch?v=J2zBTIvCt5U&list=PLyrlk8Xaylp6vEeTa5x55uTH7HjowtGkR&index=3

Holes in programs:
- Using "holes" in program, or data, maybe we can express editors with this construct.
- Holes can be filled out from examples.
https://www.youtube.com/watch?v=WQ1qkrbzLfM&list=PLyrlk8Xaylp6vEeTa5x55uTH7HjowtGkR&index=43
Use: Holes seem to be relevant to an editor of strongly typed data, where we have missing
data in constructs.

Demand-driven evaluation:
- A kind of "backwards" evaluation which can construct a "slice" of a program by evaluation
  from the result backwards.
https://www.youtube.com/watch?v=r0VCdof0tnU&list=PLyrlk8Xaylp6vEeTa5x55uTH7HjowtGkR&index=2
Potential use: Maybe this can be used to only evaluate the parts of the document view that are required?
A different way of doing lazy evaluation.

Linear types and kinds:
https://www.youtube.com/watch?v=YD7ONuMyoyk&list=PLyrlk8Xaylp6vEeTa5x55uTH7HjowtGkR&index=9
Potential use: How to mix GC and linear memory management in the type system. This would
allow us to define types and functions are linear, and thus have explicit, but automatically
inferred memory management.
Requires that we use explicit memory management in JS for data there for the data of these
types. The umbrella repo has some code to help support that.


Halide-style rewriting rules:
https://www.youtube.com/watch?v=ixuPI6PCTTU&list=PLyrlk8Xaylp6vEeTa5x55uTH7HjowtGkR&index=7
- Defines two languages for high-performance code. One for calculations, and another for
  rewriting optimizations.
https://dl.acm.org/doi/pdf/10.1145/3408974
Potential use: Optimize reducers using something like this.
- Figure out what relation between reducers and RISE is. RISE compiles to MLIR, and maybe
  there is a way to bind these things together.

https://www.youtube.com/watch?v=kIHt_xoFh74&list=PLyrlk8Xaylp6vEeTa5x55uTH7HjowtGkR&index=15
How to automatically splice a program into client/server parts, and handle communication
automatically. Links uses server/client annotations. This is similar to Fastlåst.

https://www.youtube.com/watch?v=rQ3XeBh54zQ&list=PLyrlk8Xaylp6vEeTa5x55uTH7HjowtGkR&index=18
Data structure for trees with N elements based on a binary decomposition of N, where each
bit gets a corresponding tree with that number of elements.

https://www.youtube.com/watch?v=MUcG9LwQrJA&list=PLyrlk8Xaylp6vEeTa5x55uTH7HjowtGkR&index=26
CRDT DSL: Using distributive laws to fix conflicts. Result is compositional CRDTs.
https://crdt.tech/
https://arxiv.org/pdf/2004.04303.pdf

Special case

if (isSameStructType()) somehow


# Partial evaluation as a core primitive

https://github.com/mrakgr/The-Spiral-Language

Two layered, staged language.
The first is dynamically typed, partial evaluation based.
The second is ML, statically typed.

It has two constructs:
- dyn which marks a variable to exist in the output produced by the compiler
- join, which marks an expression hich should be lifted into a function
  to be produced by the compiler

This is easy to add to Mini, since it already has a partial evaluator.

First test case is to use this to make reducers and rvalues efficient in
real life.



# Use cases

- Morris-prath
- Deforestation af reducere
- DSL kode genering, f.ex. gringo
- Regex.
- Pattern matching
- inline fastlåst
- Wasm target
- Flowschema
- SQL
- Master key
- Gringo, so we can do compile time parsing and evaluation
	c via wasm
	Typescript
- async/await lifting - client/server

- frp lifting

- Basic

New DSLs to define Curator:
- Workflow
- Dataschema/flowschema and master-key
- Reporting
- Users and roles
- Converters
- Translation
- Tasks/communication

# New plan

The Forth stuff is too complicated.
The restriction of the mini-lambda in the entire compiler is too untyped.

1. Have complete AST after parsing, using typed Gringo grammar.
   
   PExp = Parsed Expressions

   TODO:
   - Populate positions correctly

2. Once files and dependents are parsed, desugar the program to DExp:

   DExp = Desugared Expressions

3. Once dependencies are desugared, do type inference

   TExp = Typed Expressions

4. Then plug into the backends.


# Rewrite syntax

flow-exp: $id = $val; $body
=>
js-statement: 
var $id = $val(100);
$body

flow-exp: $l + $r
=>
js-exp: $l(100) + $r(99)

# Type inference

Use the egraph over types and tyvars.
Use lower/upper types as from
https://gilmi.me/blog/post/2021/04/13/giml-typing-polymorphic-variants

