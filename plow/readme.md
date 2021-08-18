# Plow - a flow compiler

Usage:

flowcpp plow/plow.flow -- file=myfile.flow

Options:
	debug=<id>,<id>
		Will trace the compilation process of the given ids.
		The ids can be types, functions, globals, or files (without .flow).

	verbose=0,1,2
		Increasing amount of tracing information

# Goals and motivation

The goal is to an incremental compiler, which is incremental at the id level.
The existing flowc compiler is incremental at the module level, but that means
most compiles are slower than they have to be.

# Representations

This compiler has these representations:

1. Have complete AST after parsing, using typed Gringo grammar.
      PExp = Parsed Expressions
   `parsePExp` converts a string to `PExp`.
   Status: Done. Can parse all code we have.

2. Once files and dependents are parsed, desugar the program to DExp:
   DExp = Desugared Expressions.
   `desugarPExp` converts a `PExp` to `DExp`, using a `DDesugar` environment
   for struct and union lookups.
   Status: Done.

3. Once dependencies are desugared, do type inference and convert the result to
   ``BExp`. Typing happens in `ttypeInference` and then we get a bmodule from
   `dmodule2bmodule`.
   BExp = Backend, Typed Expressions.
   Status: Mostly done. Fixing bugs in type checker.

4. Then plug into the backends. Initial JS backend exists. js=1

This pipeline is exposed by 

	compilePlow(cache : PlowCache, file : string) -> BModule;

where `PlowCache` is a cache for modules.

# TODOs

- Debug type errors
  - type25: it is fundamentally flow vs [flow]

	- plow/test/struct.flow
	C:\fast\plow\tests\struct.flow:11:9: Could not resolve supertype: super1{e96}
			Some(v): v;
		^
	C:\fast\plow\tests\struct.flow:9:5: Could not resolve supertype: super3{e96, e115}
		switch (m : Maybe) {
	^
	This is somehow related to how "println" contaminates the rest with the "flow" type
	there.

  - form/renderform:
	C:/flow9/lib/form/renderform.flow:367:13: and here
			CameraID(id) : {
			^
	C:/flow9/lib/form/renderform.flow:262:31: ERROR: Merge int and WidthHeight (e736 and e1930)
				if (length(texts) == 0) {
								^
	C:/flow9/lib/form/renderform.flow:262:31: and here
				if (length(texts) == 0) {
								^
	C:/flow9/lib/form/renderform.flow:533:17: and here
					ClipCapabilities(d.capabilities.move, d.capabilities.filters, d.capabilities.interactive, d.capabilities.scale, false), fn
				^
	C:/flow9/lib/form/renderform.flow:712:33: and here
			attachChildAndCapability(
								^


- Speed up the compiler - try vector in union_find_map, which might be
  faster at least in Java. Try to reduce the active set of tyvars when
  doing chunks. Maybe try small chunks (only for cycles in id use), and
  "raise" to bigger chunks in case of errors?
- Add a compile server
  - Add option to only type check given ids

# Type inference

The type inference uses equivalence classes for the types.
The type system is extended with two constructs:

- Overloads. This defines a set of types, where we know the
  real type is exactly one of them. As type inference proceeds,
  we will eliminate options one by one until we have a winner.
- Supertypes. This defines a type which is a supertype of all
  the subtypes within.

We use overload types to handle the overloading of +, - as well as
dot on structs, which can be considered as an overloaded function.

TODO: Review the lower/upper types from
https://gilmi.me/blog/post/2021/04/13/giml-typing-polymorphic-variants

# Proposal: Rewrite syntax

We could extend Plow with a rewriting feature.

flow-exp: $id = $val; $body
=>
js-statement: 
var $id = $val(100);
$body

flow-exp: $l + $r
=>
js-exp: $l(100) + $r(99)

# C++ backend

There is a C GC library here:

Automatic:
https://github.com/mkirchner/gc
https://github.com/orangeduck/tgc

Requires implementing "mark", but that should be simple.
https://github.com/doublec/gc

Advanced, performant, but complicated:
https://chromium.googlesource.com/chromium/src/+/master/third_party/blink/renderer/platform/heap/BlinkGCAPIReference.md

# General backend plan

1. Extend lambda calculus with dyn & join
2. Extend lambda calculus with inline construct
3. Add backend to compile lambda calculus to flow-code, JS, Java, Wasm, Bytecode, C++
4. First use case is Gringo to flow
