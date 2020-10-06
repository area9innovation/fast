// <file> import -> each line is evaluated
def import "evallines" swap evalfile

// It is important evalfile is the last
def prepexp "parseexp" "prepare" "mini/exp/exp.gringo" evalfile

// Do not use this in a sequence, since it is async
def readfile "nop" swap evalfile
