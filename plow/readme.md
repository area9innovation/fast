# Plow - a flow compiler

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
   Status: Subtyping to be done.

4. Then plug into the backends.

This pipeline is exposed by 

	compilePlow(cache : PlowCache, file : string) -> BModule;

where `PlowCache` is a cache for modules.

# TODOs

- Positions on some operators are off a bit.
- Implement Maybe & With desugaring
- Subtyping inference
- Add a compile server
  - Add option to only type check given ids

# Type inference

Use the egraph over types and tyvars.
Use lower/upper types as from
https://gilmi.me/blog/post/2021/04/13/giml-typing-polymorphic-variants

We use overload types to handle the overloading of +, - as well as
dot on structs, which can be considered as an overloaded function.

# Rewrite syntax

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

