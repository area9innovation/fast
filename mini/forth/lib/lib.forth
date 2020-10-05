// <file> import -> each line is evaluated
def readfile "nop" swap evalfile
def import "evallines" swap evalfile
def gringo readfile "prepare"
