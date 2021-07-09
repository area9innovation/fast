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

# Options

If you use

	koka-int=1

the code generator will use int, rather than int32 for integers.

# TODO

- Get euler1 to compile and run as Koka:
  - flow_fold is not implement
  - Unions in unions are not handled right
  - Special cases for 
    - flow_flow
      - Flow type does not exist
    - flow_isOWASPLevel1, flow_isLoggingEnabled, flow_securityModes, flow_loggingEnabled
      - top-level vars can not have effects
  - Add type arguments to lambdas? to disambiguiate args
- Fix mutable
- Fix runtime
