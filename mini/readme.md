# Mini

This is an experiment to build a queue-based, always live compiler.

It takes commands, and compiles the result into valid programs.

As files are changed, we can efficiently reprocess them, updating the queue
with changed ids.  It is based on having a database of definitions in memory. 
We track the dependencies between definitions, and as code is changed, we 
efficiently update only the parts that need it.

## Mini Server

The compile server is based on these different languages:

- commands: These provide the interface to the compiler itself to support compiles,
  lookups and similar (think of this as a Language Server Protocol)
- forth: This is a Forth interpreter used by the server to construct and manipulate ASTs.
  Since Gringo is based on a Forth-language, this is a good fit to allow interfacing the
  parser with the comple server.
- exp: This is the AST for the program we are compiling. This is an extremely minimal
  AST, in order to keep the compiler as simple as possible
- types: The language comes with type inference for a Flow-like type system

Later, we will add:
- Gringo syntax
- Runtime for forth
- Runtime for exp, where we define the types for ==, +, -, etc.

## Mini Commands

The compiler supports a range of commands (see `commands/command`):

	// Read a file and push it on the stack
	ReadFile(name : string);

	// Read this file and run it
	Filename(name : string);

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
- Re-do the file interface so that we can have a Forth program to run
  after reading a file

## Mini Forth & command interface

The interface to the compiler is modelled as a Forth. Using this language,
Mini takes commands, using a stack to pass arguments where required. Some
commands have access to the compiler commands:

	<name> <val> define		- define a top-level name in the program
	<file> readfile			- read the contents of the given file
	<file> import			- read the contents of the given file, and eval each line
						      (todo: this should probably be renamed, since it works on Forth)

## Mini Forth

Values:

	1						- push an int on the stack
	3.141					- push a double on the stack
	"hello world"			- push a string on the stack

Common stack operations:

	x drop ->
	x dup -> x x
	x print ->
	x y swap -> y x
	x y z rot -> y z x
	x y dup2 -> x y x y

In addition, we support common int/double operations:

	x y + -> x+y
	x y - -> x-y
	x y * -> x*y
	x y / -> x/y
	x y % -> x%y

String:

	<string> length -> <int>
	<string> <int> getchar -> <string>
	<string> <int> getcode -> <int>
	<string> s2i -> <int>
	<int> i2s -> <string>
	<string> <string> + -> <string>

AST:
	<string> var			- push a var ref on the stack
	<id> <val> <body> let	- push a let-binding on the stack
	<args> <body> lambda	- push a lambda on the stack
	<fn> <args>	call		- push a call on the stack

	<int> inttype			- push an int-type on the stack
	<types> <return> fntype	- push a function type on the stack
	<id> <types> typecall	- push a type call on the stack

	nil						- push the nil token on the stack
	<list> <elm> cons		- push a list elm:list on the stack

TODO:
- Add "<grammar-file> parse"

## Example compile queue

Example compile flow:

	1. Compile "mini/tests/test.mini"
	2. The file is read, each line is pushed to the compiler
	3. The definitions are added
	4. Then we type check these definitions, and if the batch passed, we push it to the last known good
	5. Then we produce outputs for each output defined

## Milestones

- Add "def" and quoting to allow defining commands.
- Change "import" to be strsplit and then unquote/eval on each
- Get Gringo to parse files read, so we can send in any syntax
- Get type inference to work. Plug the coalescing in?

- Get hello-world to compile to JS
  - consider doing a statement-based intermediate AST

- Rig up file reading and dependency tracking
   - Update declarations per file when file changes (size/timestamps/md5)
   - Track imports/exports
   - Check imports/exports, undefined names

- Get error messages with locations to work

- Add jupyter-style notebook feature and "resident" icon for the compiler

## Backends

Maybe we can do them just like functions in Fastlåst.

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
