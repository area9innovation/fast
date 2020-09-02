# Yingo - Gringo Joy&Forth

Our goal is to have a language, which is used for the semantic actions in a Gringo
grammar. This is naturally a stack-based, postfix language, given the nature of a
PEG-style parser. 

A secondary goal is to have a language to compile Gringo grammars into. It makes sense
to try to make this the same language as the semantic actions.

So the goal is to use a stack-based language, which can be evaluated effectively,
as well as be compiled to other languages, so we can compile the parsers and semantic
actions to a host of languages.

## Inspirations

We are inspired by Forth, Factor, and Joy.

An awesome implementation of Forth:
https://github.com/nornagon/jonesforth/blob/master/jonesforth.S

Factor is a typed Forth:
https://factorcode.org/

Joy is a concatenative functional language:
http://joy-lang.org/

## Syntax consideration

There is a problem with syntax in Forth-style languages. A Forth/Factor implementation
has a compile-mode and an immediate-mode. Some words are evaluated at
compile time, and others in immediate mode.

This way, the task of figuring out what is quoted and what is not is written
in the language itself, and evaluated in compile-mode. So the evaluation of
a program is a mix between compile and immediate mode, dynamically shifting.

## Literals/types

We should attempt to support the same type-system as Fast:

- ints of different lengths
- double
- string
- arrays
- structs/unions
- quoted code (array of words?)

We could attempt to do this using polymorphism.

## Operators or Words

x drop ->
x dup -> x x
x print ->
x y swap -> y x
x y over -> x y x
x y z rot -> y z x
x y dup2 -> x y x y 

Joy has the same syntax for these two, since if an array only
contains literals, it is a list/array.

[ lit lit ... lit ]	   -> <array>
[ word word ... word ] -> <quoted-program>

<quote> eval -> (result of code)

b {code0} {code1} ifelse  -> <eval code0 or code1>
b {code} if  -> <eval code0 or nothing>

x y + -> x+y
x y - -> x-y
x y * -> x*y
x y / -> x/y
x y % -> x%y

x sq -> x*x
x sqrt -> sqrt(x)
pi -> 3.141...

## Defining words


# Standard forth

index_from index_to FOR variable_name loop_statement NEXT

index_from index_to FOR variable_name loop_statement <int> STEP

 WHILE condition REPEAT loop_statement END
 DO loop_statement UNTIL condition END

--

->num   convert string to number (with full eval of syntax)
