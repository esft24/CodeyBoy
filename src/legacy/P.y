-- Parser de CodeyBoy
-- Integrantes:
--              Erick Flejan    12-11555
--              Carlos Perez    13-11089

-- CI-4721 Lenguajes de Programacion II

{
module Parser where
import Lexer
import Tokens
import AST
import System.IO
import System.Environment
import Control.Monad.State
}
-- [Token] -> Tabla ()
%name parserBoy 
%monad { Tabla }

%tokentype { Token }
%error { parseError }

%token
    Int               { TKIntType _ }
    let               { TKLet _ }
    equal             { TKAssign _ }
    colon             { TKTypeDef _ }
    Nl                { TKNewline _ }
    number            { TKNumbers _ _ }
    identifier        { TKIdentifiers _ _ }
    plus              { TKPlus _ }
%left plus

%%

START: INSTS { Prog $1 }

INSTS: INSTS Nl IN { ($3:$1) }
    |  IN          { $1:[] }

IN: MODVAR { $1 }
  | DEFVAR { DefVar }
   
DEFVAR: let identifier colon Int  {% do{if False then liftIO $ print "hola" else modify ($2:); return ()} }

MODVAR: identifier equal EXP   { Mod $1 $3 }

EXP: number                    { ExpN $1 }
  |  identifier                { ExpI $1 }
  |  EXP plus EXP              { ExpP $1 $3 }


{

parseError = error "ERROR"

type Tabla = StateT [Token] IO

data AST = Mod Ident AST
         | Prog [AST]
         | ExpN NumP
         | ExpI Ident
         | ExpP AST AST 
         | DefVar
         deriving(Show)

type NumP = Token
type Ident = Token

-- thenT :: Tabla a -> ((AST, [Token]) -> Tabla a) -> Tabla a
-- thenT mon fun = execState 

}