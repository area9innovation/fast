// <file> evalfile -> each line is evaluated
def evalfile "evallines" swap processfile

// Prepare our expression grammar parser
//   ->   
//        defines    <string> parseexp ->
// It is important processfile is the last
def prepflow "parseflow" "prepare" "mini/exp/flow.gringo" processfile

def debug dup print

// Do not use this in a sequence, since it is async
// <file> -> <filecontent>
def readfile "nop" swap processfile

def parsefile "parseflow" swap processfile

// <a> -> cons(a, nil)
def list1 nil swap cons

// <a> <b> -> cons(b, cons(a, nil))
def list2 swap nil swap cons swap cons

// <exp> <string>  -> <call>(var(string), [exp])
def unop var swap list1 call

// <exp> <exp> <string>  -> <call>(var(string), [exp, exp])
def binop var rot rot list2 call

def type0 "__type" var swap list1 call

def type1 "__type" var rot rot swap list2 call
