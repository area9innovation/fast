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

  - There is a problem with our rewrite rules, so we get

	  term1 = term2 ("|" ws0 term2 { GChoice($term(1), $term(2)) })*;

	Consequence: Maybe we should switch to a stack-based semantic
	action metaphor, instead of binding style.
	So the actions are just GUnquote, no GAction.
	I.e. we can not produce prefix notation, only postfix notation.

   We change Gringo to be event based, and then we can have default
   event handlers that produce Forth, or others which take a type
   definition of your AST, and produces an AST.

- Add error recovery

- Add syntax requirement for the semantic actions, so we can statically
  check that the outputs will comply with some syntax, such as flow values,
  s-expressions, lisp, whatever you want to have as the output

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

