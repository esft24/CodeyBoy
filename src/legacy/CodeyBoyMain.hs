-- Main para correr el lexer
-- Integrantes:
--              Erick Flejan    12-11555
--              Carlos Perez    13-11089

-- CI-4721 Lenguajes de Programacion II

module Main where
import Tokens
import Lexer
import CodeyBoyP    
import System.IO
import System.Environment

segregar :: [String] -> (String, String)
segregar [] = error "No hay argumentos\n"
segregar [x] = if (verificar x) then error "No hay archivo a leer\n" else (x, "")
segregar [x,y] = if (verificar x) then (y, x) else (x, y)
segregar _ = error "Demasiado argumentos"

verificar :: String -> Bool
verificar (x:xs) = x == '-'

main :: IO ()
main = do
  args <- getArgs
  let (file,flag) = segregar args
  handle <- openFile file ReadMode 
  contents <- hGetContents handle
  if flag == "-l" then
    printTokenList $ alexScanTokens contents
  else
    parserBoy $ alexScanTokens contents
