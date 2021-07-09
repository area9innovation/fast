# Koka

Koka is a ML-style language with effects and other goodies.

https://github.com/koka-lang/koka

This backend is intended for an experiment to see if we can
exploit the smart ref-counting behaviour Koka has for great
reduction in memory.

# Testing

To test, compile some program to koka:

	flowcpp plow/plow.flow -- file=demos/euler/euler1.flow koka=koka.kk
	flowcpp plow/plow.flow -- file=tools/gringo/gringo.flow koka=koka.kk

In Ubuntu, then use this to compile with Koka:

	koka /mnt/c/fast/koka.kk

# TODO

- Get euler1 to compile and run as Koka:
  - Structs occuring in Unions should not be declared again
  - top-level vars can not have effects
  - Add type arguments to functions to disambiguiate args
- Fix mutable
- Fix runtime
