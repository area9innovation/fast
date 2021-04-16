# New plan

The Forth stuff is too complicated.
The restriction of the mini-lambda in the entire compiler is too untyped.

1. Have complete AST after parsing, using typed Gringo grammar.
      PExp = Parsed Expressions
   Status: Done. Can parse all code we have.

2. Once files and dependents are parsed, desugar the program to DExp:
   DExp = Desugared Expressions

   Status: Partially done.

3. Once dependencies are desugared, do type inference

   TExp = Typed Expressions

4. Then plug into the backends.

# TODOs

- Positions on some operators are off a bit.
- Implement Maybe & With desugaring

# Type inference

Use the egraph over types and tyvars.
Use lower/upper types as from
https://gilmi.me/blog/post/2021/04/13/giml-typing-polymorphic-variants

# Rewrite syntax

flow-exp: $id = $val; $body
=>
js-statement: 
var $id = $val(100);
$body

flow-exp: $l + $r
=>
js-exp: $l(100) + $r(99)
