// <file> import -> each line is evaluated
def readfile "nop" swap evalfile
def import "evallines" swap evalfile
def gringo readfile "prepare"
// Debug why this does not work:
def prepexp "mini/exp/exp.gringo" readfile "parseexp" swap prepare
