# Fastlåst

The goal of Fastlåst is to allow all languages and platforms to work well together.

It is an impossible goal. There are so many languages and so many aspects of programming to 
consider, and there are trade offs to make in each individual integration that cannot be automated. 
But Fastlåst lays out a path towards that goal, which is hopefully practical and also useful 
in the shortish term.

Currently, it is still alpha, but it shows some interesting promise.

- [Fastlåst](#fastlåst)
	- [Introduction](#introduction)
		- [Usage](#usage)
		- [Alternative pitches](#alternative-pitches)
		- [Meta thoughts](#meta-thoughts)
		- [Status](#status)
		- [Potential next goals](#potential-next-goals)
	- [The Fastlåst Language](#the-fastlåst-language)
		- [Syntax](#syntax)
		- [Type system](#type-system)
		- [Language backends](#language-backends)
		- [Multi-language syntax](#multi-language-syntax)
		- [Multiple outputs](#multiple-outputs)
			- [JS backend](#js-backend)
			- [WASM backend](#wasm-backend)
			- [Java backend](#java-backend)
			- [Flow backend](#flow-backend)
			- [C backend](#c-backend)
			- [Rust backend](#rust-backend)
		- [Meta-languages](#meta-languages)
		- [Cross calls and hosting](#cross-calls-and-hosting)
		- [Embedded native code](#embedded-native-code)
		- [Native inlined types](#native-inlined-types)
		- [Effects](#effects)
		- [Meta-programming](#meta-programming)
		- [Compilation model](#compilation-model)
			- [Thoughts on changing the compiler model](#thoughts-on-changing-the-compiler-model)
		- [Optimizations](#optimizations)
	- [Runtime and standard library](#runtime-and-standard-library)
		- [Runtime](#runtime)
		- [Data structures](#data-structures)
	- [Future plans](#future-plans)
		- [Reflection and sophisticated meta-programming](#reflection-and-sophisticated-meta-programming)
		- [Asynchronous code and calls](#asynchronous-code-and-calls)
		- [Interpreter](#interpreter)
		- [Compiler](#compiler)
		- [Rough examples for the future](#rough-examples-for-the-future)
		- [Interoperability of native types](#interoperability-of-native-types)
		- [Speculations](#speculations)
		- [Coverage report](#coverage-report)
		- [Fallback implementation of data structures](#fallback-implementation-of-data-structures)
		- [Arbitrary bitwidth integers](#arbitrary-bitwidth-integers)
		- [Random todos](#random-todos)

## Introduction

Fastlåst is a strongly typed, minimal language in the functional family of languages.
It supports a range of backends, and helps make code in these languages work
together.

### Usage

Works with current working directory as "c:\fast".

Examples:

	flowcpp fast/fast.flow -- file=client_server

will compile the tests/client_server.fast file and produce a range of outputs.

	flowcpp fast/fast.flow -- test=1 >out.flow

compiles all programs in the tests folder. Useful for unit tests.

	flowcpp fast/fast.flow -- file=client_server eval=run()

compiles the program, but also evaluates the "run()" expression in the compile-time
setting.

### Alternative pitches

Seamless integration of many languages into the same source code, even across
client and server. One program should contain everything you need everywhere.

Do you want to want to make different languages work together, then Fastlåst is for you. 
Fastlåst allows you to write one program for everything you need for installation, 
development, deployment, monitoring, testing, documentation, etc.

Are you deadlocked when deciding what language to use? Fastlåst gives you all of them.
Do you wish all languages were basically ML? Then Fastlåst is for you.
Do you use language X, but need a library in language Y? Then Fastlåst is for you.
Do you want to learn 20 programming languages? Then learn Fastlåst, and you will learn all.
Do you want Yatta-style async code? Then Fastlåst is for you.
Are you the author of some cool language, but it is isolated from the rest of the world? 
Then Fastlåst is for you.

### Meta thoughts

The Fastlåst project has a fractal structure: When something is done, 5 new avenues of work
open up. That means it is hard to complete this project. On the other hand, it also means
that it is a very rich project, with a lot of potential.

Another challenge is that Fastlåst does not solve one, well defined problem. Instead, it
aims at many different problems. Normally, we want a tool to do one thing, and do that well.
Fastlåst is not in this tradition. It is a tool, which hardly can do anything at the moment,
but it has the grand goal of allowing all languages to work together in practice.

The first goal is to leverage the strength of existing languages and platforms with Fastlåst. It aims to be
a one-stop solution for front-end, backend, database, development, deployment, testing and documentation.

### Status

We have a simple language with ints implemented in these backends:
- flow, js, wasm, c, html, rust

We can use the native inlines to implement data structures, such as tuples, 
floats, string, arrays, specific structs.

### Potential next goals

- Get closures to work, using partialCall and refs

- Send structured data between languages

- Fix cross-callbacks somewhere

- Reach production quality for the current set of features
  - Fix parsing precedence
  - Fix all todos when compiling test suite
  - Fix todos in test cases

- Match flow in expressivity
  - array
  - string
  - structs
  - currying
  - unions
  - with
  - switch

- Meta-programmering
   - Lambda
   - Closures
   - Good syntax for structs, arrays
   - Switch, pattern matching

- Client/server program where we do processing server-side in Java or deno
  and some nice presentation in JS. Would be nice to do it with flow

- Effects

- Add a "fastlåst" backend to the flow compiler

- Self-hosted compiler.

- Compile time Make-like functionality

- Very low-level code - memories demo. Maybe using WebGL? WebGPU seems more modern?

- Asynchronous calls across outputs.
  Deno server side
  - WASM inside
  - Imports of code using URLs

- Do region-memory management proof of concept

## The Fastlåst Language

The language is intentionally very small.

### Syntax

The syntax is similar to flow, with some tweaks and limitations.

No body or values allowed in the export section. Only type declarations
and function declarations. No global variables can be exported.

() is not required in if condition:
	if i == 1 {
		one
	} else two;

Type annotations as part of any expression:

	// General type annotation in <exp>
	2 + (1 : i8)

We have overloading and unicode ids:

	kødpålæg(items : i32) -> i32;
	kødpålæg(items : i32, speciality : i4) -> i32;

We have introduction of new type names:

	// Define a new type float 
	typedef float = f32;

Strings are parsed, but really just represent bits in the UTF8 or UTF-16 encoding 
of the text.

No switch, no lambdas (no closures). No refs, no structs, no arrays.
All of those are done in the standard library using native inlines.

TODO:
- Mangle names with unicode towards targets that do not allow unicode

### Type system

The type system of Fastlåst is minimal. Top level names all require explicit types.
There is type inference, and the type system is intended to be complete.

- The only basic type is integers of bits. There are i1, i8, i32, ... types with arbitrary 
  numbers of bits for ints. 

- The void type is i0

- First-order functions, but no closures

- Polymorphism and type functors

- Constant data as a type in the form of binary data. This type restricts the values of that
  type to be specific numbers. As an example, that means we should be able to declare C-style 
  zero-terminating strings as Tuple<i32, string, 0 : i8>

- Native inline type definition in the form of a string with unquotes

The typedef syntax allows defining types:

	typedef f32 = i32; //  is a type constant
	typedef Tuple<?, ??> = <typeexp>; // is a type functor
	typedef foo = Tuple<i32, i64>; // is a type constant defined by the call of a type functor
	typedef c::string = inline c { char·const·* }; // Define what a string is in C syntax

We allow type constructors to overload, as long as the number of parameters is different.

TODO: 
- Disallow overloading with polymorphic arguments.

	f(Array<f32>) -> f32
	f(Array<?>) -> ?

  We should not allow overloads of types that can be unified.
  We could attempt to allow it, except in first-order context without a type annotation.

### Language backends

Fastlåst is a simple language, and allows a program to be compiled to many different 
languages.  Currently, we have these language targets in order of maturity:

- Flow (beta)
- JS (beta) with browser and deno variants
- Java (beta)
- WASM (experimental)
- C (experimental)
- Rust (experimental)

In addition, we have a range of languages, which are basically text files:
- HTML
- Dockerfile
- .yml for Docker compose and Ansible files
- Terraform

Also, we have a special language, called "compiletime", which is evaluated at
compile time.

One special goal of Fastlåst is that adding a new language backend should 
be less than 500 lines of code in the compiler, plus some work in the runtime.

TODO:
- Dart - to get access to Flutter?
- haxe - do the flow runtime in Fastlåst?
- Typescript
- Scala. Here is a server side web framework: https://www.playframework.com/
- SQL
- Erlang - great at distributed
- Python? Special challenge with indentation-based syntax
- Haskell
- PHP - easy way to get client/server
- WebGL
- Here is a minimal, similar language with a x64 assembly backend:
  https://github.com/MauriceGit/compiler
- GRIN
- Jenkins?
- Bosque? https://github.com/microsoft/BosqueLanguage/blob/master/README.md
- SHAM for DSLs: https://arxiv.org/pdf/2005.09028.pdf
- Figure out Microsoft Fluid

### Multi-language syntax

A Fastlåst program defines not just one compilation language, but a number of them.

You can use output and language annotations to specify what code goes to what languages.

	import runtime;

	// This marks we want a "program.html" output in HTML
	program.html::main() -> () {
		// This means we will also need the JS output hosted from HTML
		js::main();
	}

	js::main() {
		// This means we also need the WASM output hosted in JS
		wasm::main();
	}

	// This is compiled to WASM
	wasm::main() -> () {
		// ... which in turns calls JS println
		js::println(42);
	}

This program produces 3 outputs: program.html, program.js, and program.wasm. 
The compiler will make sure to organize all details so that the HTML includes 
the JS, and the JS will load the WASM code, and the call chain will start from 
HTML, then JS, then WASM, and then the println goes back to JS.

### Multiple outputs

Using the output annotations, we can produce multiple outputs even in the same
language from one invocation:

	curator.html::main() {
		flow::curator_main();
	}
	learner.html::main() {
		flow::learner_main();
	}

The compiler will automatically figure out what parts of the program needs to go
into what outputs.

This also allows writing client/server programs in one file:

	server.java:main() {
		flow::foo();
	}

	client.html::main() {
		flow::bar();
	}

	foo() {
		// Ends up compiled to flow in the server via Java
	}

	bar() {
		// Ends up compiled to flow in the client via JS
	}

#### JS backend

Fix tailcalls
- Check callbacks to/from Wasm, Flow
- https://parceljs.org/ can help package/compile JS and HTML and stuff
- Wasm + deno:
	https://github.com/caspervonb/deno-wasi

- https://capacitorjs.com/ for making native apps with native APIs

- https://github.com/snabbdom/snabbdom
 
#### WASM backend

You need to download the WASM binary toolkit to get wat2wasm.

https://github.com/WebAssembly/wabt

TODO:
- Fix second first-order callback
- Fix tail-calls
- Check callbacks to/from JavaScript
- Extract data-sections for constant strings
- Tuples: Use the multi-value extension for WASM
  https://github.com/WebAssembly/multi-value/blob/master/proposals/multi-value/Overview.md
  It is in stage 4, supported in Chrome, as an example

#### Java backend

- Fix tail-calls

#### Flow backend

- Allow "import flow::renderform;" which would automatically wrap all the types and functions
  for use in Fastlåst
- Check callbacks to/from Java, JavaScript

#### C backend

- Fix tail-calls

- Compile to Wasm through emscripten for use in HTML family.

	emcc fact.c -o fact

will produce fact.wasm and fact.js, which can be used in HTML.

#### Rust backend

- Figure out the borrow checking interface
- Good libraries for WASM and Rust:
  https://blog.knoldus.com/get-a-look-on-key-rust-crates-for-webassembly/

  Rust + Dart
  https://dev.to/sunshine-chain/dart-meets-rust-a-match-made-in-heaven-9f5

### Meta-languages

In addition to specific code and configuration files that are required
to get software to work, there are other aspects of developing, deployment
and managing software.

Fastlåst should provide a number of meta-languages to help manage these:

- YAML, Dockerfiles, and docker compose files.

TODO:
- Docs - provide learning about the specific component or technology used
- License - for tracking license requirements
- Test - unit test cases are collected
- Install - collect installation instructions
- Monitoring - how to monitor the running software
- Backup - code how to do backups and restores
- Versioning - how to control versions of software, including rollbacks
- Security - tracking security reviews and other security aspects
- Requirements - where specs live and come from
- Code repository - where is the original code
- IDE integration
- Package manager
  -  https://chocolatey.org/ for Windows
- Deployment - Terraform
- Translation

It is as simple as using the output annotations with a suitable format:

	readme.markdown::main() -> i0 {
		inline markdown {
			asdfkjaskldfj aslædf
		}
	}

We could also build helpers for languages such as HTML:

	index.html::main() {
		html(
			head(title("Hello")),
			body(
				div("The body"),
				p(attribute("align", "left"), "A paragraph")
			)
		)
	}

TODO:
- Decide what formats to support. It is trivial to do in the text.flow backend

### Cross calls and hosting

When you compile, the language used for the different outputs are called hosts.
Some host languages allow other languages inside. Not all combinations are implemented.
For instance, we do not allow embedded JS in Java yet.

Also, not all cross-calls between languages are implemented yet. While we allow
JS to call Wasm, and JS to call flow, we do not yet allow flow to call Wasm.

This table defines what host language support what embedded languages:

	Host	Embedded Languages
	----	---------------
	Java	flow
	flow	Java, JS
	HTML	JS, Wasm, flow
	JS		Wasm, flow
	C		None yet
	Rust	None yet

This table defines what cross-calls are supported:

	Host->	C		flow 	Java	JS		Wasm
	C		*
	flow			*		*       *
	Java			*		*
	JS				*				*		*
	Wasm							*		*
	Rust

TODO:
- Figure out how to do transitive calls from Wasm to flow through JS

- Add a "spec" report feature to the compiler, which for each language can report what features are there:
  - Core Fastlåst language can be compiled
  - Can host these languages
  - Cross-calls allowed to/from these languages
  - Cross-Callbacks allowed to/from these language
  - Integers supported: i1, i8, ...
  - Specific types: (Can be discovered by parsing the stdlib) 
     - string
     - f32, f64
     - array
     - tuples
     - ref
     - promise
  - GC or explicit memory
  - Dynamic code loading supported

- Figure out direct imports of foreign headers:

	import flow::material/material2tropic;

  The basic idea is that this can be done using compile-time code which can
  parse the flow file, and then produce the required functions and types in
  Fastlåst using inline fastlåst.

- Figure out if we should expose target triplets in gcc and llvm:
  http://llvm.org/doxygen/classllvm_1_1Triple.html
  https://clang.llvm.org/docs/CrossCompilation.html
  Can be done with require inline blocks picked up by the backends.

- Once we have async/await, that allows easy splitting of code into
  smaller executables that are loaded on demand.
  We could also consider to go all the way to Yatta, which does automatic
  parallelization based on what returns promises:

	https://functional.blog/2020/05/25/designing-a-functional-programming-language-yatta/

- Check out telefork:
	https://thume.ca/2020/04/18/telefork-forking-a-process-onto-a-different-computer/
  Provides a way to fork on another computer, for distributed computing.

### Embedded native code

The native inline construct allows code in other languages:

	js::println(s : ?) -> () {
		inline js {
			console.log($s)
		}
	}

The body of the "inline js" block is raw JS. We do not parse it, but only
lex it using the C-style lexer. Parenthesis have to be balanced in the
native block, but otherwise, the raw tokens are transferred to the output
file as is.

If you need a space, be sure to use the · sign instead. 

In the body of the code, you can use "$id" or "${exp}" syntax to unquote arguments.
The code for those parts will be expanded to the target language, and then
substituted into the code. You can also use "$type{type}" syntax to unquote the 
textual representation of a type.

This means we implement the raw constructs of the languages directly in
Fastlåst, like this:

	js::inline +(l : i32, r : i32) -> i32 { inline js { (($l) + ($r)) | 0 } }
	wasm::inline +(l : i32, r : i32) -> i32 { inline wasm { ${l} · ${r} · i32.add } }

The "inline" notation forces thse function to be inlined. We inline, and after that,
perform constant propagation to simplify the code. That means all + in your
JS and WASM programs expand to natural code in the target language.

Notice that if we did not define + as inline, the backend would produce "+(l, r)"
which is not valid JS syntax.

The native inline expression construct also allows defining requirements:

	c::print(s : i32) -> i0 {
		inline c {
			printf("%i", $s)
		} require include {
			#include·<stdio.h>
		}
	}

This dependency is tracked by the C backend, and if you use "print" in your C program, 
the compiler will automatically insert the "#include <stdio.h>" at the top of the output.

Each backend defines their own sections. This is thus a general construct, which can
also be used to define linker flags, optimization flags, or other stuff required to
install, compile and deploy the code, even in other languages.

TODO: Get something like this to work:

	connectToDb(host : string, user : string, pw : string) -> connection {
		inline java {
			// Here place code that opens a connection to a database
			...
		} require java::import {
			// Add imports for Java here
		} require maven::dependency {
			// Add stuff that ends up in the pom.xml file for Maven
		} require docker::file {
			// Here we could add a section to a Docker file
			// to ensure a database is configured
		}
	}

### Native inlined types

Similar to the ability to embed native code in other languages directly in the code, we
also allow that mechanism to define how types are represented in the target languages:

Here is an example of how we can define the Pair<?, ??> type in Fastlåst in JS:

	typedef js::Pair<?, ??> = inline js { { first: ${?}, second: ${??} } };

Here is what it corresponds to in flow:

	typedef flow::Pair<?, ??> = 
		inline flow { Pair<${?],${??}> }
		require imports { import ds/tuples; };

To construct values of this type, a useful convention is to define a function using
the lower case name:

	flow::inline pair(f : ?, s : ??) -> Pair<?, ??> {
		inline flow { Pair($f, $s) }
	}

	program.flow::main() -> i0 {
		p = pair(2, 3);
	}

### Effects

We have syntax for tracking effects:

	export {
		typedef pointer<?> = i32;

		malloc(v: ?) -> pointer<?> with {heap, write};
		free(p : pointer<?>) -> void with {heap};
		setPointer(p : pointer<?>, val : ?) -> void with {heap, write};
		readPointer(p : pointer<?>) -> ? with {heap, read};
	}

The idea is that these operations have side-effects, and that affects what our
optimizations can do. In particular, we do not want to reorder side-effects
when we do constant propagation.

We need to figure out how to track side-effects for our constant prop. optimization.

TODO:
- Implement effect tracking
- Get constant prop to understand effects and use that to control optimizations

### Meta-programming

A special language is the "compiletime" language. This allows code to be evaluated at compile time.
This code can do many things, including generated new code, which will enter the rest of the compilation
process.

This works by evaluating any function called "main" in the compiletime language:

	compiletime::main() -> i0 {
		inline fast {
		} require function {
			// This adds this function to the program just to illustrate how
			fact(i : i32) -> i32 {
				if (i <= 1) 1
				else i * fact(i - 1)
			}
		};
	}

	meta.js::main() -> i0 {
		// This function "fact" was in fact constructed at compile time, but
		// available in a strongly typed sense here
		println(fact(5));
	}

As you can see, the "inline fast" construct is used to construct Fastlåst code, which is then
parsed and inserted into the program at compile time.

### Compilation model

The steps in the compiler are these:

1) We parse and link all source files into one AST
2) TODO: Do export checking, ignoring unknown names?
3) We run type inference, ignoring type errors
4) We partially evaluate all calls marked as compiletime
5) We partially evaluate all compiletime::main functions
6) We grab all inline fast constructs, parse them and include them in the AST and do constant propagation
7) We run type inference again
8) We run the type verifier to report type errors
9) For each output in our program, we iterate over all backends, and produce code for each.
10) Partially evaluate any code given with the "eval" command line option.

See partial_call.fast for an example.

#### Thoughts on changing the compiler model

I have been thinking about how to rewrite this to be query based, instead:
https://ollef.github.io/blog/posts/query-based-compilers.html

That basically means that we have a queue of things to move forward. At first,
we have FastFilenames, those turn into FastFile structures, which then break into
FastDeclarations, i.e. types, globals and functions, as well as a set of dependencies 
in the form of imports they depend on, which are pushed as FastFilenames on the queue. 

Once all imports of a file are resolved, we can do export name checking for that cluster.

Each declaration is then processed, and if the dependencies it has are resolved, it can
proceed to the next step of type inference.
After that, all compiletime annotated functions (except main) are then partially evaluated.
Once all compiletime annoated functions are partially evaluated, then we partially
evaluate all compiletime:main() functions.

Now, we will inline all functions marked as inline, and do constant propagation.

Every time a function is changed from either compile time partial evaluation or inlining
or constant propagation, we do type inference again.

Once a main file does not depend on any compiletime or inline names, and all dependencies are
type inferenced, we are ready to compile it. At this point, we run a type check of this part
of the AST, and after that, we produce a queue of outputs for each output to produce.

Once all main functions have been evaluated, then partially evaluate any input given
with the "eval" command line argument.

The idea is that this defines a continuous process, and gives fine-grained incremental
compilation in a compile server. Also, it means we can answer very quickly on queries 
for ids, nomatter what stage that id is at.

As files are changed, we can immediately start to reprocess them, updating the queue.

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

Basically, the compiler is a server that maintains this data structure:

	// Files to compile
	files : Queue<string>,
	// Declarations to process
	pendingDeclaration : Tree<string, FDeclaration>
	// The last known good declarations that type check
	lastKnownGoodDeclarations : Tree<string, FDeclaration>
	// The set of outputs we should produce
	outputs : Tree<string, FastAst>,
	// Specific code to evaluate in the compile server
	code : Queue<FExp>,

For each item in a queue, we have a set of dependencies for it.
We might have to give new ids for the last known good declarations,
so we can juggle with multiple versions of the same code.

Another related idea is to use Datalog to represent the intermediate
AST, and allow queries on it. See 

https://petevilter.me/post/datalog-typechecking/

### Optimizations

Currently, Fastlåst implements Dead Code Elimination, Inlining with Constant Propagation
and Specialization of polymorphism.

TODO:
- Make sure our renaming works for name conflicts from inlining in sequences
- Fix constant prop. to exploit effects to inline more.

Mir claims this is the minimal set of useful optimizations. Mir itself does not scale well, unfortunately.

*	function inlining
*	dead code elimination
+	sparse conditional constant propagation
-	global common sub-expression elimination
-	variable renaming
-	register pressure sensitive loop invariant code motion
-	code selection
-	fast register allocator with implicit coalescing hard registers and stack slots for copy elimination

The GRIN backend has a very nice selection of optimizations, optimized for functional languages.
	https://grin-compiler.github.io/


## Runtime and standard library

Fastlåst comes with a standard library, which is aiming to provide the
data structures and algorithms commonly needed. The primary goal is to
allow integration of languages, but over time, Fastlåst could have a substantial
standard library of independent value.

### Runtime

- Most of the language is implemented in the standard library. The only defined 
  value by the compiler is some subset of integers. Everything else is implemented 
  in the standard library.
- Each language should provide inline natives for all operations
- There is no explicit memory management policy except for the integers supported. The language
  only relies on a stack. Any heap, GC or other memory management relies on the underlying
  language used

Goals: Align the representation with the underlying language used. This is possible
due to the inline types and expressions.

### Data structures

Strings are parsed as UTF-8 by Fastlåst, but the type of them is marked as "string".
The runtime will then define what that is in the target language:

	typedef flow::string = inline flow { string };
	typedef java::string = inline java { String };
	typedef c::string = inline c { char·const·* };

Similarly, floats and doubles are defined in the standard library with "typedef f32 = ..." 
and "typedef f64 = ..." and a suitable set of overloaded functions per language.
The operations are done in the runtime, through native inlines.

We have the start of a few basic data structures in the standard library:

	Floats, String, Array, Tuples

We have a wish list of the work-horses:

	Ref, List, Tree, Multimap, Set are the work-horses. Have graph out of the box. 
	Also have hash-based data structures, which are faster when you do not need ordering properties.

Many languages have those directly available, and there, we can reuse them through inlines.

In addition to representing the raw data, we also want a stdlib with good functions to work on these.
We would like this family with arbitray combinations:

	 hash, map, fold, iter, filter, filtermap, find, forall, exists, serialization, deserialization, 
	 conversions, math operations, reflection of types, reflection of code… defined on data structures. 
	 No need for iterators this way..

  This can arguably be done with transducers:
	 https://medium.com/javascript-scene/transducers-efficient-data-processing-pipelines-in-javascript-7985330fe73d

  Another idea is to consider a lot of these structures as special kinds of graphs. That might provide 
  another way to get the generic helpers done.

TODO:
- Implement more data structures in more languages
- Add transducers in flow, so we can figure out what the type is. Then add in stdlib
- Should we do flowschema-like automatic UIs of values this way.

## Future plans

### Reflection and sophisticated meta-programming

We hope to be able to lift the AST into the compile-time world, and do things like this:

	compiletime::main() -> () {
		specializeTypes(0);
	}

	specializeTypes(typeno : i32) -> () {
		if (numberOfTypes() < typeno) {
			type(getType(typeno));
			specializeTypes(typeno + 1);
		}
	}

	type(t : Tuple<?, ??>) -> () {
		inline fast {
		} require function {
			first(t : Tuple<?, ??>) -> $typeof{?} {
				bits_of(t, 0, ${sizeof(?)});
			}
			second(t : Tuple<?, ??>) -> $typeof{??} {
				bits_of(t, ${sizeof(?)}, ${sizeof(?) + sizeof(??)});
			}
		}
	}

and it effectively generates code like this:

	first(t : (i8, i16)) -> i8 {
		bits_of(t, 0, 8)
	}

	second(t : (i8, i16)) -> i16 {
		bits_of(t, 8, 16)
	}

TODO:
- Get the above to work and use it to implement data structures

- Introduce default values for types? Maybe this is just an overloaded "new" function?

- In the standard library, include functions to do downloads or preparations of any prerequisites 
  on the local machine

### Asynchronous code and calls

For client/server, parallel, distributed, and asynchronous code in general,
there is a need to have a good way to do these.

The best model is probably async/await using promises and then do Yatta style
on top.

Figure out how to do this, and consider to combine with the "dynamic import"
construct for flow, where we can statically verify whether something is ready
or not.

It seems we have a few different ways of loading code:
- JS-style where library and main are joined, and library can depend on main. Asynchronous.
- Java-style, where library is loaded in a new namespace. Library can depend on main. Synchronous.
- Deno, where library is loaded in a new namespace. Library can probably depend on main. Asynchronous.
- Rust. Library is loaded in a new namespace. Library can not depend on main. Asynchronous?

Use the common serialization format to allow arbitrary exchange of data between
execution units.

TODO:
- Figure this out

### Interpreter

TODO:
- Fix int value in interpreter to be proper explicit bit-width
- Add more natives runtime support:
  - Promises so we can run more than one thing
  - system
  - "reflection" to list outputs, languages, types, functions
  - string operations, for parsing
 
### Compiler

TODO:
- For incremental, maybe a way forward is to have a hash of the filename in the declarations
  so we can have fine-grained tracking from the start

- Compile server, Language Server Protocol, profile & speed up

- export checking

- Move FSizeOf, FFunctionPointer, FTypeAnnotation out of FExp as sent to backends. 
  Or at least have a central place to "instantiate" or optimize them out.
  Do the same with types, so we simplify what each backend has to handle.

- Find a way to lift types to values. Also lift code to values?
  Quoting and unquoting? These can be functions in the interpreter. 

Exp parser:
- Have a syntax operator table with arg count, associativity and precedence table for parsing
  
  There is a nice way to do it here:
  https://matklad.github.io//2020/04/13/simple-but-powerful-pratt-parsing.html

  Maybe have this syntax:
  syntax $5 + $4		-> +($5, $4)
  syntax < $5 >			-> <>($5)

  The numbers dictate associtivity at those places.
  Maybe the right hand side is automatic.

- Figure out what to do about switch. Pattern matching?

  switch can technically be an overloaded function:

	// Not valid syntax yet:
    typedef Maybe<?> ::= None<?>, Some<?>;

	foo(a : Maybe<?>) -> ?? {
	   switch(a, None, fnForNone, Some, fnForSome)
	}

	fnForNone(n : None<?>) -> ?? {
		...
	}

	fnForSome(v : Some<?>) -> ?? {

	}

	// Something with the types does not match up here..
	switch(v : ?, e1 : ?, f1 : (?) -> ??, e2 : ?, f2 : (?) -> ??) -> ??

	switch(v : ?, cases : Array< Tuple<?, (?) -> ??> >) -> ??

- Investigate this thing:
  https://rauchg.com/2020/static-hoisting
  This is a JS library which allows the CDN to produce compiled HTML
  for requests.

### Rough examples for the future

// Defining an array type: The type in the array. The type used for the length. The length
// We represent that as a tuple with the length and then enough bits for the contents
typedef Array<type, lentype, len> = Tuple<type, lentype, i(len * sizeof(type))>;

// Array concat: We have simple arithmetic when defining types
+(l : Array<?, ??, length1>, r : Array<?, ??, length2>) -> Array<?, ??, int (length1 + length2) > {
	length = length1 + length2;
	result = alloc(length);
	memcpy(l.second, result);	// Replace with iter and get and set ops
	memcpy(r.second, result + length * sizeof(??));
	Array( length, result)
}

// Defining a struct:
typedef Some<?> = Tuple<#Some, ?>
typedef Foo<?, ??> = Tuple<#Foo, ?, ??>

// Meta-code which constructs constructors for all struct-types with 1 argument
makeConstructor1(type : (? : tag, ??)) -> code {
	@tag(value : ??) -> ? {value.first}
}

typedef Maybe<?> = Tuple( tagof(None, Some), ?)
Maybe<i32> = Tuple(i1, i32) == i33


### Interoperability of native types

typedef flow::ref<?> = inline flow { ref<$?> };
typedef c::ref<?> = i32;

flow::foo(a : ref<i>) -> () {
	c::print(a);	// Not possible, since flow::ref is native
}

c::foo(a : ref<i>) -> () {
	flow::print(a);	// flow-side will get a random int
}

### Speculations

Define data structure, a la flowschema.

These data structures will have user ids linked to them, and from those,
we can define security rules?

Define "live set" in a program, which is a subset of that data.

Content package
	Modules
		Learning objectives
			Content item

Maybe this is like regions in programming?

### Coverage report

Make a "coverage" report, which will output a table of what
Fastlåst supports.

Languages:
- C
- Flow
- Java
- Javascript
- Wasm
- Rust

Top languages to consider:
* JavaScript
- Python
* Java
- PHP
- C#
- C++
- TypeScript
- Shell
* C
- Ruby

* Rust
- Haxe
- Dart
- HTML+CSS
- Go
- Swift
- SQL
- R
- Julia
- Haskell
- F#, Ocaml, ReasonML
- WebGL
- Kotlin
- Apex
- HCL - configuration language

TODO:
- Add "coverage" report
- Build flow->wasm cross-call through JS
- Build docker image for Fastlåst
- Add Rust, C++, C#, TypeScript, Dart, CSS, Swift, Haxe, Kotlin, Go
- Add first-order functions and closures as a frontend
- Add algebraic data types as frontend
- Add "with" and pattern matching as a frontend
- Self-host Fastlåst
- Add Yatta-style promises, and we get asynchronous code for all these languages

### Fallback implementation of data structures

As an example, we can define Tuples in the type system, and provide language-specific 
implementations. But some languages do not have Tuples directly. In that case, we should provide 
a fallback implementation where Tuples correspond to memory-concat of the values, and thus 
becomes a int. Example:
Tuple<i3, i5> == i8.

The idea is that we can build a hierarchy of fall-back implementations of these data structures. 
It could work like this:

	i8, i32 - most languages have some variation of a fixed size int
	tuples - correspond to memory-concat of ints
	statically sized arrays
	heap - a simple heap with regions, ref counting or gc can be implemented with static
	arrays, string
	structs - built using hash of the name and become a tuple
	arbitrary bit-width ints
	list, tree, multimap, graph

Some languages will provide a different set than others, and thus, they do not have to use the
low-level fallbacks for increased efficiency. But by defining this hierarchy of data structures
with fall-back implementations, the goal is to make it easy to add a new language. Once it
supports the lowest levels, it will get all the other structures for free. Later, the data structures
can be improved using native inlines.
Also, having a shared definition of these data structures, which ultimately can be represented as
a long bit-string, we have a clear serialized representation of data which allows different languages 
to exchange data.

For some low-level languages, we could consider to have the length of arrays and strings as part
of the type. A constant array with 2 i8 ints with capacity of 32 bits in length can thus be 
represented as  Array<i32, i8, constant 2> and would expand to a Tuple<i32, i16> behind the scenes. The point 
is that we end up with separate types for arrays of various lengths. 

Structs have language-specific implementations, but can also come with an implicit tuple-based
implementations using an implicit int-tag. The int-tag is probably a hash of the name. 
Structs compile to constructor functions a la Eff. Check out how Eff did it.

Names are arguments (similar to strings), and exist at compile time, so we can implement “value.field” as a binary 
operator “.” that takes an expression and a name, and the runtime will construct a “field(name)” function for it. 
No overloaded dot outside of normal overloading.

For low-level languages, figure out if we could do ownership a la Rust, regions? A mix of GC and 
explicit regions? Allow bulk-freeing of regions. Annotations for how to copy or move between regions.
https://www.cl.cam.ac.uk/techreports/UCAM-CL-TR-908.pdf

See this dude that uses Datalog to model regions:
http://smallcultfollowing.com/babysteps/blog/2018/04/27/an-alias-based-formulation-of-the-borrow-checker/

Down the line, we can introduce fixed-point fractional numbers of arbitrary composition f2.3. These take 2+3 bits and 
thus just a typedef for i5. Introduce floats based on exponents: f3e2 or something where 3 is the number of bits 
after the comma and 2 is the number of bits for the exponent. These take 2+3 bits. 
Introduce compression/decompression/conversion functions between the raw bit representations. As a special case, 
have functions for standard IEEE representations. Find a way to add posits, unums and others. The key idea is that 
these are not part of the language, but a set of typedefs with functions to implement the required operations.

TODO: Read about this:
https://github.com/doctorn/micro-mitten

Can we express scheduling of loops a la kernels in the runtime?

TODO:
- Implement this hierarchy of data structures with suitable functions

### Arbitrary bitwidth integers

- Check others here 
	https://en.wikipedia.org/wiki/List_of_arbitrary-precision_arithmetic_software

  - https://bellard.org/libbf/ for arbitrary bitwidth ints. Last release 2020-01-19
  - https://git.suckless.org/libzahl/log.html. 
  - https://github.com/wbhart/bsdnt
  - https://github.com/suiginsoft/hebimath
- Clang has arbitrary bit-width ints

### Random todos

- Get Python with some game library running in the browser with 2d graphics
  and interaction. https://skulpt.org/

- Consider to use this library to expose things in Jupyter
	https://github.com/jupyter-xeus/xeus

- GRIN and C interoperability.
  Here is a basic runtime with strings:
  https://github.com/grin-compiler/idris-grin/blob/master/prim_ops.h

- Consider to check out Neut:
  https://github.com/u2zv1wx/neut
