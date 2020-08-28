# Gringo

This is a Parsing Expression Grammar tool. It provides a way
to write a parser, which will convert a string to another string.

It is designed to allow succinct and composable grammars to be
written.

## Grammar

The (simplified) grammar for Gringo is given here:

	term = id "=" term(0) ";"	// Binding
		| term(1) "|" term(2)	// Choice
		| term(10) term(11)		// Sequence
		| term(12) "*"			// 0 or more
		| term(12) "+"			// One or more
		| term(12) "?"			// Optional
		| "!" term(0)			// Negation
		| "(" term(0) ")" 		// Grouping
		| "$" term              // Unquoting
		| "{" form+ "}"        // Semantic action
		| string				// Constant string
		| char "-" char			// Range
		| id "(" int ")"		// Rule ref with power
		| id					// Rule ref
		;

	form = "$" term | !("$" | "}" ) char;

See `gringo.gringo` for the real grammar, with white-space handling.

We might consider to add:

		| expect term string	// Construct for error recovery?
		| term(13) ":" type		// Type annotation

## Semantics

A gringo program takes a string, and produces a new string.

## Handling precedence and associativity

The numbers after ids are used to handle the precedence and associativity.
We use a scheme inspired by the approach in 

	https://matklad.github.io//2020/04/13/simple-but-powerful-pratt-parsing.html

where we use binding power to define precendence and associativity. This is
generalized to work for all constructs. 

An example:

	exp = exp(1) "+" exp(2)
		| exp(3) "*" exp(4)
		| int;
	int = '0'-'9';
	// "Invoke" the parser at the end
	exp;

This grammar makes sure that * binds closer than +, and that these binary
operators are left associate.

This is implemented by expanding the exp rule into exp1, exp2, exp3 and exp4
rules appropriately nested. The result is then optimized in a number of ways,
with the result being a correct and efficient grammar.

## Actions

The $<term> construct is used to produce semantic output. This will produce
the matched output of the <term> as a string. As a special case, if you use
$"string", it will produce the verbatim output "string" instead.

These actions are defined through an event-based API. By default, we use a
Forth-like output where the matched tokens are pushed on a stack as strings, 
and then semantic actions are pushed as operations.

Concretely, strings are written as "string" on a separate line, and then 
operations are produced verbatim.

	$"operation"	-> will call addVerbatim with "operation", but match epsilon
	$$"fakematch"	-> will call addMatched with "fakematch", but match epsilon
	$term			-> will call addMatched with the string matched by term

## TODO

- Get the grammar for Gringo parsed and compiled instead
  of hardcoded. I.e. replace gringo_grammar.flow to be 
  produced from gringo.gringo
  - It seems right association does not work for GSeq and GChoice,
    in particular, left-recursion optimization of 
		e = ((e | b) | c) 
	does not work.
	It has to be 
		e = (e | (b | c))

- Add error message when we have left recursion deep inside a choice

- OK, we have strange loops with the number system, so we have to do
  different operators instead:
		|>   for precedence increase
		*()  for left-associative star
		+()  for left-associative plus

- Add error recovery

- Add JSON action output, parse flow types, and construct actions for that

## Inspiration

Optimizing PEG grammars:
https://mpickering.github.io/papers/parsley-icfp.pdf

Adding error recovery:
https://www.eyalkalderon.com/nom-error-recovery/

## Expression grammar

Here is an example expression grammar that matches C
associativity and precedence.

	exp = 
		// Bin ops
		exp(1) "||" exp(2)
		| exp(3) "&&" exp(4)

		| exp(5) "==" exp(6)
		| exp(5) "!=" exp(6)

		| exp(7) "<=" exp(8)
		| exp(7) "<" exp(8)
		| exp(7) ">=" exp(8)
		| exp(7) ">" exp(8)

		| exp(9) "+" exp(10)
		| exp(9) "-" exp(10)

		| exp(11) "*" exp(12)
		| exp(11) "/" exp(12)
		| exp(11) "%" exp(12)

		| exp(13) ":" type(0)

		// Prefix
		| "-" exp(14)
		| "if" exp(0) exp(2) "else" exp(1)
		| "if" exp(0) exp(1)

		// Postfix
		| exp(14) "[" exp(0) "]"
		| exp(15) "." exp(14)		// Right associative

		| exp(15) "?" exp(0) ":" exp(14)	
		;

