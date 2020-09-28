# Mini

This is an experiment to build a queue-based, always live compiler.

It takes inputs, and continuously compiles the result into valid programs.

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

## Example compile queue

Example compile flow:

	1. compile "mini/tests/test.mini"
	2. the file is read, each line is pushed to the compiler
