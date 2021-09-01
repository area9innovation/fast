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

## Type inference

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

# Name and type lookups

A key problem is to find names, types, sub- and supertypes from the context 
of a given module. We would like this lookup to be precise in terms of the import graph.

This is not easy. Consider the problem of transitive supertypes:

	file1:
	U := A, B;

	Add relations: A -> U, B -> U

	file2:
	import file1
	T := U, C;

	Has: A -> U, B -> U, 
	Add relations: U -> T, C -> T, and expanding U to get A -> T, B -> T

	file3:
	import file2
	V := T, D;

	Has: A -> U, B -> U, U -> T, C -> T, A -> T, B -> T
	Add relations: T -> V, D -> V, expand T to get: U -> V, (A -> V, B -> V), C -> T

	file4:
	W := C, E;

	Add: C -> W, E -> W.

So we have a graph of types and subtypes, but there are some parts of the graph
that only become online when certain files are included.

Rejection options for having efficient solution:

- Maintaining transivitive closure: https://pure.tue.nl/ws/files/4393029/319321.pdf

Basically, requires a N^2 binary matrix for each step. Thus, maintaining all intermediate
transitive closures requires N^3 space. We have on the order of 5000 flow files.
To keep all those would require 120gb. So we have to be smarter.
We could restrict the graph to just those files that define unions. For plow, this is 21 
files out of 148. 15%. That still becomes 1GB for Rhapsode. So doing it precisely for all 
files is not realistic.

Instead, we should maintain a global lookup, as well as a way to check what path each
global is defined in.
Then we need the ability to check whether a given file is included in the transitive
import closure of another file.

Live data structures to make this possible:
- Global graph of super/subtypes
- Import graph
- Global map from symbol to what file defines that

So to find the supertypes of a given file, we get the global list.
Then we filter that list by looking up the source file of each type, and
checking that this is in the transitive closure of the current file.

This paper provides an algorithm that allows us to check if A is in the
transitive closure of B:
https://dl.acm.org/doi/abs/10.1145/99935.99944

Try to understand that, and maybe implement it.

Plan:
- Get it to work with global ids.
  Place global ids in plowcache, which is the only thing which survives all files. Done for
  sub-/super-types, but todo: Do this eagerly for structs & unions as well.
- TODO: Implement the transitive closure check in a second step to filter the list of ids found.
  We should probably maintain a set of dependent ids for each global, so we can quickly check this
  also when incremental is going to be done on ids?

# TODOs

- Improve type error reporting: Probably, we should build a tyvar hierarchy with reference to where
  they belong and what semantic check they are involved in. Also, we should not report more than one
  error per tyvar.

- Debug type errors
  - tools/flowc/type_helpers.flow:1108:9: ERROR: Merge FcTypeName and FcType (e12441 and e11628)
		FcTypeName(n1, typars1,__):
	Also, when run directly, it has a bunch of unknown unions and structs.

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
	Still unknown.

## Optimization of the compiler

The compiler has decent speed, but could be faster.

- Try vector in union_find_map, which might be faster at least in Java. 

- Try to reduce the active set of tyvars when doing chunks. Copy from one 
  tyvar space to a new one, to reduce max set.

- Compiling runtime.flow takes 2527ms. Rough breakdown:
    800ms in parsing. The best fix there is to improve Gringo backend for common
	      constructs
   1262ms in type inference
 	 	600ms in resolveTNodes

- UnionFindMap total time (with some double counting, since they call each others):
  588ms in iterUnionMap
  529ms in findUnionMapRoot
  468ms in unionEnsureMapCapacity
  328ms in setUnionMapValue
  184ms in getUnionMapValue
  167ms in unionUnionMap
  Main potential improvement is the reduce the number of live tyvars, next
  try a different data structure.

- When finding chunks, check if the code for a referenced piece of code has any
  free ids. If not, no need to chunk it. (see unicodeToLowerTable and others
  in text/unicodecharacters.flow)

## Improvements

- Imports that start with "lib/" are almost surely wrong, and do not work.

- Add a check that imports really exist, and report errors for those that do not

- Add a compile server
  - Add option to only type check given ids

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

TODO:
- We need struct id and unions to work

There is a C GC library here:

Automatic:
https://github.com/mkirchner/gc
https://github.com/orangeduck/tgc

Requires implementing "mark", but that should be simple.
https://github.com/doublec/gc

Advanced, performant, but complicated:
https://chromium.googlesource.com/chromium/src/+/master/third_party/blink/renderer/platform/heap/BlinkGCAPIReference.md

The best solution is to go for Perceus:
https://www.microsoft.com/en-us/research/uploads/prod/2020/11/perceus-tr-v1.pdf

## General backend plan

1. Extend lambda calculus with dyn & join with partial evaluation to construct vars and functions

2. Extend lambda calculus with inline construct and foreign language construct

3. Add backend to compile lambda calculus to flow-code, JS, Java, Wasm, Bytecode, C++

4. First use case could be Gringo to flow
