all: codeyboy

Lexer.hs: Lexer.x
	alex Lexer.x

ParserTabla.hs: ParserTabla.y
	happy ParserTabla.y

codeyboy: Lexer.hs ParserTabla.hs
	ghc -o codeyBoyRun --make -main-is Main Main.hs

clean :
	rm -f codeyBoyRun Lexer.hs ParserTabla.hs *.o *.hi *.info
