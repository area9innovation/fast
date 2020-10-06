// <file> evalfile -> each line is evaluated
def evalfile "evallines" swap processfile

// Prepare our expression grammar parser
//   ->   
//        defines    <string> parseexp ->
// It is important processfile is the last
def prepexp "parseexp" "prepare" "mini/exp/exp.gringo" processfile

// Do not use this in a sequence, since it is async
// <file> -> <filecontent>
def readfile "nop" swap processfile

def parsefile "parseexp" swap processfile

// <a> -> cons(a, nil)
def list1 nil swap cons

// <a> <b> -> cons(a, cons(b, nil))
def list2 swap nil swap cons swap cons

// <exp> <string>  -> <call>(var(string), [exp])
def unop var swap list1 call

// <exp> <exp> <string>  -> <call>(var(string), [exp, exp])
def binop var rot rot list2 call
