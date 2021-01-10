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

// <pos> <exp> <string>  -> <call>(var(string), [exp], pos)
def unop var swap list1 call setpos

// <exp> <exp> <string>  -> <call>(var(string), [exp, exp])
def binop var rot2 list2 call

// <exp> <pos> <exp> <string> -> <call>(var(string), [exp, exp], pos)
def binopp p2134 binop setpos
// def binopp var rot setpos rot2 list2 call

// Type name only
def type0 "__type" var swap list1 call

// Type with 1 type parameter
def type1 "__type" var rot2 swap list2 call
