-- Integrantes:
--              Erick Flejan    12-11555
--              Carlos Perez    13-11089

-- CI-4721 Lenguajes de Programacion II

module Main (main) where
import Tokens
import Lexer
import ParserTabla
import AST
import LBC
import Control.Monad.State
import Control.Monad.Writer
import System.IO
import System.Environment
import System.Console.GetOpt
import System.Exit
import TAC
import MachineCode


data Options = Options  { optLexer    :: [Token] -> IO ()
                        , optAST      :: Programa -> IO ()
                        , optSymTable :: Estado -> [ErrorLog] -> IO ()
                        , optTAC      :: [TAC] -> String -> IO ()
                        }

dummy1 :: [Token] -> IO ()
dummy1 _ = return ()

dummy2 :: Programa -> IO ()
dummy2 _ = return ()

dummy3 :: Estado -> [ErrorLog] -> IO ()
dummy3 _ _ = return ()

dummy4 :: [TAC] -> String -> IO ()
dummy4 _ _ = return ()

startOptions :: Options
startOptions = Options dummy1 dummy2 dummy3 dummy4

options :: [OptDescr (Options -> IO Options)]
options =
  [ Option ['l'] ["lexer"]
      (NoArg (\opt -> return opt {optLexer = lexer}))
      "Show Recognized Tokens"

  , Option ['a'] ["ast"]
      (NoArg (\opt -> return opt {optAST = ast}))
      "\"Pretty Print\" AST"

  , Option ['t'] ["\"symtable\""]
      (NoArg (\opt -> return opt {optSymTable = table}))
      "Show Symbol Table"
  
  , Option ['3'] ["\"3ac\""]
      (NoArg (\opt -> return opt {optTAC = tac}))
      "Show 3AC" 
  ]

lexer :: [Token] -> IO ()
lexer tokens = do
  putStrLn "Tokens Reconocidos: \n"
  printTokenList tokens
  return ()

ast :: Programa -> IO ()
ast arbol = do
    putStrLn "Arbol Sintáctico Creado: \n"
    putStrLn $ show arbol
    return ()

table :: Estado -> [ErrorLog] -> IO ()
table tabla errores = do
    putStrLn "Tabla de Símbolos."
    putStrLn $ show $ getLBC tabla
    if null errores
      then
        return ()
      else do
        putStrLn $ "Errores Encontrados: "
        putStrLn $ unlines $ map show errores
        return ()

tac :: [TAC] -> String -> IO ()
tac code str = do
  putStrLn "3AC."
  mapM_ (putStrLn . show) code
  let tacWrite = unlines $ map show code
  writeFile ("./" ++ reverse (drop 4 (reverse str)) ++ ".teen") tacWrite
  return ()

main :: IO()
main = do
  (file:flags) <- getArgs
  handle <- openFile file ReadMode
  contents <- hGetContents handle
  let tokens = alexScanTokens contents
  ((arbol,tabla),logErrores) <- runWriterT $ runStateT (parserBoy $ tokens) estadoInicial
  let funciones = extraerFunciones $ getLBC tabla
  (((), tacEstadoFinal))  <- runStateT (inicioTAC arbol funciones) (estadoInicialTAC (getLBC tabla))
  let tac = getTAC tacEstadoFinal
  let (actions, nonOptions, errors) = getOpt Permute options flags
  opts <- foldl (>>=) (return startOptions) actions

  let Options { optLexer = olexer
              , optAST = oast
              , optSymTable = osymtable
              , optTAC = o3AC
              } = opts

  olexer tokens
  oast arbol
  osymtable tabla logErrores
  o3AC tac file
