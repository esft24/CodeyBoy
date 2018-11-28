module TAC where
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import Control.Monad.State
import Control.Monad.Writer
import System.IO
import System.Environment
import Data.Maybe
import AST
import Tokens
import Debug.Trace
import ParserTabla
import LBC
import Lexer

testTAC :: String -> IO [TAC]
testTAC str = do
  handle <- openFile ("../Examples/" ++ str) ReadMode
  contents <- hGetContents handle
  ((arbol,tabla),logOcurrencias) <- runWriterT $ runStateT (parserBoy $ alexScanTokens contents) estadoInicial

  -- putStrLn $ printLBC $ getLBC tabla
  let funciones = extraerFunciones $ getLBC tabla
  -- liftIO $ putStrLn $ show funciones
  -- putStrLn $ unlines $ map symbolErrorToStr logOcurrencias
  -- putStrLn $ unlines $ map typeErrorToStr logOcurrencias
  (((), tacEstadoFinal))  <- runStateT (inicioTAC arbol funciones) (estadoInicialTAC (getLBC tabla))
  
  if null logOcurrencias
  then do
    mapM_ (putStrLn . show) $ getTAC tacEstadoFinal 
    let tac = unlines $ map show $ getTAC tacEstadoFinal 
    writeFile ("./" ++ reverse (drop 4 (reverse str)) ++ ".teen") tac
    
  else do
    putStr ""
    -- putStrLn $ unlines $ map symbolErrorToStr logOcurrencias
    -- putStrLn $ unlines $ map typeErrorToStr logOcurrencias
  putStrLn $ unlines $ map show $ getTAC tacEstadoFinal

  return (getTAC tacEstadoFinal)
    
   

type Funcion = (String, [Instruccion], [Extra])

data Operando = Operando {
                          getNombreT :: String, 
                          getOffsetT :: Offset
                          }
              | Literal   { literal :: String }
              | Dereferencia { getOperando :: Operando }
              | Temporal     { getNombreT :: String }
              | Vacio        { error :: String }
              | Doble        { opnArr :: Operando, opnExp :: Operando }
              deriving (Eq, Ord)

type Operador = String

instance Show Operando where
  show (Vacio str)                     = str
  show (Literal lit)                   = lit
  show (Temporal temp)                 = temp
  show (Dereferencia opr)              = "*(" ++ (show opr) ++ ")"
  show (Operando str (_, -1))          = str
  show (Operando str (nombre, offset)) = str ++ "_" ++ nombre ++ "_" ++ (show offset)
  show (Doble opn1 opn2)               = "doble" ++ (show opn1) ++ (show opn2) 


isTacVar :: Operando -> Bool
isTacVar (Operando _ _)   = True
isTacVar (Dereferencia _) = True
isTacVar (Temporal _)     = True
isTacVar _                = False


  
type Semilla = Int
type Label = String

data TAC = TACOperationB { 
                          opr  :: Operador,
                          str :: Operando,
                          opn1 :: Operando,
                          opn2 :: Operando 
                          }
          | TACOperationU { 
                          opr  :: Operador,
                          str :: Operando,
                          opn :: Operando
                          }
          | TACStore {
                      str :: Operando,
                      opn :: Operando 
                      }
          | TACGoto { label :: Label }
          | TACIfGoto {
                        cond  :: String,
                        opn   :: Operando,
                        label :: Label
                      }
          | TACLabel { label :: Label }
          | TACReturnNE
          | TACEmpilar { opn :: Operando }
          | TACDesempilar { opn :: Operando }                    
          | TACReturn { opn :: Operando }
          | TACLlamar { label :: String, param :: Int }
          | TACLlamarAsignacion { opn :: Operando, label :: String, param :: Int }
          | TACLlamadaEspecialAsignacion {opn :: Operando, fun :: String}
          | TACLlamadaEspecial {fun :: String}   
          | TACVacio {label :: String}                          
          deriving(Eq)


instance Show TAC where
    show (TACOperationB opr str opn1 opn2)      = (show str) ++ " := " ++ (show opn1) ++ " " ++ opr ++ " " ++ (show opn2)
    show (TACOperationU opr str opn)            = (show str) ++ " := " ++ opr ++ " " ++ (show opn)
    show (TACStore str opn)                     = (show str) ++ " := " ++ (show opn)
    show (TACGoto label)                        = "goto " ++ label
    show (TACIfGoto cond opn label)             = cond ++ " " ++ (show opn) ++ " goto " ++ label
    show (TACLabel label)                       = label ++ ":"
    show TACReturnNE                            = "return"
    show (TACEmpilar opn)                       = "push " ++ (show opn)
    show (TACDesempilar opn)                    = "pop " ++ (show opn)
    show (TACLlamar label par)                  = "call " ++ label ++ " " ++ (show par)
    show (TACLlamarAsignacion opn label par)    = (show opn) ++ " := call " ++ label ++ " " ++ (show par)
    show (TACReturn opn)                        = "return " ++ (show opn)
    show (TACLlamadaEspecialAsignacion opn fun) = (show opn) ++ " := " ++ fun ++ "()"
    show (TACLlamadaEspecial fun)               = fun ++ "()"
    show (TACVacio str)                         = str


fresh :: Semilla -> (Operando, Semilla)
fresh semilla = (Temporal ("$Boy" ++ show semilla), semilla + 1)


freshLabel :: Semilla -> (Label, Semilla)
freshLabel semilla = ("$Label" ++ show semilla, semilla + 1)


data TACEstado = TACEstado {
                            getTAC  :: [TAC],
                            getFuncion :: [TAC],
                            getInFunc :: Bool,
                            getSemilla :: Semilla,
                            getSemillaLabel :: Semilla,
                            getOffsetReg :: Offset,
                            getLBCT :: LBC
                            }

type TACMonad = StateT TACEstado IO

estadoInicialTAC :: LBC -> TACEstado
estadoInicialTAC lbc = (TACEstado [] [] False 1 1 ("",0)) lbc


inOutFunction :: TACMonad ()
inOutFunction = do
  (TACEstado listaTAC funcionTAC inFunc semilla semillaLabel offsetReg lbc) <- get
  put (TACEstado listaTAC funcionTAC (not inFunc) semilla semillaLabel offsetReg lbc)


escribirTAC :: TAC -> TACMonad ()
escribirTAC tac = do
  (TACEstado listaTAC funcionTAC inFunc semilla semillaLabel offsetReg lbc) <- get
  if inFunc then put $ TACEstado listaTAC (funcionTAC ++ [tac]) inFunc semilla semillaLabel offsetReg lbc
            else put $ TACEstado (listaTAC ++ [tac]) funcionTAC inFunc semilla semillaLabel offsetReg lbc

  
getFresh :: TACMonad Operando
getFresh = do
  (TACEstado listaTAC funcionTAC inFunc semilla semillaLabel offsetReg lbc) <- get
  let (nuevoOperando, nuevaSemilla) = fresh semilla
  put (TACEstado listaTAC funcionTAC inFunc nuevaSemilla semillaLabel offsetReg lbc)
  return nuevoOperando

  
getFreshLabel :: TACMonad Label
getFreshLabel = do
  (TACEstado listaTAC funcionTAC inFunc semilla semillaLabel offsetReg lbc) <- get
  let (nuevoLabel, nuevaSemilla) = freshLabel semillaLabel
  put (TACEstado listaTAC funcionTAC inFunc semilla nuevaSemilla offsetReg lbc) 
  return nuevoLabel

  
replaceOffset :: Offset -> TACMonad Offset
replaceOffset newOffset = do
  (TACEstado listaTAC funcionTAC inFunc semilla semillaLabel offsetReg lbc) <- get  
  put (TACEstado listaTAC funcionTAC inFunc semilla semillaLabel newOffset lbc)
  return offsetReg  


getOffsetLeft :: Operando -> Offset
getOffsetLeft (Operando _ offset) = offset
getOffsetLeft (Doble opn _)       = getOffsetLeft opn 
getOffsetLeft _                   = ("", 0)


inicioTAC :: Programa -> [Funcion] -> TACMonad ()
inicioTAC main funciones = do
  escribirTAC (TACGoto "$Main")
  mapM_ escribirFuncionTAC funciones
  escribirTAC (TACLabel "$Main")
  escribirMainTAC main


escribirFuncionTAC :: Funcion -> TACMonad ()
escribirFuncionTAC (nombre, instrucciones, parametros) = do
  escribirTAC (TACLabel nombre)
  let referencias = foldl (\acc (Parametro (nombre, _, modo, offset)) -> if modo then (nombre, offset):acc else acc) [] parametros
  inOutFunction
  mapM_  instruccionesTAC (reverse instrucciones)
  cambiarAReferencias referencias
  mergeTACs
  inOutFunction


mergeTACs :: TACMonad ()
mergeTACs = do
  (TACEstado listaTAC funcionTAC inFunc semilla semillaLabel offsetReg lbc) <- get
  put $ TACEstado (listaTAC ++ funcionTAC) [] inFunc semilla semillaLabel offsetReg lbc

  
cambiarAReferencias :: [(String, Offset)] -> TACMonad ()
cambiarAReferencias referencias = do
  (TACEstado listaTAC funcionTAC inFunc semilla semillaLabel offsetReg lbc) <- get
  let nuevaFuncionTAC = map (dereferenciar referencias) funcionTAC
  put (TACEstado listaTAC nuevaFuncionTAC inFunc semilla semillaLabel offsetReg lbc)


dereferenciar :: [(String, Offset)] -> TAC -> TAC
dereferenciar referencias (TACOperationB opr str opn1 opn2) = (TACOperationB opr (change referencias str) (change referencias opn1) (change referencias opn2))
dereferenciar referencias (TACOperationU opr str opn)       = (TACOperationU opr (change referencias str) (change referencias opn))
dereferenciar referencias (TACStore str opn)                = (TACStore (change referencias str) (change referencias opn))
dereferenciar referencias (TACIfGoto cond opn label)        = (TACIfGoto cond (change referencias opn) label)
dereferenciar _ tac                                         = tac


change :: [(String, Offset)] -> Operando -> Operando
change referencias op@(Operando nombre offset) = if elem (nombre, offset) referencias then (Dereferencia op) else op
change _ x = x


escribirMainTAC :: Programa -> TACMonad ()
escribirMainTAC (Programa _ []) = return ()
escribirMainTAC (Programa _ instrucciones) = mapM_ instruccionesTAC $ reverse instrucciones


instruccionesTAC :: Instruccion -> TACMonad ()
instruccionesTAC (ModificacionSimple lv@(LAccessArray _ _ _ _ _) expresion) = do
  finalVar <- expresionesTAC expresion
  (lValVar, lValExpr) <- lAssignArrayTAC lv "[]="
  let tac = (TACOperationB "[]=" lValExpr lValVar finalVar)
  escribirTAC tac 

instruccionesTAC (ModificacionSimple lValue expresion) = do
  lValVar <- lValueTAC lValue "[]="
  oldOffset <- replaceOffset $ getOffsetLeft lValVar
  finalVar <- expresionesTAC expresion
  replaceOffset oldOffset

  case finalVar of (Vacio _)  -> return ()
                   _          -> case lValVar of (Operando _ _)    -> escribirTAC (TACStore lValVar finalVar)
                                                 (Doble opn1 opn2) -> escribirTAC (TACOperationB "[]=" opn1 opn2 finalVar)
                                                 _                 -> return ()

instruccionesTAC (InstIf expInsts) = do
  let expresiones = map fst expInsts
  let instrucciones = map snd expInsts
  (labels, instTrue) <- generateLabels (reverse expresiones)
  labelSalida <- getFreshLabel
  if instTrue then return () else escribirTAC (TACGoto labelSalida)
  instruccionesTACIf (reverse instrucciones) labels labelSalida
  escribirTAC (TACLabel labelSalida)

instruccionesTAC (InstRepIndet (RepeticionIndet expresion instrucciones)) = do
  labelEntrada <- getFreshLabel
  escribirTAC (TACLabel labelEntrada)
  booleano <- expresionesTAC expresion
  labelSalida <- getFreshLabel
  escribirTAC (TACIfGoto "ifnot" booleano (labelSalida))
  mapM_ instruccionesTAC $ reverse instrucciones
  escribirTAC (TACGoto labelEntrada)
  escribirTAC (TACLabel labelSalida)       

-- TODO Recordar los tipos Sobre los iterables (Char, Int, etc etc)
instruccionesTAC (InstRepDet (RepDet identificador _ expFrom expTo expBy instrucciones offset)) = do
  inicial <- expresionesTAC expFrom
  final <- expresionesTAC expTo
  paso <- case expBy of Nothing -> return (Literal "1")
                        (Just x) -> expresionesTAC x
  let iterando = tknString identificador
  let operandoIt = Operando iterando offset
  escribirTAC (TACStore operandoIt inicial)
  labelEntrada <- getFreshLabel
  labelSalida <- getFreshLabel
  escribirTAC (TACLabel labelEntrada)
  booleano <- getFresh
  escribirTAC (TACOperationB "-" booleano final operandoIt)
  escribirTAC (TACIfGoto "ifeqz" booleano labelSalida)
  mapM_ instruccionesTAC $ reverse instrucciones
  escribirTAC (TACOperationB "+" operandoIt operandoIt paso)
  escribirTAC (TACGoto labelEntrada)
  escribirTAC (TACLabel labelSalida)

instruccionesTAC (InstReturn Nothing) = escribirTAC (TACReturnNE)

instruccionesTAC (InstReturn (Just x)) = do
  operando <- expresionesTAC x
  escribirTAC (TACReturn operando)

instruccionesTAC (InstLlamada (Llamada funcion expresiones)) = do
  parametros <- mapM expresionesTAC expresiones
  mapM_ empilar parametros
  escribirTAC (TACLlamar (tknString funcion) (length expresiones))
  mapM_ desempilar (reverse parametros)

instruccionesTAC (Print exp) = do
  opnExp <- expresionesTAC exp
  empilar opnExp
  escribirTAC (TACLlamadaEspecial "print")
  desempilar opnExp

instruccionesTAC (Free exp) = do
  opnExp <- expresionesTAC exp
  empilar opnExp
  escribirTAC (TACLlamadaEspecial "free")
  desempilar opnExp

instruccionesTAC _ = return ()


empilar :: Operando -> TACMonad ()
empilar operando = escribirTAC (TACEmpilar operando)


desempilar :: Operando -> TACMonad ()
desempilar operando = escribirTAC (TACDesempilar operando)


expresionesTAC :: Expresion -> TACMonad Operando
expresionesTAC (ExpNumero number _)                      = return $ Literal $ tknNumber number
expresionesTAC (ExpTrue _)                               = return $ Literal "True"
expresionesTAC (ExpFalse _)                              = return $ Literal "False"
expresionesTAC (ExpCaracter chr _)                       = return $ Literal $ show $ tknChar chr
expresionesTAC (ExpString str _)                         = return $ Literal $ tknString str
expresionesTAC (ExpStringify exp _)                      = llamadaEspecialExpParam "string" exp
expresionesTAC (ExpPlus izq der _)                       = expresionesTACBinarias "+" izq der
expresionesTAC (ExpMinus izq der _)                      = expresionesTACBinarias "-" izq der
expresionesTAC (ExpProduct izq der _)                    = expresionesTACBinarias "*" izq der
expresionesTAC (ExpDivision izq der _)                   = expresionesTACBinarias "/" izq der
expresionesTAC (ExpMod izq der _)                        = expresionesTACBinarias "%" izq der
expresionesTAC (ExpWholeDivision izq der _)              = expresionesTACBinarias "//" izq der
expresionesTAC (ExpGreater izq der _)                    = expresionesTACBinarias ">" izq der
expresionesTAC (ExpGreaterEqual izq der _)               = expresionesTACBinarias ">=" izq der
expresionesTAC (ExpLesser izq der _)                     = expresionesTACBinarias "<" izq der
expresionesTAC (ExpLesserEqual izq der _)                = expresionesTACBinarias "<=" izq der
expresionesTAC (ExpEqual izq der _)                      = expresionesTACBinarias "==" izq der
expresionesTAC (ExpNotEqual izq der _)                   = expresionesTACBinarias "/=" izq der
expresionesTAC (ExpUminus exp _)                         = expresionesTACUnarias "-" exp
expresionesTAC (ExpNot exp _)                            = expresionesTACUnarias "!" exp
expresionesTAC (ExpOr izq der _)                         = expresionCortoCircuito izq der "||"
expresionesTAC (ExpAnd izq der _)                        = expresionCortoCircuito izq der "&&"

expresionesTAC (ExpMalloc t)                             = return $ Literal $ "malloc"
expresionesTAC (ExpInput _)                              = llamadaEspecialExp "input"
expresionesTAC (ExpLlamada llamada _)                    = llamadaExpTAC llamada
expresionesTAC (ExpRValue lv@(LAccessArray _ _ _ _ _) _) = lValueTAC lv "=[]"
expresionesTAC (ExpRValue lv@(LIdentificador _ _ _ _) _) = lValueTAC lv ":="
expresionesTAC (ExpRValue lv@(LAccessMember _ _ _) _)    = lValueTAC lv "."
expresionesTAC (ExpRValue lv@(LAccessPointer _ _) _)     = lValueTAC lv "*()"
expresionesTAC (ExpArray exps _)                         = getFresh >>= arregloLiteral 0 (reverse exps)
expresionesTAC (ExpBlock defBlock t)                     = (expresionBloque defBlock t) >> (return $ Vacio $ "En proceso")
expresionesTAC e                                         = return $ Vacio $ show e

-- ExpBlock {getDefDeBloque :: DefinicionDeBloque, getTipoEx :: Type }
-- ExpUBlock {getDefDeBloqueU :: DefinicionDeBloqueUnion, getTipoEx :: Type }
-- [(Identificador, Expresion)]
expresionBloque :: DefinicionDeBloque -> Type -> TACMonad ()
expresionBloque defBloque tipo = do
  estado <- get
  let tabla = getLBCT estado
  let nombres = map (\(id,_) -> tknString id) defBloque
  let (nombre, offset) = getOffsetReg estado
  let nuevosOffsets = map (\(id, off) -> (nombre ++ "_" ++ (show offset) ++ "_" ++ id, off)) $ map getOffsetC $ map fromJust $ map (\(id, _, alcance) -> buscarSimbolo id alcance tabla) $ map (\(id, _) -> obtenerContenidoRecord tipo (tknString id)) defBloque
  traducirExpresionEnBloque nombres nuevosOffsets (map snd defBloque)


traducirExpresionEnBloque :: [String] -> [Offset] -> [Expresion] -> TACMonad ()
traducirExpresionEnBloque [] [] [] = return ()
traducirExpresionEnBloque (nombre:nombres) (newOffset:offsets) (expresion:exps) = do
  oldOffset <- replaceOffset newOffset
  opnExp <- expresionesTAC expresion
  let opnLeft = (Operando nombre newOffset)
  case opnExp of (Vacio _) -> return ()
                 _         -> escribirTAC (TACStore opnLeft opnExp)
  replaceOffset oldOffset
  traducirExpresionEnBloque nombres offsets exps


printear :: Show a => a -> TACMonad ()
printear cosita = liftIO $ putStrLn $ show cosita


arregloLiteral :: Int -> [Expresion] -> Operando -> TACMonad Operando
arregloLiteral index [exp] opn = do
  opnExp <- expresionesTAC exp
  escribirTAC (TACOperationB "[]=" opn (Literal $ show index) opnExp)
  return opn

arregloLiteral index (exp:exps) opn  = do
  opnExp <- expresionesTAC exp
  escribirTAC (TACOperationB "[]=" opn (Literal $ show index) opnExp)
  arregloLiteral (index + 1) exps opn
  return opn


llamadaEspecialExp :: String -> TACMonad Operando
llamadaEspecialExp fun = do
  variableFresca <- getFresh
  escribirTAC (TACLlamadaEspecialAsignacion variableFresca fun)
  return variableFresca


llamadaEspecialExpParam :: String -> Expresion -> TACMonad Operando
llamadaEspecialExpParam fun exp = do
  opnExp <- expresionesTAC exp
  empilar opnExp
  varRetorno <- getFresh
  escribirTAC (TACLlamadaEspecialAsignacion varRetorno fun)
  desempilar opnExp
  return varRetorno


llamadaExpTAC :: Llamada -> TACMonad Operando
llamadaExpTAC (Llamada funcion expresiones) = do
  parametros <- mapM expresionesTAC expresiones
  mapM_ empilar parametros
  operandoFresco <- getFresh
  escribirTAC (TACLlamarAsignacion operandoFresco (tknString funcion) (length expresiones))
  mapM_ desempilar (reverse parametros)
  return operandoFresco


expresionesTACBinarias :: Operador -> Expresion -> Expresion -> TACMonad Operando
expresionesTACBinarias operador izq der = do
  izqTAC <- expresionesTAC izq
  derTAC <- expresionesTAC der
  freshVar <- getFresh
  let tac = (TACOperationB operador freshVar izqTAC derTAC)
  escribirTAC tac
  return freshVar


expresionesTACUnarias :: Operador -> Expresion -> TACMonad Operando
expresionesTACUnarias operador exp = do
  expTAC <- expresionesTAC exp
  freshVar <- getFresh
  let tac = (TACOperationU operador freshVar expTAC)
  escribirTAC tac
  return freshVar


expresionCortoCircuito :: Expresion -> Expresion -> String -> TACMonad Operando
expresionCortoCircuito izq der "&&" = do
  labelTrueInt <- getFreshLabel
  labelFalse   <- getFreshLabel
  labelTrue    <- getFreshLabel
  labelNext    <- getFreshLabel
  opnFinal     <- getFresh
  cortoCircuitoAux izq labelTrueInt labelFalse
  escribirTAC (TACLabel labelTrueInt)
  cortoCircuitoAux der labelTrue labelFalse
  escribirTAC (TACLabel labelFalse)
  escribirTAC (TACStore opnFinal (Literal "False"))
  escribirTAC (TACGoto labelNext)
  escribirTAC (TACLabel labelTrue)
  escribirTAC (TACStore opnFinal (Literal "True"))
  escribirTAC (TACLabel labelNext)
  return opnFinal

expresionCortoCircuito izq der "||" = do
  labelFalseInt <- getFreshLabel
  labelFalse    <- getFreshLabel
  labelTrue     <- getFreshLabel
  labelNext     <- getFreshLabel
  opnFinal      <- getFresh
  cortoCircuitoAux izq labelTrue labelFalseInt
  escribirTAC (TACLabel labelFalseInt)
  cortoCircuitoAux der labelTrue labelFalse
  escribirTAC (TACLabel labelFalse)
  escribirTAC (TACStore opnFinal (Literal "False"))
  escribirTAC (TACGoto labelNext)
  escribirTAC (TACLabel labelTrue)
  escribirTAC (TACStore opnFinal (Literal "True"))
  escribirTAC (TACLabel labelNext)
  return opnFinal
  
cortoCircuitoAux :: Expresion -> Label -> Label -> TACMonad ()
cortoCircuitoAux (ExpOr izq der _) labelTrue labelFalse = do
  labelFalseInt <- getFreshLabel
  cortoCircuitoAux izq labelTrue labelFalseInt
  escribirTAC (TACLabel labelFalseInt)
  cortoCircuitoAux der labelTrue labelFalse

cortoCircuitoAux (ExpAnd izq der _) labelTrue labelFalse = do
  labelTrueInt <- getFreshLabel
  cortoCircuitoAux izq labelTrueInt labelFalse
  escribirTAC (TACLabel labelTrueInt)
  cortoCircuitoAux der labelTrue labelFalse

cortoCircuitoAux exp labelTrue labelFalse = do
  opn <- expresionesTAC exp
  escribirTAC (TACIfGoto "if" opn labelTrue)
  escribirTAC (TACGoto labelFalse)

-- (ExpOr izq der _)
-- (a && (b || c)) && ((f || y) || (e && z))
-- (a && (b || c))

-- codigo de la a -> t1
-- if t1 goto TRUE1
-- goto FALSE1
-- TRUE1:
-- codigo de la b -> t2
-- if t1 goto TRUE2
-- codigo de la c -> t3
-- if t2 goto TRUE2
-- goto FALSE2
-- TRUE2
-- t4 = True
-- goto OUT
-- FALSE2:
-- goto FALSE1
-- FALSE1:
-- t4 = False
-- OUT:

lValueTAC :: LValue -> Operador -> TACMonad Operando
lValueTAC (LIdentificador identificador _ offset _) _ = return $ Operando (tknString identificador) offset

lValueTAC (LAccessArray identificador expresiones _ offset _) "=[]" = do
  accesos <- mapM expresionesTAC (reverse expresiones)
  foldM recorrerAccesosArreglo (Operando (tknString identificador) offset) accesos

lValueTAC lam@(LAccessMember _ _ _) str = lAccessMemberTAC lam [] str

lValueTAC (LAccessPointer lvalue _) _ = lValueTAC lvalue "*()" >>= (return . Dereferencia) 

lValueTAC x _ = return $ Vacio $ show x

lAccessMemberTAC :: LValue -> [String] -> String -> TACMonad Operando
lAccessMemberTAC (LIdentificador nombre _ _ alcance) identificadores str = do
  estado <- get
  let (Just (Var tipo)) = (buscarSimbolo (tknString nombre) alcance (getLBCT estado)) >>= (\x -> Just $ getCategoria x)
  let tipoDereferenciado = dereferenciarRegistro tipo
  let listaContenidos = foldl (\acc@((_,t,_):xs) n -> (obtenerContenidoRecord t n):acc) [((tknString nombre), tipoDereferenciado, alcance)] (identificadores)
  let listaOffsets = map (\(n,_,a) -> conseguirOffset n a (getLBCT estado)) listaContenidos 
  let nuevoOffset = foldl (\(str, off) (stracc, offacc)-> (stracc ++ "_" ++ (show offacc) ++ "_" ++ str, off)) (head listaOffsets) (tail listaOffsets)
  return $ Operando (last identificadores) nuevoOffset

lAccessMemberTAC (LAccessMember left (LIdentificador nombre _ _ _) _) identificadores str = do 
  lAccessMemberTAC left ((tknString nombre):identificadores) str

lAccessMemberTAC (LAccessMember left right@(LAccessArray nombre expresiones _ offset alcance) _) identificadores "[]=" = do
  arreglo <- lAccessMemberTAC left ((tknString nombre):identificadores) "[]="
  arregloTemp <- getFresh
  escribirTAC (TACStore arregloTemp arreglo)
  (ultima:accesos) <- mapM expresionesTAC (reverse expresiones)
  expresion <- foldM recorrerAccesosArreglo arregloTemp (reverse accesos)
  return (Doble expresion ultima)

lAccessMemberTAC (LAccessMember left right@(LAccessArray nombre expresiones _ offset alcance) _) identificadores str = do
  arreglo <- lAccessMemberTAC left ((tknString nombre):identificadores) str
  arregloTemp <- getFresh
  escribirTAC (TACStore arregloTemp arreglo)
  accesos <- mapM expresionesTAC (reverse expresiones)
  foldM recorrerAccesosArreglo arregloTemp accesos

lAccessMemberTAC a _ _ = do
  return $ Vacio $ show a 


conseguirOffset :: String -> Int -> LBC -> Offset
conseguirOffset nombre alcance tabla = fromJust maybeOffset
  where maybeOffset = ((buscarSimbolo nombre alcance tabla) >>= (\x -> Just $ getOffsetC x))

  
obtenerContenidoRecord :: Type -> String -> (Nombre, Type, Alcance)
obtenerContenidoRecord (RegType set) nombre 
  = S.elemAt 0 $ S.filter (\(n,_,_) -> n == nombre) set
obtenerContenidoRecord a b = trace (show (a,b)) ("",IntType,0)


dereferenciarRegistro :: Type -> Type
dereferenciarRegistro (PointerType t) = dereferenciarRegistro t
dereferenciarRegistro t           = t


lAssignArrayTAC :: LValue -> Operador -> TACMonad (Operando, Operando)
lAssignArrayTAC (LAccessArray identificador expresiones _ offset alcance) "[]=" = do
  (ultima:accesos) <- mapM expresionesTAC expresiones
  expresion <- foldM recorrerAccesosArreglo (Operando (tknString identificador) offset) (reverse accesos)
  return (ultima, expresion)

  
recorrerAccesosArreglo :: Operando -> Operando -> TACMonad Operando
recorrerAccesosArreglo identificador acceso = do
  variableFresca <- getFresh
  escribirTAC (TACOperationB "=[]" variableFresca identificador acceso)
  return variableFresca

-- Auxiliares para If
instruccionesTACIf :: [[Instruccion]] -> [Label] -> Label -> TACMonad ()
instruccionesTACIf (instrucciones:insts) [label] labelSalida = do
  escribirTAC (TACLabel label)
  mapM_ instruccionesTAC $ reverse instrucciones

instruccionesTACIf (instrucciones:insts) (label:labels) labelSalida = do
  escribirTAC (TACLabel label)
  mapM_ instruccionesTAC $ reverse instrucciones
  escribirTAC (TACGoto labelSalida)
  instruccionesTACIf insts labels labelSalida    


generateLabels :: [Expresion] -> TACMonad ([Label], Bool)
generateLabels [expresion] = do
  booleano <- expresionesTAC expresion
  label <- getFreshLabel
  if booleano == (Literal "True")
    then do 
      escribirTAC (TACGoto label)
      return ([label], True)
    else do
      escribirTAC (TACIfGoto "if" booleano label)
      return $ ([label], False)

generateLabels (expresion:expresiones) = do
  booleano <- expresionesTAC expresion
  label <- getFreshLabel
  liftIO $ putStrLn $ show expresion
  if booleano == (Literal "True")
    then do 
      escribirTAC (TACGoto label)
      return ([label], True)
    else do
      escribirTAC (TACIfGoto "if" booleano label)
      (labels, instTrue) <- generateLabels expresiones
      return $ ((label:labels), instTrue)

