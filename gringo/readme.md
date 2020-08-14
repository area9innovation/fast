# Gringo

This is Lingo2. A string to string converter.

Inspired by the approach in 

	https://matklad.github.io//2020/04/13/simple-but-powerful-pratt-parsing.html

where we use binding power to define precendence and associativity, combined with
a PEG-style parser.

## Grammar

term = id "=" term(0) ";"	// Binding
	| term(1) "|" term(2)	// Choice
	| term(10) term(11)		// Sequence
	| term(12) "*"			// 0 or more
	| term(12) "+"			// One or more
	| term(12) "?"			// Optional
//	| term(13) ":" type		// Type annotation
	| "!" term(0)			// Negation
	| "(" term(0) ")" 		// Grouping
	| "{" form* "}"			// Semantic action
	| string				// Constant string
	| char "-" char			// Range
	| id "(" int ")"		// Rule ref with power
	| id					// Rule ref
	;

form = "$" int | "$" id | string;

## Semantics

A gringo program takes a string, and produces a new string.

## TODO

Reconstruct grammar so term(1) -> term1, and so forth,
so we specialize the precendence and associativity into
separate rules.

	exp = exp(1) "+" exp(2)
		| exp(3) "*" exp(4)
		| int;
	int = '0'-'9';

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

## Optimization

https://mpickering.github.io/papers/parsley-icfp.pdf

## Expression grammar

Here is an example expression grammar.

	exp = 
		// Bin ops
		exp(1) "||" exp(2)		{ ||($1, $2) }
		| exp(3) "&&" exp(4)	{ &&($3, $4) }

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

