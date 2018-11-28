-- Tokens de CodeyBoy
-- Integrantes:
--              Erick Flejan    12-11555
--              Carlos Perez    13-11089

-- CI-4721 Lenguajes de Programacion II

--Aun falta agregar el token de break

module Tokens where

--Sinonimo de una tupla de enteros que usamos para la posicion representado por:
-- (fila, columna)
type Pos = (Int, Int)

-- Tipo Token creado para guardar los tokens encontrados en el programa a
-- reconocer
data Token =
  -- Tipos
  TKIntType { tknPos :: Pos }                           |
  TKBoolType { tknPos :: Pos }                          |
  TKCharType { tknPos :: Pos }                          |
  TKFloatType { tknPos :: Pos }                         |
  TKVoidType { tknPos :: Pos }                          |
  TKArrayType { tknPos :: Pos }                         |
  TKStringType { tknPos :: Pos }                        |
  TKBoyType { tknPos :: Pos }                           |
  TKRegType { tknPos :: Pos }                           |
  TKUnionType { tknPos :: Pos }                         |
  TKPointerType { tknPos :: Pos }                       |
  TKType { tknPos :: Pos, tknString :: String }         |
  -- Estructuras de Control
  TKWhile { tknPos :: Pos }                             |
  TKFor { tknPos :: Pos }                               |
  TKFrom { tknPos :: Pos }                              |
  TKTo { tknPos :: Pos }                                |
  TKBy { tknPos :: Pos }                                |
  TKIn { tknPos :: Pos }                                |
  TKIf { tknPos :: Pos }                                |
  TKElse { tknPos :: Pos }                              |
  TKOtherwise { tknPos :: Pos }                         |
  TKBreak { tknPos :: Pos}                              |
  -- Asignacion
  TKFunc { tknPos :: Pos }                              |
  TKLet { tknPos :: Pos }                               |
  TKAssign { tknPos :: Pos }                            |
  TKTypeDef { tknPos :: Pos }                           |
  TKRef { tknPos :: Pos }                               |
  TKPirata { tknPos :: Pos }                            |
  -- Bloques
  TKOpenBracket { tknPos :: Pos }                       |
  TKCloseBracket { tknPos :: Pos }                      |
  TKOpenParenthesis { tknPos :: Pos }                   |
  TKCloseParenthesis { tknPos :: Pos }                  |
  TKOpenSqrBracket { tknPos :: Pos }                    |
  TKCloseSqrBracket { tknPos :: Pos }                   |
  -- Operadores Logicos
  TKEqual { tknPos :: Pos }                             |
  TKUnequal { tknPos :: Pos }                           |
  TKAnd { tknPos :: Pos }                               |
  TKOr { tknPos :: Pos }                                |
  TKNot { tknPos :: Pos }                               |
  -- Operadores numericos
  TKGreater { tknPos :: Pos }                           |
  TKLesser { tknPos :: Pos }                            |
  TKGreaterEqual { tknPos :: Pos }                      |
  TKLesserEqual { tknPos :: Pos }                       |
  TKPlus { tknPos :: Pos }                              |
  TKMinus { tknPos :: Pos }                             |
  TKMultiplication { tknPos :: Pos }                    |
  TKDivision { tknPos :: Pos }                          |
  TKWholeDivision { tknPos :: Pos }                     |
  TKMod { tknPos :: Pos }                               |
  -- Literales
  TKIdentifiers { tknPos :: Pos, tknString :: String }  |
  TKNumbers { tknPos :: Pos, tknNumber :: String }       |
  TKString { tknPos :: Pos, tknString :: String }       |
  TKChar { tknPos :: Pos, tknChar :: Char }             |
  TKTrue { tknPos :: Pos }                              |
  TKFalse { tknPos :: Pos }                             |
  TKComma { tknPos :: Pos }                             |
  TKPoint { tknPos :: Pos }                             |
  TKDollar { tknPos :: Pos }                            |
  TKReturn { tknPos :: Pos }                            |
  -- Modularidad
  TKBring { tknPos :: Pos }                             |
  TKTheBoys { tknPos :: Pos }                           |
  TKAll { tknPos :: Pos }                               |
  TKWho { tknPos :: Pos }                               |
  TKAka { tknPos :: Pos }                               |
  TKBut { tknPos :: Pos }                               |
  -- Errores/Invalidos
  TKError { tknPos :: Pos, tknString :: String }        |
  --  Terminales
  TKNewline { tknPos :: Pos }                           |
  TKEOF { tknPos :: Pos}                                |
  -- Tokens para Union Tags
  TKTag { tknPos :: Pos }                               |
  TKWith { tknPos :: Pos }                              |
  TKCase { tknPos :: Pos }                              |
  TKMatch { tknPos :: Pos }                             |
  TKDefault { tknPos :: Pos }                           |
  TKBoy { tknPos :: Pos, tknString :: String }          |
  -- Tokens funciones polimorficas
  TKInput { tknPos :: Pos }                             |
  TKPrint { tknPos :: Pos }                             |
  TKMalloc { tknPos :: Pos }                            |
  TKFree { tknPos :: Pos }                              |
  TKStringify { tknPos :: Pos }
  deriving(Eq, Ord)

-- Instancias de Show
instance Show Token where
  show (TKIntType _)                  = "Tipo de dato: Int"
  show (TKBoolType _)                 = "Tipo de dato: Bool"
  show (TKCharType _)                 = "Tipo de dato: Char"
  show (TKFloatType _)                = "Tipo de dato: Float"
  show (TKVoidType _)                 = "Tipo de dato: Void"
  show (TKArrayType _)                = "Tipo de dato: Array"
  show (TKStringType _)               = "Tipo de dato: String"
  show (TKRegType _)                  = "Tipo de dato: Reg"
  show (TKBoyType _)                  = "Palabra reservada: Boy"
  show (TKUnionType _)                = "Tipo de dato: Union"
  show (TKPointerType _)              = "Tipo de dato: Pointer"
  show (TKType _ name)                = "Tipo de dato construido de nombre: "
                                         ++ name
  show (TKWhile _)                    = "Palabra reservada: while"
  show (TKFor _)                      = "Palabra reservada: for"
  show (TKFrom _)                     = "Palabra reservada: from"
  show (TKTo _)                       = "Palabra reservada: to"
  show (TKBy _)                       = "Palabra reservada: by"
  show (TKIn _)                       = "Palabra reservada: in"
  show (TKIf _)                       = "Palabra reservada: if"
  show (TKElse _)                     = "Simbolo reservado: |"
  show (TKOtherwise _)                = "Simbolo reservado: _"
  show (TKBreak _)                    = "Palabra reservada: break"
  show (TKFunc _)                     = "Palabra reservada: func"
  show (TKLet _)                      = "Palabra reservada: let"
  show (TKAssign _)                   = "Simbolo reservado: ="
  show (TKTypeDef _)                  = "Simbolo reservado: :"
  show (TKRef _)                      = "Simbolo reservado: ::"
  show (TKPirata _)                   = "Leave me treasure alone boy! ARGHHHH!!"
  show (TKOpenBracket _)              = "Simbolo reservado: {"
  show (TKCloseBracket _)             = "Simbolo reservado: }"
  show (TKOpenParenthesis _)          = "Simbolo reservado: ("
  show (TKCloseParenthesis _)         = "Simbolo reservado: )"
  show (TKOpenSqrBracket _)           = "Simbolo reservado: ["
  show (TKCloseSqrBracket _)          = "Simbolo reservado: ]"
  show (TKEqual _)                    = "Simbolo reservado: =="
  show (TKUnequal _)                  = "Simbolo reservado: /="
  show (TKAnd _)                      = "Simbolo reservado: &&"
  show (TKOr _)                       = "Simbolo reservado: ||"
  show (TKNot _)                      = "Simbolo reservado: !"
  show (TKGreater _)                  = "Simbolo reservado: >"
  show (TKLesser _)                   = "Simbolo reservado: <"
  show (TKGreaterEqual _)             = "Simbolo reservado: >="
  show (TKLesserEqual _)              = "Simbolo reservado: <="
  show (TKPlus _)                     = "Simbolo reservado: +"
  show (TKMinus _)                    = "Simbolo reservado: -"
  show (TKMultiplication _)           = "Simbolo reservado: *"
  show (TKDivision _)                 = "Simbolo reservado: /"
  show (TKWholeDivision _)            = "Simbolo reservado: //"
  show (TKMod _)                      = "Simbolo reservado: %"
  show (TKIdentifiers _ name)         = "Identificador: " ++ name
  show (TKNumbers _ number)           = "Numero: " ++ show number
  show (TKString _ string)            = "String: " ++ string
  show (TKChar _ char)                = "Caracter: " ++ [char]
  show (TKTrue _)                     = "Palabra reservada: True"
  show (TKFalse _)                    = "Palabra reservada: False"
  show (TKComma _)                    = "Simbolo reservado: ,"
  show (TKPoint _)                    = "Simbolo reservado: ."
  show (TKDollar _)                   = "Simbolo reservado: $"
  show (TKReturn _)                   = "Palabra reservada: return"
  show (TKPrint _)                    = "Palabra reservada: print"
  show (TKInput _)                    = "Palabra reservada: input"
  show (TKMalloc _)                   = "Palabra reservada: malloc"
  show (TKStringify _)                = "Palabra reservada: stringify"
  show (TKFree _)                     = "Palabra reservada: free"
  show (TKBring _)                    = "Palabra reservada: bring"
  show (TKTheBoys _)                  = "Palabra reservada: the boys"
  show (TKAll _)                      = "Palabra reservada: all"
  show (TKWho _)                      = "Palabra reservada: who"
  show (TKAka _)                      = "Palabra reservada: aka"
  show (TKBut _)                      = "Palabra reservada: but"

  show (TKError _ error)              = "*****Error lexico. " ++ error
  show (TKNewline _)                  = "Salto de linea"
  show (TKEOF _)                      = "Fin del archivo"

  show (TKTag _)                      = "Palabra reservada: Tag"
  show (TKWith _)                     = "Palabra erservada: with"
  show (TKCase _)                     = "Palabra reservada: case"
  show (TKMatch _)                    = "Palabra reservada: match"
  show (TKBoy _ _)                    = "CodeyBoy"
  show (TKDefault _)                  = "Palabra reservada: default"

-- Funcion que imprime en pantalla un token con su posicion
printToken :: Token -> String
printToken t = show t ++ "\nEl Token fue encontrado en la fila " ++ (show $ fst (tknPos t)) ++ " en la columna " ++ (show $ snd (tknPos t)) ++ "\n"

-- Funcion que imprime en pantalla cada uno de los Tokens encontrados en el
--programa a verificar
printTokenList :: [Token] -> IO ()
printTokenList x = mapM_ (putStrLn . printToken) x

-- Funcion que imprime en pantalla cada uno de los tokens que dan error lexico
--para ser analizados, en caso de no haber ninguno, imprime un mensaje de exito
printErrors :: [Token] -> IO ()
printErrors tks
  = case (lookForErrors tks) of
     [] -> putStrLn "Analisis lexico completado correctamente"
     _ -> printTokenList $ lookForErrors tks

-- Funcion que Filtra los Tokens de error en una lista de Tokens
lookForErrors :: [Token] -> [Token]
lookForErrors = filter matchError
  where matchError (TKError _ _) = True
        matchError _ = False

tknContent :: Token -> String
tknContent tk@(TKType _ _) = tknString tk
tknContent tk@(TKChar _ _) = [tknChar tk]
tknContent tk@(TKString _ _) = tknString tk
tknContent tk@(TKNumbers _ _) = tknNumber tk
tknContent tk@(TKIdentifiers _ _) = tknString tk
tknContent _ = ""
