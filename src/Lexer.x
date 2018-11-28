-- Lexer de CodeyBoy
-- Integrantes:
--              Erick Flejan    12-11555
--              Carlos Perez    13-11089

-- CI-4721 Lenguajes de Programacion II

{
module Lexer where
import Tokens
import System.IO
import System.Environment
}

%wrapper "monad"

-- Macro definitions
$whitechar = [\ \t\r\f\v]

$underscore = \_
$digit  = 0-9
$uppercase = A-Z
$downcase  = a-z
$alpha     = [$downcase $uppercase]
$newline = ["\\n]

-- Regular expression macros
@inside_string  = ($printable # ["\\] | \\$newline)
@string         = \"@inside_string*\"
@bad_string     = \"@inside_string*
@space = $whitechar+
@identifier = $downcase [$alpha $digit $underscore]*
@registers = $uppercase [$alpha $digit $underscore]*
@double = $digit+\.$digit+
@number = ($digit+ | @double)
@char = \'.\'
@comment = "#.*"
@realnewline = (\n|\#.*)($whitechar|\n|\#.*)*
@opencurlybracket = \{ ($whitechar|\n|\#.*)*

tokens :-
    @space+                ;
    -- Tokens de palabras reservadas
    "Int"               { makeLexeme TKIntType }
    "Bool"              { makeLexeme TKBoolType }
    "Char"              { makeLexeme TKCharType }
    "Float"             { makeLexeme TKFloatType }
    "Void"              { makeLexeme TKVoidType }
    "Array"             { makeLexeme TKArrayType }
    "String"            { makeLexeme TKStringType }
    "Reg"               { makeLexeme TKRegType }
    "Boy"               { makeLexeme TKBoyType }
    "Union"             { makeLexeme TKUnionType }
    "Pointer"           { makeLexeme TKPointerType }
    "while"             { makeLexeme TKWhile }
    "for"               { makeLexeme TKFor }
    "from"              { makeLexeme TKFrom }
    "to"                { makeLexeme TKTo }
    "by"                { makeLexeme TKBy }
    "in"                { makeLexeme TKIn }
    "break"             { makeLexeme TKBreak }
    "if"                { makeLexeme TKIf }
    $underscore         { makeLexeme TKOtherwise }
    "with"              { makeLexeme TKWith }
    "func"              { makeLexeme TKFunc }
    "let"               { makeLexeme TKLet }
    "="                 { makeLexeme TKAssign }
    "::"                { makeLexeme TKRef }
    ":"                 { makeLexeme TKTypeDef }
    "Arr"               { makeLexeme TKPirata }
    @opencurlybracket   { makeLexeme TKOpenBracket }
    "}"                 { makeLexeme TKCloseBracket }
    "("                 { makeLexeme TKOpenParenthesis }
    ")"                 { makeLexeme TKCloseParenthesis }
    "["                 { makeLexeme TKOpenSqrBracket }
    "]"                 { makeLexeme TKCloseSqrBracket }
    "!"                 { makeLexeme TKNot }
    "=="                { makeLexeme TKEqual }
    "/="                { makeLexeme TKUnequal }
    "&&"                { makeLexeme TKAnd }
    "||"                { makeLexeme TKOr }
    "|"                 { makeLexeme TKElse }
    ">"                 { makeLexeme TKGreater }
    "<"                 { makeLexeme TKLesser }
    ">="                { makeLexeme TKGreaterEqual }
    "<="                { makeLexeme TKLesserEqual }
    "+"                 { makeLexeme TKPlus }
    "-"                 { makeLexeme TKMinus }
    "*"                 { makeLexeme TKMultiplication }
    "//"                { makeLexeme TKWholeDivision }
    "/"                 { makeLexeme TKDivision }
    "%"                 { makeLexeme TKMod }
    "True"              { makeLexeme TKTrue }
    "False"             { makeLexeme TKFalse }
    ","                 { makeLexeme TKComma }
    "."                 { makeLexeme TKPoint }
    "$"                 { makeLexeme TKDollar }
    "return"            { makeLexeme TKReturn }
    "print"             { makeLexeme TKPrint }
    "input"             { makeLexeme TKInput }
    "malloc"            { makeLexeme TKMalloc }
    "free"              { makeLexeme TKFree }
    "stringify"         { makeLexeme TKStringify }

    "bring"             { makeLexeme TKBring }
    "the boys"          { makeLexeme TKTheBoys }
    "all"               { makeLexeme TKAll }
    "who"               { makeLexeme TKWho }
    "aka"               { makeLexeme TKAka }
    "but"               { makeLexeme TKBut }

    -- Union Tags
    "Tag"               { makeLexeme TKTag }
    "case"              { makeLexeme TKCase }
    "match"             { makeLexeme TKMatch }
    "default"           { makeLexeme TKDefault }

    @realnewline        { makeLexeme TKNewline }
    @char               { makeLexemeWithChar TKChar }
    @number             { makeLexemeNumber TKNumbers }
    @string             { makeLexemeWithString TKString }
    @registers          { makeLexemeWithString TKType }
    @identifier         { makeLexemeWithString TKIdentifiers }
    @bad_string         { makeLexemeWithString TKError }
    .                   { makeLexemeWithString TKError }

{
-- Las funciones de makeLexeme* son funciones que reciben un token y la
--informacion de este y crea el token como tal dentro de el monad Alex
makeLexemeWithString :: (Pos -> String -> Token) -> AlexInput -> Int
                        -> Alex Token
makeLexemeWithString f (p,_,_,s) lengthBoy = return $ f positionBoy contentBoy
  where contentBoy = take lengthBoy s
        positionBoy = extractPosition p

makeLexemeWithChar :: (Pos -> Char -> Token) -> AlexInput -> Int
                        -> Alex Token
makeLexemeWithChar f (p,_,_,s) _ = return $ f positionBoy contentBoy
  where contentBoy = s !! 1
        positionBoy = extractPosition p

makeLexemeNumber :: (Pos -> String -> Token) -> AlexInput -> Int
                    -> Alex Token
makeLexemeNumber f (p,_,_,s) lengthBoy = return $ f positionBoy contentBoy
 where contentBoy = take lengthBoy s
       positionBoy = extractPosition p

makeLexeme :: (Pos -> Token) -> AlexInput -> Int -> Alex Token
makeLexeme f (p,_,_,_) _ = return $ f (extractPosition p)

-- Funcion que extrae la posicion de un AlexPosn
extractPosition :: AlexPosn -> Pos
extractPosition (AlexPn _ f c) = (f,c)

-- Funcion de ayuda para el parser (a futuro) representa el token EOF
alexEOF :: Alex Token
alexEOF = return (TKEOF (0,0))

-- Funcion que invoca la funcionalidad principal del Lexer haciando uso de
--runAlex, recibe una string como entrada y realiza un analisis lexico sobre
--el para extraer los datos
alexScanTokens :: String -> [Token]
alexScanTokens str
  = lastnl $ map (extractRight . runAlex "") $ go (AlexPn 0 1 1, '\n', [], str)
  where go inp = case (alexScan inp 0) of AlexError _ -> error "lexical error"
                                          AlexSkip inn len        -> go inn
                                          AlexToken inn len act   -> act inp len : go inn
                                          _                       -> []

-- Funcion que extrae el contenido del monad Either en caso de no haber error
extractRight :: Either String b -> b
extractRight (Right x) = x
extractRight (Left x) = error x

lastnl :: [Token] -> [Token]
lastnl xs = case last xs of TKNewline _ -> init xs
                            _           -> xs

--- Funciones de prueba

test = do
  fileName <- getLine
  handle <- openFile fileName ReadMode
  contents <- hGetContents handle
  printTokenList $ alexScanTokens contents

testExample str = do
  handle <- openFile ("../Examples/" ++ str) ReadMode
  contents <- hGetContents handle
  printTokenList $ alexScanTokens contents

testErrors str = do
  handle <- openFile ("../Examples/" ++ str) ReadMode
  contents <- hGetContents handle
  printErrors $ alexScanTokens contents

testSnippet = printTokenList . alexScanTokens

}
