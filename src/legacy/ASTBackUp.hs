-- Tipos Data para el parser de CodeyBoy
-- Integrantes:
--              Erick Flejan    12-11555
--              Carlos Perez    13-11089

-- CI-4721 Lenguajes de Programacion II

module AST where
import Lexer
import Tokens
--import Parser
data Arbol =  ArbolP Programa
              | ArbolI Instruccion
              | ArbolE Expresion
              | ArbolT Type
              | ArbolVacio
              deriving(Show,Eq)

data Programa =         Programa [Import] [Instruccion] deriving(Show,Eq)
      
data Import =           ImportSome Modulo [Who] (Maybe Aka)
                        | ImportAll Modulo [But] (Maybe Aka)
                        deriving(Show,Eq)
      
type But =              Token
type Aka =              Token
type Who =              Token
      
type Modulo =           Token

type Path =             Token

type Identificador =    Token

data Parametro =        PorValor Token
                        | PorReferencia Token
                        deriving(Show,Eq)

data Instruccion =      DeclaracionVariable
                        | ModificacionVariable Identificador Expresion
                        | ModificacionMiembro AccessMember Expresion
                        -- | DefinicionDeTipo TypeName Type
                        | DefinicionDeFuncion Identificador [(Parametro, Type)] Type [Instruccion]
                        | InstIf If
                        | InstMatch Match
                        | InstRepDet RepeticionDet
                        | InstRepIndet RepeticionIndet
                        | InstLlamada Llamada
                        | Print Expresion
                        | Free Identificador
                        | InstReturn (Maybe Expresion)
                        deriving(Show,Eq)

data Type =             IntType
                        | CharType
                        | BoolType
                        | FloatType
                        | ArrayType
                        | StringType
                        | PointerType
                        | TypeNameType TypeName
                        | VoidType
                        | RegType [Instruccion]
                        | UnionType (Maybe [Instruccion]) [(TypeName, [Instruccion])]
                        deriving(Show,Eq)

type TypeName =         Token

type If =               [(Expresion, [Instruccion])]

data Match =            Match Identificador [Case] deriving(Show,Eq)

data Case =             Case TypeName [Instruccion] deriving(Show,Eq)

data RepeticionDet =    RepDet Identificador Type Token Token (Maybe Token) [Instruccion]
                        | RepDetArray Identificador Type Identificador [Instruccion]
                        | RepDetArrayExplicit Identificador Type [Expresion] [Instruccion]
                        deriving(Show,Eq)

data RepeticionIndet =  RepeticionIndet Expresion [Instruccion] deriving(Show,Eq)

data Expresion =        ExpLlamada Llamada
                        | ExpVariable Identificador
                        | ExpAcceso AccessMember
                        | ExpArray [Expresion]
                        | ExpNumero Number
                        | ExpCaracter Token
                        | ExpTrue
                        | ExpFalse
                        | ExpString StringBoy
                        | ExpMalloc Expresion
                        | ExpInput
                        | ExpBlock DefinicionDeBloque
                        | ExpUBlock DefinicionDeBloqueUnion
                        | ExpNot Expresion
                        | ExpOr { operadorIzq, operadorDer :: Expresion }
                        | ExpAnd { operadorIzq, operadorDer :: Expresion }
                        | ExpGreater { operadorIzq, operadorDer :: Expresion }
                        | ExpLesser { operadorIzq, operadorDer :: Expresion }
                        | ExpGreaterEqual { operadorIzq, operadorDer :: Expresion }
                        | ExpLesserEqual { operadorIzq, operadorDer :: Expresion }
                        | ExpEqual { operadorIzq, operadorDer :: Expresion }
                        | ExpNotEqual { operadorIzq, operadorDer :: Expresion }
                        | ExpPlus { operadorIzq, operadorDer :: Expresion }
                        | ExpMinus { operadorIzq, operadorDer :: Expresion }
                        | ExpProduct { operadorIzq, operadorDer :: Expresion }
                        | ExpDivision { operadorIzq, operadorDer :: Expresion }
                        | ExpMod { operadorIzq, operadorDer :: Expresion }
                        | ExpWholeDivision { operadorIzq, operadorDer :: Expresion }
                        | ExpUminus Expresion
                        deriving(Show,Eq)

type Number =           Token
type StringBoy =        Token

type AccessMember =     [Identificador]

data Llamada =        Llamada Identificador [Expresion]
                      | LlamadaModulo TypeName Identificador [Expresion]
                      deriving(Show,Eq)

type DefinicionDeBloque = [(Identificador, Expresion)]
type DefinicionDeBloqueUnion = (TypeName, DefinicionDeBloque)

{-
printPrograma :: Programa -> IO ()
printPrograma = putStrLn . show
-}

tabs :: Int -> String
tabs n = replicate n '\t'

printPrograma :: Programa -> String
printPrograma (Programa imports instrucciones) = "Programa:\n" ++ printImports (reverse imports) 1 ++ printInstrucciones (reverse instrucciones) 1

printImports :: [Import] -> Int -> String
printImports [] number = tabs number ++ "Imports:\n" ++ tabs (number+1) ++ "-\n"
printImports [x] number = tabs number ++ "Imports:\n" ++ printImport x (number+1)
printImports (x:xs) number = printImports xs number ++ printImport x (number+1)

printInstrucciones :: [Instruccion] -> Int -> String
printInstrucciones [] number = tabs number ++ "Instrucciones:\n" ++ tabs (number+1) ++ "-\n"
printInstrucciones [x] number = tabs number ++ "Instrucciones:\n" ++ printInstruccion x (number+1)
printInstrucciones (x:xs) number = printInstrucciones xs number ++ printInstruccion x (number+1)

printImport :: Import -> Int -> String
printImport (ImportSome modulo who aka) number = tabs number ++ "Modulo de nombre: " ++ show (tknContent modulo) ++ "\n" ++ printWho (reverse who) number ++ printAka aka number
printImport (ImportAll modulo but aka) number = tabs number ++ "Modulo de nombre: " ++ show (tknContent modulo) ++ "\n" ++ printBut (reverse but) number ++ printAka aka number

--printInstruccion (DeclaracionVariable identificador tipo maybeExpresion ) number = tabs number ++ "Declaracion de variable:\n" ++ tabs (number+1) ++ "Variable: " ++ show (tknContent identificador) ++ "\n" ++ tabs (number+1) ++ "Tipo: " ++ printTipo tipo (number+1) ++ printMaybeExpresion maybeExpresion (number+1)
printInstruccion :: Instruccion -> Int -> String
printInstruccion (ModificacionVariable identificador expresion) number = tabs number ++ "Modificacion de Variable:\n" ++ tabs (number+1) ++ "Variable: " ++ show (tknContent identificador) ++ "\n" ++ tabs (number+1) ++ "Asignacion: " ++ printExpresion expresion (number+2)
printInstruccion (ModificacionMiembro miembro expresion) number = tabs number ++ "Modificacion de Variable de Record:\n" ++ tabs (number+1) ++ "Target: " ++ printAccessMember miembro ++ "\n" ++ tabs (number+1) ++ "Asignacion: " ++ printExpresion expresion (number+2)
--printInstruccion (DefinicionDeTipo typename tipo) number = tabs number ++ "Definicion de Tipo:\n" ++ tabs (number+1) ++ "Nombre de Tipo nuevo: " ++ show (tknContent typename) ++ "\n" ++ tabs (number+1) ++ "Tipo: " ++ printTipo tipo (number+2)
printInstruccion (DefinicionDeFuncion identificador parametros tipo instrucciones) number = tabs number ++ "Definicion de funcion:\n" ++ tabs (number+1) ++ "Nombre: " ++ show (tknContent identificador) ++ "\n" ++ tabs (number+1) ++ "Parametros:\n" ++ printParametros (reverse parametros) (number+2) ++ "\n" ++ tabs (number+1) ++  "Tipo de retorno: " ++ printTipo tipo (number+2)  ++ printInstrucciones (reverse instrucciones) (number+1)
printInstruccion (InstIf instIf) number = tabs number ++ "Seleccion if:\n" ++ printIfs (reverse instIf) (number+1)
printInstruccion (InstMatch match) number = tabs number ++ "Seleccion match:\n" ++ printMatch match (number+1)
printInstruccion (InstRepDet repeticionDet) number = tabs number ++ "Repeticion determinada:\n" ++ printRepeticionDet repeticionDet (number+1)
printInstruccion (InstRepIndet repeticionIndet) number = tabs number ++ "Repeticion indeterminada:\n" ++ printRepeticionIndet repeticionIndet (number+1)
printInstruccion (InstLlamada llamada) number = tabs number ++ "Llamada a funcion:\n" ++ printLlamada llamada (number+1)
printInstruccion (Print expresion) number = tabs number ++ "Impresion en pantalla:\n" ++ tabs (number+1) ++ "Expresion a imprimir: " ++ printExpresion expresion (number+2)
printInstruccion (Free identificador) number = tabs number ++ "Liberacion de apuntador:\n" ++ tabs (number+1) ++ "Variable: " ++ show (tknContent identificador) ++ "\n"
printInstruccion (InstReturn (Just expresion)) number = tabs number ++ "Instruccion return:\n" ++ tabs (number+1) ++ "Expresion de retorno: " ++ printExpresion expresion (number+1)
printInstruccion (InstReturn Nothing) number = tabs number ++ "Instruccion return vacia\n"

printBut :: [But] -> Int -> String
printBut [] _ = ""
printBut [x] number = tabs number ++ "Funciones ignoradas:\n" ++ tabs (number+1) ++ "Nombre de la funcion: " ++ show (tknContent x) ++ "\n"
printBut (x:xs) number = printBut xs number ++ tabs (number+1) ++ "Nombre de la funcion: " ++ show (tknContent x) ++ "\n"

printWho :: [Who] -> Int -> String
printWho [] _ = ""
printWho [x] number = tabs number ++ "Funciones importadas:\n" ++ tabs (number+1) ++ "Nombre de la funcion: " ++ show (tknContent x) ++ "\n"
printWho (x:xs) number = printWho xs number ++ tabs (number+1) ++ "Nombre de la funcion: " ++ show (tknContent x) ++ "\n"

printAka :: Maybe Aka -> Int -> String
printAka Nothing  _ = ""
printAka (Just x) number = tabs number ++ "Nombre del modulo dentro del programa: " ++ show (tknContent x) ++ "\n"

printMaybeExpresion :: Maybe Expresion -> Int -> String
printMaybeExpresion Nothing _ = ""
printMaybeExpresion (Just x) number = tabs number ++ "Asignacion: " ++ printExpresion x (number+1)

printExpresion :: Expresion -> Int -> String
printExpresion (ExpLlamada llamada) number = "Llamada\n" ++ printLlamada llamada number
printExpresion (ExpVariable identificador) number = "Variable\n" ++ tabs number ++ "Variable: " ++ show (tknContent identificador) ++ "\n"
printExpresion (ExpAcceso accessMember) number = printAccessMember accessMember
printExpresion (ExpArray array) number = "Arreglo\n" ++ tabs number ++ "Contenido: " ++ show array ++ "\n"
printExpresion (ExpNumero numberBoy) number = "Numero\n" ++ tabs number ++ "Valor: " ++ show (tknContent numberBoy) ++ "\n"
printExpresion (ExpCaracter char) number = "Caracter\n" ++ tabs number ++ "Valor: " ++ show (tknContent char) ++ "\n"
printExpresion (ExpTrue) _ = "True\n"
printExpresion (ExpFalse) _ = "False\n"
printExpresion (ExpString stringBoy) number = "String\n" ++ tabs number ++ "Contenido: " ++ show (tknContent stringBoy)
printExpresion (ExpMalloc expresion) number = "Malloc\n" ++ tabs number ++ printExpresion expresion (number+1)
printExpresion (ExpInput) _ = "Input\n"
printExpresion (ExpBlock definicionDeBloque) number = "Definicion de bloque\n" ++ printDefinicionBloque (reverse definicionDeBloque) number
printExpresion (ExpUBlock (variante, definicionDeBloque)) number = "Definicion de bloque Union\n" ++ tabs number ++ "Nombre del Variante: " ++ show (tknContent variante) ++ "\n" ++ printDefinicionBloque definicionDeBloque number
printExpresion (ExpNot expresion) number = "Negacion de expresion\n" ++ tabs number ++ "Expresion: " ++ printExpresion expresion (number+1)
printExpresion expOr@(ExpOr _ _) number = "Conjuncion de expresiones\n" ++ tabs number ++ "Operador izquierdo: " ++ printExpresion (operadorIzq expOr) (number+1) ++ tabs number ++ "Operador derecho: " ++ printExpresion (operadorDer expOr) (number+1)
printExpresion expAnd@(ExpAnd _ _) number = "Disyuncion de expresiones\n" ++ tabs number ++ "Operador izquierdo: " ++ printExpresion (operadorIzq expAnd) (number+1) ++ tabs number ++ "Operador derecho: " ++ printExpresion (operadorDer expAnd) (number+1)
printExpresion expGreater@(ExpGreater _ _) number = "Comparacion mayor que\n" ++ tabs number ++ "Operador izquierdo: " ++ printExpresion (operadorIzq expGreater) (number+1) ++ tabs number ++ "Operador derecho: " ++ printExpresion (operadorDer expGreater) (number+1)
printExpresion expLesser@(ExpLesser _ _) number = "Comparacion menor que\n" ++ tabs number ++ "Operador izquierdo: " ++ printExpresion (operadorIzq expLesser) (number+1) ++ tabs number ++ "Operador derecho: " ++ printExpresion (operadorDer expLesser) (number+1)
printExpresion expGreaterEqual@(ExpGreaterEqual _ _) number = "Comparacion mayor igual que\n" ++ tabs number ++ "Operador izquierdo: " ++ printExpresion (operadorIzq expGreaterEqual) (number+1) ++ tabs number ++ "Operador derecho: " ++ printExpresion (operadorDer expGreaterEqual) (number+1)
printExpresion expLesserEqual@(ExpLesserEqual _ _) number = "Comparacion menor igual que\n" ++ tabs number ++ "Operador izquierdo: " ++ printExpresion (operadorIzq expLesserEqual) (number+1) ++ tabs number ++ "Operador derecho: " ++ printExpresion (operadorDer expLesserEqual) (number+1)
printExpresion expEqual@(ExpEqual _ _) number = "Comparacion de igualdad\n" ++ tabs number ++ "Operador izquierdo: " ++ printExpresion (operadorIzq expEqual) (number+1) ++ tabs number ++ "Operador derecho: " ++ printExpresion (operadorDer expEqual) (number+1)
printExpresion expNotEqual@(ExpNotEqual _ _) number = "Comparacion de desigualdad\n" ++ tabs number ++ "Operador izquierdo: " ++ printExpresion (operadorIzq expNotEqual) (number+1) ++ tabs number ++ "Operador derecho: " ++ printExpresion (operadorDer expNotEqual) (number+1)
printExpresion expPlus@(ExpPlus _ _) number = "Suma\n" ++ tabs number ++ "Operador izquierdo: " ++ printExpresion (operadorIzq expPlus) (number+1) ++ tabs number ++ "Operador derecho: " ++ printExpresion (operadorDer expPlus) (number+1)
printExpresion expMinus@(ExpMinus _ _) number = "Resta\n" ++ tabs number ++ "Operador izquierdo: " ++ printExpresion (operadorIzq expMinus) (number+1) ++ tabs number ++ "Operador derecho: " ++ printExpresion (operadorDer expMinus) (number+1)
printExpresion expProduct@(ExpProduct _ _) number = "Multiplicacion\n" ++ tabs number ++ "Operador izquierdo: " ++ printExpresion (operadorIzq expProduct) (number+1) ++ tabs number ++ "Operador derecho: " ++ printExpresion (operadorDer expProduct) (number+1)
printExpresion expDivision@(ExpDivision _ _) number = "Division\n" ++ tabs number ++ "Operador izquierdo: " ++ printExpresion (operadorIzq expDivision) (number+1) ++ tabs number ++ "Operador derecho: " ++ printExpresion (operadorDer expDivision) (number+1)
printExpresion expMod@(ExpMod _ _) number = "Modulo\n" ++ tabs number ++ "Operador izquierdo: " ++ printExpresion (operadorIzq expMod) (number+1) ++ tabs number ++ "Operador derecho: " ++ printExpresion (operadorDer expMod) (number+1)
printExpresion expWholeDivision@(ExpWholeDivision _ _) number = "Division entera\n" ++ tabs number ++ "Operador izquierdo: " ++ printExpresion (operadorIzq expWholeDivision) (number+1) ++ tabs number ++ "Operador derecho: " ++ printExpresion (operadorDer expWholeDivision) (number+1)
printExpresion (ExpUminus expresion) number = "Negacion unaria\n" ++ tabs number ++ "Expresion: " ++ printExpresion expresion (number+1)

printTipo :: Type -> Int -> String
printTipo IntType _ = "Entero\n"
printTipo CharType _ = "Caracter\n"
printTipo BoolType _ = "Booleano\n"
printTipo FloatType _ = "Punto Flotante\n"
printTipo ArrayType _ = "Arreglo\n"
printTipo StringType _ = "String\n"
printTipo PointerType _ = "Apuntador\n"
printTipo (TypeNameType typeName) _ = show (tknContent typeName) ++ "\n"
printTipo VoidType _ = "Void\n"
printTipo (RegType instrucciones) number = "Registro\n" ++ printInstrucciones (reverse instrucciones) (number+1)
printTipo (UnionType maybeInstrucciones tags) number = "Union\n" ++ printMaybeInstrucciones maybeInstrucciones number ++ tabs number ++ "Variantes:\n" ++ printTags (reverse tags) (number+1)

printParametros :: [(Parametro, Type)] -> Int -> String
printParametros [] number = tabs number ++ "-"
printParametros [(par,tipo)] number = tabs number ++ printParametro par ++ tabs number ++ "Tipo: " ++ printTipo tipo (number+1)
printParametros ((par,tipo):xs) number = printParametros xs number ++ tabs number ++ printParametro par ++ tabs number ++ "Tipo: " ++ printTipo tipo (number+1)

printIfs :: If -> Int -> String
printIfs [(cond, insts)] number = tabs number ++ "Condicion: " ++ printExpresion cond (number+1) ++ printInstrucciones insts (number+1)
printIfs ((cond, insts):xs) number = printIfs xs number ++ tabs number ++ "Condicion: " ++ printExpresion cond (number+1) ++ printInstrucciones insts (number+1)

printMatch :: Match -> Int -> String
printMatch (Match identificador cases) number = tabs number ++ "Seleccion Match: " ++ show (tknContent identificador) ++ "\n" ++ tabs number ++ "Casos: \n" ++ printCases (reverse cases) (number+1)

printCases :: [Case] -> Int -> String
printCases [] number = tabs number ++ "-"
printCases [(Case tipo instrucciones)] number = tabs number ++ "Caso: \n" ++ tabs (number+1) ++ "Nombre del caso: " ++ show (tknContent tipo) ++ "\n" ++ printInstrucciones instrucciones (number+1)       
printCases ((Case tipo instrucciones):xs) number = printCases xs number ++ tabs number ++ "Caso:\n" ++ tabs (number+1) ++ "Nombre del caso: " ++ show (tknContent tipo) ++ "\n" ++ printInstrucciones instrucciones (number+1)

printRepeticionDet :: RepeticionDet -> Int -> String
printRepeticionDet (RepDet identificador tipo desde hasta mediante instrucciones) number = tabs number ++ "Contador: " ++ show (tknContent identificador) ++ "\n" ++ tabs number ++ "Tipo: " ++ printTipo tipo (number+2) ++ tabs (number+1) ++ "Desde: " ++ show (tknContent desde) ++ "\n" ++ tabs (number+1) ++ "Hasta: " ++ show (tknContent hasta) ++ "\n" ++ printBy mediante (number+1) ++  printInstrucciones instrucciones (number + 1)
printRepeticionDet (RepDetArray identificador tipo forma instrucciones) number = tabs number ++ "Iterable: " ++ show (tknContent identificador) ++ "\n" ++ tabs (number+1) ++ "De tipo: " ++ printTipo tipo (number+1) ++ "\n" ++ tabs (number+1) ++ "Formado por: " ++ show (tknContent forma) ++  "\n" ++ printInstrucciones instrucciones (number+1)
printRepeticionDet (RepDetArrayExplicit identificador tipo arreglo instrucciones) number = tabs number ++ "Iterable: " ++ show (tknContent identificador) ++ "\n" ++ tabs (number+1) ++ "De tipo: " ++ printTipo tipo (number+1) ++ "\n" ++ tabs (number+1) ++ "Formado por: " ++ show arreglo ++ "\n" ++ printInstrucciones instrucciones (number+1)

printBy :: Maybe Token -> Int -> String
printBy Nothing _ = ""
printBy (Just x) n = tabs n ++ "Mediante: " ++ show (tknContent x) ++ "\n"

printRepeticionIndet :: RepeticionIndet -> Int -> String
printRepeticionIndet (RepeticionIndet cond instrucciones) number = tabs number ++ "Condicion: " ++ printExpresion cond (number+1) ++ printInstrucciones instrucciones number

printLlamada :: Llamada -> Int -> String
printLlamada (Llamada identificador expresiones) number = tabs number ++ "Llamada a funcion: " ++ show (tknContent identificador) ++ "\n" ++ tabs (number+1) ++ "con Argumentos:\n" ++ printArgumentos expresiones (number+2)
printLlamada (LlamadaModulo modulo identificador expresiones) number = tabs number ++ "Llamada a funcion externa: " ++ show (tknContent identificador) ++ "\n" ++ tabs number ++ "Del Modulo: " ++ show (tknContent modulo)

printArgumentos :: [Expresion] -> Int -> String
printArgumentos [] num = tabs num ++ "-\n"
printArgumentos [exp] num = tabs num ++ printExpresion exp num ++ "\n"
printArgumentos (exp:xs) num = printArgumentos xs num ++ tabs num ++ printExpresion exp num ++ "\n"

printAccessMember :: [Identificador] -> String 
printAccessMember list = init $ foldl (\ x y -> (show (tknContent y)) ++ "." ++ x) "" (reverse list)

printDefinicionBloque :: DefinicionDeBloque -> Int -> String
printDefinicionBloque [] number = tabs number ++ "-\n"
printDefinicionBloque [(identificador, exp)] number = tabs number ++ "Se Asigna a: " ++ show (tknContent identificador) ++ "\n" ++ tabs number ++ "La expresion: " ++ printExpresion exp (number+1) 
printDefinicionBloque ((identificador, exp):xs) number = printDefinicionBloque xs number ++ tabs number ++ "Se Asigna a: " ++ show (tknContent identificador) ++ "\n" ++ tabs number ++ "La expresion: " ++ printExpresion exp (number+1)

printMaybeInstrucciones :: Maybe [Instruccion] -> Int -> String
printMaybeInstrucciones Nothing _ = ""
printMaybeInstrucciones (Just instrucciones) number = tabs number ++ "Valores Generales: \n" ++ printInstrucciones instrucciones (number+1) 

printTags :: [(TypeName, [Instruccion])] -> Int -> String
printTags [] number = tabs number ++ "-\n"
printTags [(tipo, instrucciones)] number = tabs number ++ "Nombre: " ++ show (tknContent tipo) ++ "\n" ++ tabs number ++ "Declaraciones:\n" ++ printInstrucciones instrucciones (number+1) ++ "\n"
printTags ((tipo, instrucciones):xs) number = printTags xs number ++ tabs number ++ "Nombre: " ++ show (tknContent tipo) ++ "\n" ++ tabs number ++ "Declaraciones:\n" ++ printInstrucciones instrucciones (number+1)

printParametro :: Parametro -> String
printParametro (PorValor par) = "Parametro por Valor de nombre: " ++ show (tknContent par) ++ "\n"
printParametro (PorReferencia par) = "Parametro por Referencia de nombre: " ++ show (tknContent par) ++ "\n"
