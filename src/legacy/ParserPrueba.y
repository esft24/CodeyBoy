{
module ParserPrueba where
import Lexer
import Tokens
import AST
import System.IO
import System.Environment
import Control.Monad.State
}

%name parserBoy
%monad { MonadEstado }

%tokentype { Token }
%error { parseError }

%token
    Int               { TKIntType _ }
    if                { TKIf _ }
    otherwise         { TKOtherwise _ }
    let               { TKLet _ }
    equal             { TKAssign _ }
    colon             { TKTypeDef _ }
    begin             { TKOpenBracket _ }
    end               { TKCloseBracket _ }
    open              { TKOpenParenthesis _ }
    close             { TKCloseParenthesis _ }
    else              { TKElse _ }
    plus              { TKPlus _ }
    minus             { TKMinus _ }
    mult              { TKMultiplication _ }
    wdiv              { TKWholeDivision _ }
    div               { TKDivision _ }
    mod               { TKMod _ }
    Nl                { TKNewline _ }
    number            { TKNumbers _ _ }
    identifier        { TKIdentifiers _ _ }

-- PRECEDENCIAS

%left plus minus
%left mult div mod wdiv 
%right uminus

%nonassoc then
%nonassoc else

%%

START: Nl INSTRUCCIONES                                                   { Programa [] $2 }
       | INSTRUCCIONES                                                    { Programa [] $1 }

INSTRUCCIONES:  INSTRUCCIONES Nl INSTRUCCION                              { $3:$1 }
                | INSTRUCCION                                             { $1:[] }

INSTRUCCION:  DEFVARIABLE                                                 { $1 }
              | MODVARIABLE                                               { $1 }
              | SELECCIONIF                                               { InstIf $1 }

DEFVARIABLE:  let identifier colon Int ACTUALDEF                          { DeclaracionVariable $2 IntType $5 }

ACTUALDEF:    {- Vacio -}                                                 { Nothing }
              | equal EXPRESION                                           { Just $2 }

MODVARIABLE:  identifier equal EXPRESION                                  { ModificacionVariable $1 $3 }

SELECCIONIF:  if EXPRESION begin INSTRUCCIONES Nl end   %prec then        {% do {expresion <- get $2;} [($2, (reverse $4))] }
              --| if EXPRESION begin INSTRUCCIONES Nl end LISTAELSE         { ($2, (reverse $4)):(reverse $7) }

-- Elses de los if
--LISTAELSE:    LISTAELSE else EXPRESION begin INSTRUCCIONES Nl end         { ($3 , (reverse $5)):$1 }
              --| else otherwise begin INSTRUCCIONES Nl end                 { [(ExpTrue, (reverse $4))] }
              --| else EXPRESION begin INSTRUCCIONES Nl end                 { [($2, (reverse $4))] }
              --| LISTAELSE else otherwise begin INSTRUCCIONES Nl end       { (ExpTrue , (reverse $5)):$1 }

EXPRESION:    identifier                                                  {% put ArbolE (ExpVariable $1) }
              | number       
              | EXPRESION plus EXPRESION                                  {% do { left <- get $1; right <- get $3; put ArbolE (ExpPlus (extractExpresion left) (extractExpresion right))} }


{
type Contenido = (Nombre, Categoria, Alcance, Type)
type Nombre = String
type Categoria = String
type Alcance = Int

type Tabla = [(Nombre,Contenido)]

type Pila = [Int]

type LBC = (Tabla, Pila, Int)

type Estado = Arbol

type MonadEstado = State Estado

estadoInicial :: Estado
estadoInicial = ArbolVacio

funcion :: MonadEstado ()
funcion = do
  x <- get
  let expresionNumero = ArbolE (ExpNumero (TKNumbers (1,1) 5.0))
  put expresionNumero

extractExpresion :: Estado -> Expresion
extractExpresion (ArbolE x) = x

extractInstruccion :: Estado -> Instruccion
extractInstruccion (ArbolI x) = x

extractPrograma :: Estado -> Programa
extractPrograma (ArbolP x) = x

extractType :: Estado -> Type
extractType (ArbolT x) = x

principal = execState funcion estadoInicial

parseError [] = error "Final Inesperado"
parseError ts = error $ "Token Inesperado: \n" ++ (printToken $ head ts)
}