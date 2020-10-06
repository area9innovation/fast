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
