# Gringo

This is a Parsing Expression Grammar tool. It provides a way
to write a parser, which will convert a string to another string.

It is designed to allow succinct and composable grammars to be
written.

## Grammar

The grammar for Gringo is given here:

	term = id "=" term(0) ";"	// Binding
		| term(1) "|" term(2)	// Choice
		| term(10) term(11)		// Sequence
		| term(12) "*"			// 0 or more
		| term(12) "+"			// One or more
		| term(12) "?"			// Optional
		| "!" term(0)			// Negation
		| "(" term(0) ")" 		// Grouping
		| "$" term              // Semantic action
		| string				// Constant string
		| char "-" char			// Range
		| id "(" int ")"		// Rule ref with power
		| id					// Rule ref
		;

We might consider to add:

		| term(13) ":" type		// Type annotation
		| expect term string	// Construct for error recovery?

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

Parsing "1+3", we should get this trace:

	exp(0) ->
		exp(1) -> 
			exp(1) is skipped, since power[exp] = 1, and 1 <= 1
		
			exp(3) -> int, fail at "*"
			int -> int

		"+" matches

		exp(2) -> 
			exp(3) -> int, fail at "*", since we have nothing
			int -> int

Parsing "1*3", we should get this trace:

	exp(0) ->
		exp(1) ->
			exp(1) is skipped, since power[exp] = 1, and 1 <= 1
			exp(3) -> int
			"*"
			exp(4) ->
				exp(1) is skipped, since power[exp] = 4, and 1 <= 4
				exp(3) is skipped, since power[exp] = 4, and 3 <= 4
				int -> int

Parsing "1*2+3", we should get this trace:

	- TODO: Add the trace

## TODO

- Get the grammar for Gringo parsed and compiled instead
  of hardcoded. I.e. replace gringo_grammar.flow to be 
  produced from gringo.gringo:
   - Add semantic actions

- Check that it works

- Redo semantic actions to a shorter form
  - Using names as shortcuts for results:

		| id "(" int ")"		{ Rule($int, $id) }

  - Using the numbers as shortcuts for results:

		exp(1) "||" exp(2)		{ ||($1, $2) }

- Add error recovery

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

