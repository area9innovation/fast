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
	-> This leads to commands that set definitions of ids in Mini
	-> Thus, we build the AST for the parsed program in the exp language
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

- Get hello-world to compile and run in JS using "import runtime"
  - __cast, :
  - __ref, __deref
  - array constructor
  - fields: Figure out what to do with the field name. 
    - Is that a string or var? It is probably a construct in Exp
  - struct constructor
  - Figure out natives from runtime & linking
    - fold, isSameStructType
  - Introduce "prerequisite" in Back for 

	public static function fold<T, U>(values : Array<T>, init : U, fn : U -> T -> U) : U {
		for (v in values) {
			init = fn(init, v);
		}
		return init;
	}

	public static inline function isSameStructType(o1 : Dynamic, o2 : Dynamic) : Bool {
		#if (js && readable)
			return !isArray(o1) && !isArray(o2) &&
				Reflect.hasField(o1, "_name") &&
				Reflect.hasField(o2, "_name") &&
				o1._name == o2._name;
		#else
			return !isArray(o1) && !isArray(o2) &&
				Reflect.hasField(o1, "_id") &&
				Reflect.hasField(o2, "_id") &&
				o1._id == o2._id;
		#end
	}



- Get euler examples to compile and run in JS.

- Parse all of flow syntax. Missing:

  - maybe ?? exp : exp, string-include, quoting, string-escapes in AST, forbid
  - require, forbid

- Get type inference to work: 
  - Type declarations are ignored
  - Fix polymorphism recovery
  - Fields, struct and unions
  - Improve type inference

- Rig up file reading and dependency tracking
   - Track declarations per file when file changes
   - Track imports/exports
   - Check imports/exports, undefined names

- Get error messages with locations to work

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

Trailing top-level semi-colon after brace is not allowed:

	foo() {
		...
	};				// foo() { }

We do not support multi-strings:'

	"Hello " "World"	// "Hello World"

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
- Consider a forward-type declaration command to allow "stitching" types declarations
  and definitions together without propagation too much. We can use the type declarations
  map for this.
- Add "desugaring"/"export" checking phase, which might also do the stitching type thing?
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

	<int> inttype			- push an int-type on the stack
	<types> <return> fntype	- push a function type on the stack
	<id> <types> typecall	- push a type call on the stack

	<e1> <e2> <op> binop    - push call(var(op), cons(e2, cons(e1, nil))

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
  subset of JS or Java?

### Async and the Forth standard library

We have a simple standard library of useful Forth definitions defined in forth/lib/lib.forth.

It defines:

	<file> evalfile		   		- read the contents of the given file, and eval each line
	<file> readfile				- read the contents of the given file and push on the stack

Both of these are async, so only use them in the interactive context, or with care.

### TODO Forth primitives

- uncons, comparisons, and, or, not
- ifte, while, eval, map, quoting

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
- Unfolding of expressions into statements (let inside conditions of if)
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

- Fix : to write bools, and ignore in other cases
- Constant lifting (JSON-like values for JS in particular to help reduce memory and startup)

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
