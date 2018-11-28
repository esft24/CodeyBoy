-- LBC de CodeyBoy
-- Integrantes:
--              Erick Flejan    12-11555
--              Carlos Perez    13-11089

-- CI-4721 Lenguajes de Programacion II

module LBC where
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

data Categoria = Tp Type
               | Func [Instruccion] [Type] Type Bool
               | Reg
               | Uni
               | Var Type
               | Par
               | Mem
               | Tag deriving(Eq, Show)

type LBC = M.Map Nombre (M.Map Alcance Contenido)

data Contenido = Contenido { getNombre    :: Nombre
                           , getCategoria :: Categoria
                           , getAlcanceC  :: Alcance
                           , getOtro      :: [Extra] 
                           , getOffsetC   :: Offset}
                           deriving(Eq, Show)

type PilaAlcance = [EntradaPila]
type EntradaPila = Alcance

baseLBC :: LBC
baseLBC = M.fromList [
                    ("Int",       M.fromList [(0, Contenido "Int"       (Tp IntType)    0 [] ("global", -1))]),
                    ("String",    M.fromList [(0, Contenido "String"    (Tp StringType) 0 [] ("global", -1))]),
                    ("Float",     M.fromList [(0, Contenido "Float"     (Tp FloatType)  0 [] ("global", -1))]),
                    ("Char",      M.fromList [(0, Contenido "Char"      (Tp CharType)   0 [] ("global", -1))]),
                    ("Bool",      M.fromList [(0, Contenido "Bool"      (Tp BoolType)   0 [] ("global", -1))]),
                    ("Void",      M.fromList [(0, Contenido "Void"      (Tp VoidType)   0 [] ("global", -1))]),
                    ("Reg",       M.fromList [(0, Contenido "Reg"       (Tp VoidType)   0 [] ("global", -1))]),
                    ("Array",     M.fromList [(0, Contenido "Array"     (Tp VoidType)   0 [] ("global", -1))]),
                    ("Pointer",   M.fromList [(0, Contenido "Pointer"   (Tp VoidType)   0 [] ("global", -1))]),
                    ("Union",     M.fromList [(0, Contenido "Union"     (Tp VoidType)   0 [] ("global", -1))]),
                    ("ErrorType", M.fromList [(0, Contenido "ErrorType" (Tp VoidType)   0 [] ("global", -1))]),
                    ("NullType",  M.fromList [(0, Contenido "NullType"  (Tp VoidType)   0 [] ("global", -1))])
                    ]

data Extra = Parametro (Nombre, Alcance, Bool, Offset)
           | Miembro (Nombre, Alcance)
           deriving (Eq, Show)

type EmpiladosBloque = [Int]

type EstructuraPila = (PilaAlcance,EmpiladosBloque)

data ErrorLog = TypeError String
                | SymbolError String

instance Show ErrorLog where
  show (TypeError str) = str
  show (SymbolError str) = str

data Estado = Estado {  getLBC :: LBC
                      , getPila :: EstructuraPila
                      , getAlcance ::  Alcance
                      , toCheck :: [Identificador]
                      , getOffset :: [Offset]
                      } deriving (Eq, Show)


getWidth :: Type -> Int
getWidth IntType            = 4
getWidth BoolType           = 4
getWidth FloatType          = 8
getWidth CharType           = 4
getWidth (PointerType _)    = 4
getWidth (TypeNameType _ t) = getWidth t
getWidth StringType         = 4
getWidth (ArrayType _ _)    = 69
getWidth (RegType set)      = sum $ S.toList $ S.map (\(_, t, _) -> getWidth t) set
getWidth (UnionType comun tags) = maxTag + comunWidth
  where tagWidth   = S.toList $ S.map (\(_,set) -> getWidth (RegType set)) tags
        maxTag     = maximum tagWidth
        comunWidth = getWidth (RegType comun)
getWidth _                      = 0

insertOffsetFunc :: Identificador -> ECMonad ()
insertOffsetFunc identificador = do
  let nombre = tknString identificador
  estado <- get
  put $ Estado (getLBC estado) (getPila estado) (getAlcance estado) (toCheck estado) ((nombre, 0):(getOffset estado))

popOffsetFunc :: ECMonad ()
popOffsetFunc = do
  estado <- get
  put $ Estado (getLBC estado) (getPila estado) (getAlcance estado) (toCheck estado) (tail $ getOffset estado)

-- Prueba Erick
insertOffsetReg :: ECMonad ()
insertOffsetReg = do
  estado <- get
  put $ Estado (getLBC estado) (getPila estado) (getAlcance estado) (toCheck estado) (("Reg", 0):(getOffset estado))

popOffset :: ECMonad Offset
popOffset = do
  estado <- get
  put $ Estado (getLBC estado) (getPila estado) (getAlcance estado) (toCheck estado) (tail $ getOffset estado)
  return $ head $ getOffset estado 



type ECMonad = StateT Estado (WriterT [ErrorLog] IO)

estadoInicial :: Estado
estadoInicial = Estado baseLBC ([2,1,0], [0]) 3 [] [("global", 0)]

-- Usado en modifyLBC
pushVariable :: EstructuraPila -> Alcance -> EstructuraPila
pushVariable (pilaAlcance, (x:xs)) alcance = (alcance:pilaAlcance, (x+1:xs))

-- Usado en modifyLBCG
pushVariableG :: EstructuraPila -> Alcance -> EstructuraPila
pushVariableG (pilaAlcance, declaradosBloque) alcance = (pilaAlcance ++ [alcance], take tomar declaradosBloque ++ [((last declaradosBloque) + 1)])
  where tomar = (length declaradosBloque) - 1

-- Usado en nuevoBloque
pushBloque :: EstructuraPila -> EstructuraPila
pushBloque (pilaAlcance, pilaDeclarados) = (pilaAlcance, 0:pilaDeclarados)

-- Usado en finalizarBloqueU
pop :: EstructuraPila -> EstructuraPila
pop (pilaAlcance, (x:xs)) = (drop x pilaAlcance, xs)

-- Usado en: InsertarVariableTabla, InsertarFuncionTabla, insertarFuncionTablaP, insertarTipoTabla
nuevoSimbolo :: LBC -> Nombre -> Contenido -> LBC
nuevoSimbolo tabla n c = M.insertWith (M.union) n simb tabla
    where simb = M.fromList [(getAlcanceC c, c)]

-- Usado en: createListDef
buscarIdentificador :: Nombre -> Estado -> Maybe Contenido
buscarIdentificador nombre estado =
  if verificar == [] then Nothing else head verificar
  where tabla = getLBC estado
        (pilaAux, (numeroDeclarados:_)) = getPila estado
        pila = take numeroDeclarados pilaAux
        verificar = filter isJust $ map (\x -> buscarSimbolo nombre x tabla) pila

-- Usado en: buscarIdentificador, verificarExistencia, verificarExistenciaG, extractTypeParameter, verificarExistenciaP,
-- llamadaFuncionVerificacion, verificarExistenciaT, extractTypeIdent, extractTypeLlamada, cambiarDefFuncion, cambiarTag
buscarSimbolo :: Nombre -> Alcance -> LBC -> Maybe Contenido
buscarSimbolo n a tabla = do
    entradas <- M.lookup n tabla
    M.lookup a entradas

-- Usado en: insertarVariableTabla, insertarVariableTablaP, insertarTipoTabla
modifyLBC :: Estado -> (LBC -> LBC) -> Estado
modifyLBC estado f = Estado (f tabla) (pushVariable estructuraPila alcance) (alcance+1) (toCheck estado) (getOffset estado)
  where tabla          = getLBC estado
        estructuraPila = getPila estado
        alcance        = getAlcance estado

-- Usado en: insertarFuncionTabla
modifyLBCG :: Estado -> (LBC -> LBC) -> Estado
modifyLBCG estado f = Estado (f tabla) (pushVariableG estructuraPila alcance) (alcance+1) (toCheck estado) (getOffset estado)
  where tabla          = getLBC estado
        estructuraPila = getPila estado
        alcance        = getAlcance estado

-- Usado en: nuevoBloque, finalizarBloqueU
modifyPila :: Estado -> EstructuraPila -> Estado
modifyPila estado pila = Estado (getLBC estado) (pila) (getAlcance estado) (toCheck estado) (getOffset estado)

-- Usado en: insertarVariableTabla, insertarFuncionTabla, insertarVariableTablaP
buscarTipoTabla :: String -> Estado -> Bool
buscarTipoTabla tipo estado =
  case busqueda of Nothing        -> False
                   Just definidas -> existe definidas
  where busqueda          = M.lookup tipo (getLBC estado)
        (pilaAlcance, _)  = getPila estado
        choqueAlcances y  = map (\x -> M.lookup x y) pilaAlcance
        existe y          = any isJust (choqueAlcances y)

-- Usado en: insertarVariableTabla
verificarExistencia :: Estado -> Nombre -> Bool
verificarExistencia estado nombre = (any isJust $ map (\x -> buscarSimbolo nombre x tabla) aVerificar) || funciones
  where tabla                          = getLBC estado
        (pilaAlcances, pilaDeclarados) = getPila estado
        cantidadVerificar              = head pilaDeclarados
        aVerificar                     = take cantidadVerificar pilaAlcances
        funciones                      = any nombreEq $ map fromJust $ filter isJust $ map extraerFun $ concat $ map ((map snd) . M.toList . snd) $ M.toList tabla
        nombreEq contenido             = getNombre contenido == nombre
        fromJust (Just c)              = c
        extraerFun x                   = case getCategoria x of {(Func _ _ _ _) -> Just x; _ -> Nothing}

-- Usado en: verificarTabla, insertarFuncionTabla
verificarExistenciaG :: Estado -> Nombre -> Bool
verificarExistenciaG estado nombre = any isJust $ map (\x -> buscarSimbolo nombre x tabla) pilaAlcances
  where tabla = getLBC estado
        (pilaAlcances, _) = getPila estado

-- Usado en: SELECCIONMATCH, SELECCIONMATCHF
verificarTabla :: Identificador -> ECMonad ()
verificarTabla identificador = do
  estado <- get
  let resultado = verificarExistenciaG estado (tknString identificador)
  case resultado of True  -> return ()
                    False -> lift $ tell $ [SymbolError $ "Linea " ++ (show $ fst $ tknPos identificador) ++ "\n\tLa variable " ++ (tknString identificador) ++ " no esta declarada"]

-- Usado en: NUEVOBLOQUE, PARAMLIST, REPDETITER, REPDETARRAY
nuevoBloque :: ECMonad ()
nuevoBloque = do
  estado <- get
  let estructuraPila = getPila estado
  let nuevaPila = pushBloque estructuraPila
  put $ modifyPila estado nuevaPila
  return ()

-- Usado en: TYPE, LISTATAG, DEFFUNC, SELECCIONIF, IF, LISTAELSE, SELECCIONIFF, IFF, LISTAELSEF, LISTACASOS,
-- DEFAULTCASE, REPETICIONDET, REPETICIONDETF, REPETICIONINDET, REPETICIONINDETF,
finalizarBloqueU :: ECMonad ()
finalizarBloqueU = do
  estado <- get
  let estructuraPila = getPila estado
  let nuevaPila = pop estructuraPila
  put $ modifyPila estado nuevaPila
  return ()

--------------------------------------------------------------------------------
--  DEFVARIABLE
--------------------------------------------------------------------------------

makeOffset :: Type -> Offset -> Offset
makeOffset tipo (nombre, offsetAnterior) = (nombre, (getWidth tipo) + offsetAnterior)

-- Usado en: tryInsert, tryInsertP
insertarVariableTabla :: Estado -> Identificador -> Type -> (Either String Estado, Offset, Alcance)
insertarVariableTabla estado identificador tipoEntrada =
  case verificacion of True -> (Left ("Linea " ++ (show $ tknPos identificador) ++ "\n\tLa variable " ++ nombre ++ " ya esta declarada"), head (getOffset estado), alcance)
                       False -> case ingresoTipo of False   -> (Left ("Linea " ++ (show $ tknPos identificador) ++ "\n\tEl tipo " ++ tipo ++ " no esta declarado"), head (getOffset estado), alcance)
                                                    True  -> (Right (Estado (getLBC nuevoEstado) (getPila nuevoEstado) (getAlcance nuevoEstado) (toCheck nuevoEstado) nuevoOffset), head (getOffset estado), alcance)
  where nombre = tknString identificador
        alcance = getAlcance estado
        ingresoTipo = buscarTipoTabla tipo estado
        nuevoEstado = (modifyLBC estado f)
        contenido = Contenido nombre (Var tipoEntrada) alcance [] (head (getOffset estado))
        nuevoOffset     = (makeOffset tipoEntrada (head $ getOffset estado)) : (tail $ getOffset estado)
        f = (\x -> nuevoSimbolo x nombre contenido)
        verificacion = verificarExistencia estado nombre
        tipo = stringify tipoEntrada

insertarVariableTablaR :: Estado -> Identificador -> Type -> (Either String Estado, Offset, Alcance)
insertarVariableTablaR estado identificador tipoEntrada =
  case verificacion of True -> (Left ("Linea " ++ (show $ tknPos identificador) ++ "\n\tLa variable " ++ nombre ++ " ya esta declarada"), head (getOffset estado), alcance)
                       False -> case ingresoTipo of False   -> (Left ("Linea " ++ (show $ tknPos identificador) ++ "\n\tEl tipo " ++ tipo ++ " no esta declarado"), head (getOffset estado), alcance)
                                                    True  -> (Right (Estado (getLBC nuevoEstado) (getPila nuevoEstado) (getAlcance nuevoEstado) (toCheck nuevoEstado) nuevoOffset), head (getOffset estado), alcance)
  where nombre = tknString identificador
        alcance = getAlcance estado
        ingresoTipo = buscarTipoTabla tipo estado
        nuevoEstado = (modifyLBC estado f)
        contenido = Contenido nombre (Var tipoEntrada) alcance [] (head (getOffset estado))
        nuevoOffset     = (makeOffset (PointerType tipoEntrada) (head $ getOffset estado)) : (tail $ getOffset estado)
        f = (\x -> nuevoSimbolo x nombre contenido)
        verificacion = verificarExistencia estado nombre
        tipo = stringify tipoEntrada

-- Usado en: insertarVariableTabla, insertarFuncionTabla, inertarVariableTablaP,
stringify :: Type -> String
stringify IntType = "Int"
stringify CharType = "Char"
stringify BoolType = "Bool"
stringify FloatType = "Float"
stringify (ArrayType _ _ ) = "Array"
stringify StringType = "String"
stringify (PointerType _ ) = "Pointer"
stringify (TypeNameType typeName _) = tknString typeName
stringify VoidType = "Void"
stringify (RegType _) = "Reg"
stringify (UnionType _ _) = "Union"
stringify ErrorType = "ErrorType"

-- Usado en: checkPrintFree, checkArrayLength, extractTypeLlamada, buscarReturns,
-- verificarTipoDefAux, verificarTipoRepDet, verificarTipoRepDetBy, verificarTipoRepDetArr, verificarTipoCond,
-- verificarTipoBlock, modificarTipoUnion, compararLconR,
stringify' :: Type -> String
stringify' IntType = "Int"
stringify' CharType = "Char"
stringify' BoolType = "Bool"
stringify' FloatType = "Float"
stringify' (ArrayType t _ ) = "Array de elementos de tipo " ++ stringify' t
stringify' StringType = "String"
stringify' (PointerType t ) = "Apuntador " ++ (stringify' t)
stringify' (TypeNameType typeName _) = tknString typeName
stringify' VoidType = "Void"
stringify' (RegType _) = "Reg"
stringify' (UnionType _ _) = "Union"
stringify' ErrorType = "mal definido"
stringify' (NullType _) = "por especificar"

-- Usado en: DEFVARIABLE, PARAMLIST, REPDETITER, REPDETARRAY
tryInsert :: Identificador -> Type -> ECMonad (Offset, Int)
tryInsert identificador tipo = do
  estado <- get
  let (maybeEstado, offset, alcance) = insertarVariableTabla estado identificador tipo
  case maybeEstado of Left errorBoy -> lift $ tell $ [SymbolError errorBoy]
                      Right nuevoEstado -> put nuevoEstado
  return (offset, alcance)

  
tryInsertR :: Identificador -> Type -> ECMonad (Offset, Int)
tryInsertR identificador tipo = do
  estado <- get
  let (maybeEstado, offset, alcance) = insertarVariableTablaR estado identificador tipo
  case maybeEstado of Left errorBoy -> lift $ tell $ [SymbolError errorBoy]
                      Right nuevoEstado -> put nuevoEstado
  return (offset, alcance)


--------------------------------------------------------------------------------
--  DEFFUNC
--------------------------------------------------------------------------------

--Left ("Linea " ++ show (fst $ tknPos identificador) ++ "\n\tLa variable " ++ nombre ++ " ya esta declarada")
-- Usado en: tryInsertF
-- TODO - Probar
insertarFuncionTabla :: Estado -> Identificador -> Type -> [Parametro] -> Bool -> Either String Estado
insertarFuncionTabla estado identificador tipo parametros conOSinBloque =
  case existencia of False -> Right (modifyLBCG estado f)
                     True  -> case conOSinBloque of True  -> case definida of Left str    -> Left str
                                                                              Right True  -> Left ("Linea " ++ show (fst $ tknPos identificador) ++ "\n\tLa funcion " ++ nombre ++ " ya esta declarada")
                                                                              Right False -> Right estado
                                                    False -> Left ("Linea " ++ show (fst $ tknPos identificador) ++ "\n\tLa funcion " ++ nombre ++ " ya esta declarada")
  where tabla = getLBC estado
        nombre = tknString identificador
        existencia = verificarExistenciaG estado nombre
        contenido = Contenido nombre (Func [] tipoParametros tipo False) (getAlcance estado) parametrosContenido (nombre, -1)
        tipoContenido = buscarTipoTabla (stringify tipo) estado
        parametrosContenido = map (parametrify tabla) parametros
        tipoParametros = map fromJust $ filter isJust $ map (extractTypeParameter estado) parametrosContenido
        f = (\x -> nuevoSimbolo x nombre contenido)
        fromJust (Just x) = x
        definida = conseguirDefinida estado identificador 

-- Def [nombre (P1: t1) : tr] { Inst }
--       ^^^^^                                insertarFuncionTabla -> Func [t1...] tr True si no habia nada antes
--       ^^^^^                                insertarFuncionTabla -> nada si habia algo antes no definido (False)
--       ^^^^^                                insertarFuncionTabla -> error

-- Def [nombre (P1: t1) : tr]
--       ^^^^^                                insertarFuncionTabla -> Func [t1...] tr False si no habia nada antes
--       ^^^^^                                insertarFuncionTabla -> error

conseguirDefinida :: Estado -> Identificador -> Either String Bool
conseguirDefinida estado identificador 
  = case funciones of [] -> Left $ "Linea " ++ (show (fst $ tknPos identificador)) ++ "\n\tLa variable " ++ nombre ++ " ya esta declarada"
                      _  -> Right x
  where tabla = getLBC estado
        (pilaAlcance, _) = getPila estado
        nombre           = tknString identificador
        contenido        = map fromJust $ filter (isJust) $ map (\x -> buscarSimbolo nombre x tabla) pilaAlcance
        funciones        = filter (isFunc . getCategoria) contenido
        isFunc y         = case y of {Func _ _ _ _ -> True; _ -> False}
        Func _ _ _ x     = getCategoria $ head funciones

-- Usado en: insertarFuncionTabla
extractTypeParameter :: Estado -> Extra -> Maybe Type
extractTypeParameter estado (Parametro (nombre, alcance, _, _))
  = case (buscarSimbolo nombre alcance tabla) of Nothing -> Nothing
                                                 Just contenido -> case getCategoria contenido of Var tipo -> Just tipo
                                                                                                  _        -> Nothing
  where tabla = getLBC estado

-- Usado en: insertarFuncionTabla,
parametrify :: LBC -> Parametro -> Extra
parametrify tabla parametro = Parametro (nombre, alcance, modoDeEntrada, offset)
  where (token, modoDeEntrada, offset) = extractTokenPar parametro
        nombre = tknString token
        maybeMapaNombre = M.lookup nombre tabla
        fromJust (Just m) = m
        (_, contenido) = last $ M.toList $ fromJust maybeMapaNombre
        alcance = getAlcanceC contenido

-- Usado en: parametrify
extractTokenPar :: Parametro -> (Token, Bool, Offset)
extractTokenPar (PorValor t offset) = (t, False, offset)
extractTokenPar (PorReferencia t offset) = (t, True, offset)

-- Usado en: FUNCNAME, FUNCNAMEP
tryInsertF :: Identificador -> Type -> [Parametro] -> Bool -> ECMonad ()
tryInsertF identificador tipo parametros conOSinBloque = do
  estado <- get
  let resultado = insertarFuncionTabla estado identificador tipo parametros conOSinBloque
  case resultado of Left str           -> lift $ tell $ [SymbolError str]
                    Right estadoSalida -> put estadoSalida

-- Usado en: DEFVARIABLEP
tryInsertP :: Identificador -> Type -> ECMonad (Offset, Int)
tryInsertP identificador tipo = do
  estado <- get
  let (maybeEstado, offset, alcance) = insertarVariableTablaP estado identificador tipo
  case maybeEstado of Left errorBoy -> lift $ tell $ [SymbolError errorBoy]
                      Right nuevoEstado -> put nuevoEstado
  return (offset, alcance)

tryInsertU :: Identificador -> Type -> ECMonad (Offset, Int)
tryInsertU identificador tipo = do
  estado <- get
  let (maybeEstado, offset, alcance) = insertarVariableTablaU estado identificador tipo
  case maybeEstado of Left errorBoy -> lift $ tell $ [SymbolError errorBoy]
                      Right nuevoEstado -> put nuevoEstado
  return (offset, alcance)



-- Usado en: tryInsertP
insertarVariableTablaP :: Estado -> Identificador -> Type -> (Either String Estado, Offset, Alcance)
insertarVariableTablaP estado identificador tipoEntrada =
  case verificacion of True -> (Left ("Linea " ++ (show $ fst $ tknPos identificador) ++ "\n\tLa variable " ++ nombre ++ " ya esta declarada"), head $ getOffset estado, alcance)
                       False -> case ingresoTipo of False -> (Left ("Linea " ++ (show $ fst $ tknPos identificador) ++ "\n\tEl tipo " ++ tipo ++ " no ha sido declarado."), head $ getOffset estado, alcance)
                                                    True  -> (Right (Estado (getLBC nuevoEstado) (getPila nuevoEstado) (getAlcance nuevoEstado) (toCheck nuevoEstado) nuevoOffset), head $ getOffset estado, alcance)
  where nombre = tknString identificador
        alcance = getAlcance estado
        ingresoTipo = buscarTipoTabla tipo estado
        contenido = Contenido nombre (Var tipoEntrada) alcance [] (head (getOffset estado))
        nuevoOffset     = (makeOffset tipoEntrada (head $ getOffset estado)) : (tail $ getOffset estado)
        nuevoEstado = (modifyLBC estado f)
        f = (\x -> nuevoSimbolo x nombre contenido)
        verificacion = verificarExistenciaP estado nombre
        tipo = stringify tipoEntrada

insertarVariableTablaU :: Estado -> Identificador -> Type -> (Either String Estado, Offset, Alcance)
insertarVariableTablaU estado identificador tipoEntrada =
  case verificacion of True -> (Left ("Linea " ++ (show $ fst $ tknPos identificador) ++ "\n\tLa variable " ++ nombre ++ " ya esta declarada"), head $ getOffset estado, alcance)
                       False -> case ingresoTipo of False -> (Left ("Linea " ++ (show $ fst $ tknPos identificador) ++ "\n\tEl tipo " ++ tipo ++ " no ha sido declarado."), head $ getOffset estado, alcance)
                                                    True  -> (Right (Estado (getLBC nuevoEstado) (getPila nuevoEstado) (getAlcance nuevoEstado) (toCheck nuevoEstado) nuevoOffset), head $ getOffset estado, alcance)
  where nombre = tknString identificador
        alcance = getAlcance estado
        ingresoTipo = buscarTipoTabla tipo estado
        contenido = Contenido nombre (Var tipoEntrada) alcance [] (head (getOffset estado))
        nuevoOffset     = (makeOffset tipoEntrada (head $ getOffset estado)) : (tail $ getOffset estado)
        nuevoEstado = (modifyLBC estado f)
        f = (\x -> nuevoSimbolo x nombre contenido)
        verificacion = verificarExistenciaU estado nombre
        tipo = stringify tipoEntrada


-- Usado en: insertarVariableP
verificarExistenciaP :: Estado -> Nombre -> Bool
verificarExistenciaP estado nombre = (any isJust $ map (\x -> buscarSimbolo nombre x tabla) aVerificar) || funciones
  where tabla                          = getLBC estado
        (pilaAlcances, pilaDeclarados) = getPila estado
        cantidadVerificar              = sum $ init pilaDeclarados
        aVerificar                     = take cantidadVerificar pilaAlcances
        funciones                      = any nombreEq $ map fromJust $ filter isJust $ map extraerFun $ concat $ map ((map snd) . M.toList . snd) $ M.toList tabla
        nombreEq contenido             = getNombre contenido == nombre
        extraerFun x                   = case getCategoria x of {(Func _ _ _ _) -> Just x; _ -> Nothing}
        fromJust (Just c)              = c

verificarExistenciaU :: Estado -> Nombre -> Bool
verificarExistenciaU estado nombre = (any isJust $ map (\x -> buscarSimbolo nombre x tabla) aVerificar) || funciones
  where tabla                          = getLBC estado
        (pilaAlcances, pilaDeclarados) = getPila estado
        cantidadVerificar              = sum $ take 2 pilaDeclarados
        aVerificar                     = take cantidadVerificar pilaAlcances
        funciones                      = any nombreEq $ map fromJust $ filter isJust $ map extraerFun $ concat $ map ((map snd) . M.toList . snd) $ M.toList tabla
        nombreEq contenido             = getNombre contenido == nombre
        extraerFun x                   = case getCategoria x of {(Func _ _ _ _) -> Just x; _ -> Nothing}
        fromJust (Just c)              = c

--------------------------------------------------------------------------------
-- LLAMADA
--------------------------------------------------------------------------------

-- tipo <- typeLlamadaMonadic (getTokenL $1) (map getTipoEx (getParametros $1))

-- Usado en: chequeoLlamadasF, LLAMADA
verificarExistenciaFuncion :: Identificador -> Int -> ECMonad ()
verificarExistenciaFuncion identificador cantidadParametros = do
  estado <- get
  let nombre = tknString identificador
  let verificacion = llamadaFuncionVerificacion estado nombre cantidadParametros (tknPos identificador)
  case verificacion of Nothing  -> return ()
                       Just str -> lift $ tell [SymbolError str]

-- Usado en: verificarExistenciaFuncion,
llamadaFuncionVerificacion :: Estado -> Nombre -> Int -> (Int, Int) -> Maybe String
llamadaFuncionVerificacion estado nombre cantidadParametros posicion =
  case (any isJust filtrado) of False -> Just ("Linea " ++ (show $ fst posicion) ++ "\n\t" ++ "La funcion " ++ nombre ++ " no ha sido definida")
                                True  -> Nothing
  where tabla = getLBC estado
        (pilaAlcances, _) = getPila estado
        filtrado = map (\x -> buscarSimbolo nombre x tabla) pilaAlcances
        fromJust (Just c) = c
        cantidadDefinida = length (getOtro $ fromJust $ head $ filter isJust filtrado)
        verificacionParametros = cantidadDefinida == cantidadParametros

-- -- Usado en: NO SE USA
-- chequeoLlamadasF :: ECMonad ()
-- chequeoLlamadasF = do
--   estado <- get
--   let uncurried = uncurry verificarExistenciaFuncion
--   let chequeo = toCheck estado
--   mapM_ uncurried chequeo
--   put $ Estado (getLBC estado) (getPila estado) (getAlcance estado) []

chequeoLlamadas :: ECMonad ()
chequeoLlamadas = do
  estado <- get
  let chequeo = toCheck estado
  mapM_ verificacionDefinicionLlamadas chequeo
  
verificacionDefinicionLlamadas :: Identificador -> ECMonad ()
verificacionDefinicionLlamadas funcion = do
  estado <- get
  let nombreFuncion = tknString funcion
  let (linea, _)    = tknPos funcion
  case chequearDeficionFuncion estado nombreFuncion of True  -> return ()
                                                       False -> lift $ tell [TypeError $ "Linea " ++ (show linea) ++ ":\n\tLa funcion " ++ nombreFuncion ++ " no esta definida correctamente."]
                                    
chequearDeficionFuncion :: Estado -> Nombre -> Bool
chequearDeficionFuncion estado nombreFuncion = definida
  where tabla                               = getLBC estado
        (pilaAlcances, _)                   = getPila estado
        contenidos                          = map fromJust $ filter (isJust) $ map (\x -> buscarSimbolo nombreFuncion x tabla) pilaAlcances
        funciones                           = filter (isFunc . getCategoria) contenidos
        isFunc y                            = case y of {Func _ _ _ _ -> True; _ -> False}
        (Func _ _ _ definida)               = getCategoria (head funciones)

--------------------------------------------------------------------------------
-- Definicion y Verificacion de Tipo
--------------------------------------------------------------------------------

-- Usado en: insertarTipoTabla
verificarExistenciaT :: Estado -> Nombre -> Bool
verificarExistenciaT estado nombre = any isJust $ map (\x -> buscarSimbolo nombre x tabla) aVerificar
  where tabla = getLBC estado
        (pilaAlcances, pilaDeclarados) = getPila estado
        cantidadVerificar              = head pilaDeclarados
        aVerificar                     = take cantidadVerificar pilaAlcances

-- Usado en: tryInsertTipo
insertarTipoTabla :: Estado -> Identificador -> Type -> Either String Estado
insertarTipoTabla estado identificador tipoFinal =
  case verificacion of True -> Left ("Linea " ++ (show $ fst $ tknPos identificador) ++ "\n\tEl tipo " ++ nombre ++ " ya esta declarado")
                       False -> Right (modifyLBC estado f)
  where nombre = tknString identificador
        alcance = getAlcance estado
        contenido = Contenido nombre (Tp tipoFinal) alcance [] ("global", -1)
        f = (\x -> nuevoSimbolo x nombre contenido)
        verificacion = verificarExistenciaT estado nombre

-- Usado en: DEFDETIPO
tryInsertTipo :: Identificador -> Type -> ECMonad ()
tryInsertTipo identificador tipo = do
  estado <- get
  let maybeEstado = insertarTipoTabla estado identificador tipo
  case maybeEstado of Left errorBoy -> lift $ tell $ [SymbolError errorBoy]
                      Right nuevoEstado -> put nuevoEstado
--------------------------------------------------------------------------------
-- Impresiones
--------------------------------------------------------------------------------

-- Usado en: testExample
printLBC :: LBC -> String
printLBC lbc = unlines impresion
  where tabla = M.toList lbc
        contenidos = map snd tabla
        impresion = map show $ map M.toList contenidos

--------------------------------------------------------------------------------
-- Extraccion de tipos
--------------------------------------------------------------------------------

-- Usado en: EXPRESION
unary :: Type -> Type -> Type
unary tipoMust tipoIs = if tipoMust <=> tipoIs then tipoMust else ErrorType

-- Usado en: EXPRESION
binaryBoolean :: Type -> Type -> Type
binaryBoolean tipoLeft tipoRight = if tipoLeft <=> BoolType && tipoRight <=> BoolType then BoolType else ErrorType

-- Usado en: EXPRESION
binaryNumberOp :: Type -> Type -> Type -> Type
binaryNumberOp tipoIs tipoLeft tipoRight 
  = if (tipoLeft <=> IntType || tipoLeft <=> FloatType) && (tipoRight <=> IntType || tipoRight <=> FloatType) 
    then tipoIs
    else ErrorType

-- Usado en: EXPRESION
binaryEquivalenceOp :: Type -> Type -> Type
binaryEquivalenceOp IntType FloatType = BoolType
binaryEquivalenceOp FloatType IntType = BoolType
binaryEquivalenceOp tipoRight tipoLeft
  = if (tipoLeft <=> tipoRight) then BoolType
    else ErrorType

-- Usado en: EXPRESION 
binaryNumberOpRestricted :: Type -> Type -> Type
binaryNumberOpRestricted IntType IntType = IntType
binaryNumberOpRestricted IntType FloatType = FloatType
binaryNumberOpRestricted FloatType IntType = FloatType
binaryNumberOpRestricted FloatType FloatType = FloatType
binaryNumberOpRestricted _ _ = ErrorType


-- Usado en: INSTRUCCION, INSTRUCCIONF, INSTRUCCIONP, INSTRUCCIONFL, INSTRUCCIONC, INSTRUCCIONL
checkPrintFree :: Pos -> Type -> Type -> ECMonad ()
checkPrintFree (linea,_ ) tipoIn tipoShould
  = if tipoIn <=> tipoShould then return ()
    else if tipoShould == StringType then lift $ tell $ [TypeError $ "Linea " ++ (show linea) ++ "\n\tNo se puede imprimir un elemento de tipo "++ stringify' tipoIn]
         else lift $ tell [TypeError $ "Linea " ++ (show linea) ++ "\n\tNo se puede liberar un elemento de tipo " ++ (stringify' tipoIn)]

-- Usado en: EXPRESION
checkStringify :: Pos -> Type -> ECMonad()
checkStringify (linea, _) tipoIn
  = if tipoIn == ErrorType then lift $ tell $ [TypeError $ "Linea " ++ show linea ++ "\n\tNo se puede formar una string con un elemento mal definido."]
    else return ()

-- Usado en: TYPE
checkArrayLength :: Pos -> Type -> ECMonad ()
checkArrayLength (linea, _) tipoIn
  = if tipoIn <=> IntType then return ()
    else lift $ tell [TypeError $ "Linea " ++ (show linea) ++ "\n\tNo se puede crear un arreglo con un tamaño no entero."]

-- Usado en: EXPRESION
getArrayType :: [Expresion] -> Type
getArrayType [] = NullType []
getArrayType listaTipos = (ArrayType (foldl1 reduceType $ map getTipoEx listaTipos) (ExpNumero (TKNumbers (420,69) (show $ length listaTipos)) IntType))
  where reduceType acc result = if acc <=> result then acc else ErrorType

-- Usado en: EXPRESION
floatOrInt :: String -> Type
floatOrInt x = if elem '.' x then FloatType else IntType

-- Usado en: verificarCasosTag, createListDef, extractTypeLvalue
extractTypeIdent :: Estado -> String -> Type
extractTypeIdent estado nombre = case contenidos of [] -> ErrorType
                                                    _  -> case variables of []     -> ErrorType
                                                                            (x:xs) -> getTipoFinal $ getCategoria x
  where tabla                         = getLBC estado
        (pilaAlcance, pilaDeclarados) = getPila estado
        cantidadVerificar             = sum pilaDeclarados
        alcances                      = take cantidadVerificar pilaAlcance
        contenidos                    = map fromJust $ filter (isJust) $ map (\x -> buscarSimbolo nombre x tabla) alcances
        variables                     = filter (isVar . getCategoria) contenidos
        isVar y                       = case y of {Var _ -> True; _ -> False}
        getTipoFinal (Var tipoFinal)  = tipoFinal


--PRUEBA ERICK
extractOffset :: Estado -> String -> Offset
extractOffset estado nombre = case contenidos of [] -> ("dummy", 42069)
                                                 _  -> case variables of []     -> ("dummy", 42069)
                                                                         (x:xs) -> (head offsets)
  where tabla                         = getLBC estado
        (pilaAlcance, pilaDeclarados) = getPila estado
        cantidadVerificar             = sum pilaDeclarados
        alcances                      = take cantidadVerificar pilaAlcance
        contenidos                    = map fromJust $ filter (isJust) $ map (\x -> buscarSimbolo nombre x tabla) alcances
        variables                     = filter (isVar . getCategoria) contenidos
        offsets                       = map getOffsetC $ filter (isVar. getCategoria) contenidos
        isVar y                       = case y of {Var _ -> True; _ -> False}
        getTipoFinal (Var tipoFinal)  = tipoFinal

extractAlcance :: Estado -> String -> Int
extractAlcance estado nombre = case contenidos of [] -> -1
                                                  _  -> case variables of []     -> -1
                                                                          (x:xs) -> (head alcances')
  where tabla                         = getLBC estado
        (pilaAlcance, pilaDeclarados) = getPila estado
        cantidadVerificar             = sum pilaDeclarados
        alcances                      = take cantidadVerificar pilaAlcance
        contenidos                    = map fromJust $ filter (isJust) $ map (\x -> buscarSimbolo nombre x tabla) alcances
        variables                     = filter (isVar . getCategoria) contenidos
        alcances'                     = map getAlcanceC $ filter (isVar. getCategoria) contenidos
        isVar y                       = case y of {Var _ -> True; _ -> False}
        getTipoFinal (Var tipoFinal)  = tipoFinal

-- Usado en: INSTRUCCION, INSTRUCCIONF, INSTRUCCIONFP, INSTRUCCIONFL, INSTRUCCIONC, INSTRUCCIONL, EXPRESION
typeLlamadaMonadic :: Token -> [Type] -> ECMonad Type
typeLlamadaMonadic token tipos = do
  estado <- get
  case (extractTypeLlamada estado token tipos) of
    Left str  -> lift $ tell [TypeError str] >> return ErrorType
    Right (definida, tipo) -> case definida of True  -> return tipo
                                               False -> do
                                                          put $ Estado (getLBC estado) (getPila estado) (getAlcance estado) (token:(toCheck estado)) (getOffset estado)
                                                          return tipo

-- Usado en: typeLlamadaMonadic
extractTypeLlamada :: Estado -> Token -> [Type] -> Either String (Bool, Type)
extractTypeLlamada estado token tiposEntrada
  = case contenidos of [] -> Right (True, ErrorType)
                       _  -> case funciones of [] -> Right (True, ErrorType)
                                               _  -> if tiposEntrada == parametros then Right (definida, salida) 
                                                     else Left $ "Linea " ++ (show linea) ++ "\n\tSe intento llamar a la funcion " ++ (tknString token) ++ " con tipo de entrada " ++ (unwords $ map stringify' parametros) ++ " con parametros de tipo " ++ (unwords $ map stringify' tiposEntrada)
  where nombre                              = tknString token
        tabla                               = getLBC estado
        (pilaAlcances, _)                   = getPila estado
        contenidos                          = map fromJust $ filter (isJust) $ map (\x -> buscarSimbolo nombre x tabla) pilaAlcances
        funciones                           = filter (isFunc . getCategoria) contenidos
        isFunc y                            = case y of {Func _ _ _ _ -> True; _ -> False}
        (Func _ parametros salida definida) = getCategoria (head funciones)
        (linea, _)                          = tknPos token

-- Usado en: DEFFUNC
agregarInstruccionesFunc :: Identificador -> [Instruccion] -> ECMonad ()
agregarInstruccionesFunc identificadorFun instrucciones = do
  estado <- get
  let (nuevoEstado, devolucion) = cambiarDefFuncion estado identificadorFun instrucciones
  put nuevoEstado
  let errores = concat $ map (\x -> buscarReturns x devolucion (fst $ tknPos identificadorFun)) instrucciones
  lift $ tell $ errores

-- Usado en: agregarInstruccionesFunc
cambiarDefFuncion :: Estado -> Identificador -> [Instruccion] -> (Estado, Type)
cambiarDefFuncion estado identificador instrucciones
  = (Estado nuevoLBC (getPila estado) (getAlcance estado) (toCheck estado) (getOffset estado), salida) 
  where nombre                         = tknString identificador
        tabla                          = getLBC estado
        (pilaAlcances, _)              = getPila estado
        contenidos                     = map fromJust $ filter (isJust) $ map (\x -> buscarSimbolo nombre x tabla) pilaAlcances
        funciones                      = filter (isFunc . getCategoria) contenidos
        contenidoTarget                = (head funciones)
        isFunc y                       = case y of {Func _ _ _ _ -> True; _ -> False}
        (Func _ parametros salida _)   = getCategoria (head funciones)
        (linea, _)                     = tknPos identificador
        nuevoContenido                 = Contenido nombre (Func instrucciones parametros salida True) (getAlcanceC contenidoTarget) (getOtro contenidoTarget) (getOffsetC contenidoTarget)
        nuevoLBC                       = M.adjust (M.adjust (\_ -> nuevoContenido) (getAlcanceC contenidoTarget)) nombre tabla

-- Usado en: agregarInstruccionesFunc
buscarReturns :: Instruccion -> Type -> Int -> [ErrorLog]
buscarReturns (InstReturn Nothing) t line       = if t <=> VoidType then [] else [TypeError $ "Linea " ++ show line ++ "\n\tSe debe retornar un elemento de tipo Void"]
buscarReturns (InstReturn (Just tr)) t line     = if t <=> (getTipoEx tr) then [] else [TypeError $ "Linea " ++ show line ++ "\n\tSe debia retornar un elemento de tipo " ++ (stringify' t)]
buscarReturns (InstIf listaIf) t line           = concat $ concat $ map (\(_,inst) -> map (\x -> buscarReturns x t line) inst) listaIf
buscarReturns (InstMatch (Match _ listaCase)) t line = concat $ map (\x -> buscarReturns x t line) (concat $ map getInstCase listaCase)
buscarReturns (InstRepDet det) t line           = concat $ map (\x -> buscarReturns x t line) (getInstDet det)
buscarReturns (InstRepIndet indet) t line       = concat $ map (\x -> buscarReturns x t line) (getInstIndet indet)
buscarReturns _ t _ = []

-------------------------------------------------------------------------------
-- Verificacion de Tipos
-------------------------------------------------------------------------------

--Usado en: DEFVARIABLE, DEFVARIABLEP
verificarTipoDef :: Identificador -> Type -> Type -> ECMonad ()
verificarTipoDef identificador tipoDef tipoIn = do
  if tipoDef <=> tipoIn then return ()
    else verificarTipoDefAux tipoDef tipoIn (tknString identificador) (tknPos identificador)

-- Usado en: verificarTipoDef
verificarTipoDefAux :: Type -> Type -> String -> (Int, Int) -> ECMonad ()
verificarTipoDefAux tipoDef tipoIn nombre (fila, columna) =
  if tipoDef <=> ErrorType
    then lift $ tell [TypeError $ "Linea " ++ (show fila) ++ "\n\tSe intenta declarar la variable " ++ nombre ++ " con un tipo inexistente"]
    else lift $ tell [TypeError $ "Linea " ++ (show fila) ++ "\n\tSe debe declarar la variable " ++ nombre ++ " con un elemento de tipo " ++ (stringify' tipoDef)]
-- Usado en: REPDETITER
verificarTipoRepDet :: Int -> Type -> Type -> Type -> ECMonad ()
verificarTipoRepDet _ IntType IntType IntType = return ()
verificarTipoRepDet _ FloatType FloatType IntType = return ()
verificarTipoRepDet _ FloatType IntType FloatType = return ()
verificarTipoRepDet _ FloatType FloatType FloatType = return ()
verificarTipoRepDet _ FloatType IntType IntType = return ()
verificarTipoRepDet _ CharType CharType CharType = return ()
verificarTipoRepDet f tIter tFrom tTo = lift $ tell [TypeError $ "Linea " ++ (show f) ++ "\n\t" ++ "Iterador de tipo " ++ (stringify' tIter) ++ ", expresion from de tipo " ++ (stringify' tFrom) ++ ", expresion to de tipo " ++ (stringify' tTo)]

-- Usado en: REPDETITER
verificarTipoRepDetBy :: Int -> Type -> Type -> Type -> Type -> ECMonad ()
verificarTipoRepDetBy _ IntType IntType IntType IntType = return ()
verificarTipoRepDetBy _ FloatType FloatType IntType IntType = return ()
verificarTipoRepDetBy _ FloatType IntType FloatType IntType = return ()
verificarTipoRepDetBy _ FloatType FloatType FloatType IntType = return ()
verificarTipoRepDetBy _ FloatType IntType IntType IntType = return ()
verificarTipoRepDetBy _ FloatType FloatType IntType FloatType = return ()
verificarTipoRepDetBy _ FloatType IntType FloatType FloatType = return ()
verificarTipoRepDetBy _ FloatType FloatType FloatType FloatType = return ()
verificarTipoRepDetBy _ FloatType IntType IntType FloatType = return ()
verificarTipoRepDetBy f tIter tFrom tTo tBy = lift $ tell [TypeError $ "Linea " ++ (show f) ++ "\n\t" ++ "Iterador de tipo " ++ (stringify' tIter) ++ ", expresion from de tipo " ++ (stringify' tFrom) ++ ", expresion to de tipo " ++ (stringify' tTo) ++ ", expresion by de tipo " ++ (stringify' tBy)]

-- Usado en: REPDETARRAY
verificarTipoRepDetArr :: Int -> Type -> Type -> ECMonad ()
verificarTipoRepDetArr f tIter (ArrayType tArr _) = if tIter == tArr then return () else lift $ tell [TypeError $ "Linea " ++ (show f) ++ "\n\t" ++ "Iterador de tipo " ++ (stringify' tIter) ++ " no puede iterar sobre arreglo con " ++ (stringify' tArr)]
verificarTipoRepDetArr f tIter tErr = lift $ tell [TypeError $ "Linea " ++ (show f) ++ "\n\t" ++ "No se puede iterar sobre un elemento de tipo " ++ (stringify' tErr)]

-- Usado en: SELECCIONIF, IF, LISTAELSE, SELECCIONIFF, IFF, LISTAELSEF, REPETICIONINDET, REPETICIONINDETF

verificarTipoCond :: Int -> Type -> ECMonad ()
verificarTipoCond f t    = if t <=> BoolType then return () else lift $ tell [TypeError $ "Linea " ++ (show f) ++ "\n\t" ++ "La condicion de la instruccion debe ser una expresion booleana."]


-- -- Usado en: SELECCIONMATCH, SELECCIONMATCHF
verificarCasosTag :: Type -> [Case] -> Pos -> ECMonad ()
verificarCasosTag (UnionType _ contTags) casos (linea, _) = do
  let tagsUnions    = tagsDeUnion contTags
  let tagsCasos     = tagsDeCasos casos
  let tagsFaltantes = tagsUnions S.\\ tagsCasos
  let tagsDeMas     = (tagsCasos S.\\ S.singleton "default") S.\\ tagsUnions
  let repitenCasos  = length (S.toList tagsCasos) /= length (casos)
  let repetidos     = filterRepeats $ map (tknString.getTypeCase) casos
  if repitenCasos
    then lift $ tell [TypeError $ "Linea " ++ show linea ++ "\n\tNo pueden haber casos repetidos en una instruccion match. Estos son los casos que se repiten: " ++ (unwords $ intersperse ", " repetidos)]
    else if tagsUnions == tagsCasos
      then return ()
      else
        if S.member "default" tagsCasos
          then if (S.isSubsetOf (tagsCasos S.\\ S.singleton "default") tagsUnions)
                then return ()
                else lift $ tell [TypeError $ "Linea " ++ show linea ++ "\n\tLa instruccion match contempla casos que el elemento Union no tiene. Estos son los casos que sobran: " ++ (unwords $ intersperse ", " $ S.toList tagsDeMas)]
          else if S.isSubsetOf tagsCasos tagsUnions
                then lift $ tell [TypeError $ "Linea " ++ show linea ++ "\n\tLa instruccion match no contempla casos que el elemento Union tiene, o falta el caso default. Estos son los casos que faltan: " ++ (unwords $ intersperse ", " $ S.toList tagsFaltantes)]
                else lift $ tell [TypeError $ "Linea " ++ show linea ++ "\n\tLa instruccion match contempla casos que el elemento Union no tiene. Estos son los casos que sobran: " ++ (unwords $ intersperse ", " $ S.toList tagsDeMas)]

verificarCasosTag _ casos (linea, _) = lift $ tell [TypeError $ "Linea " ++ show linea ++ "\n\tEl elemento contemplado en la instruccion Match no es de tipo Union"]

intersperse :: a -> [a] -> [a]
intersperse _   []      = []
intersperse _   [x]     = [x]
intersperse sep (x:xs)  = x : sep : intersperse sep xs

quicksort :: Ord a => [a] -> [a]
quicksort [] = []
quicksort (p:xs) = (quicksort lesser) ++ [p] ++ (quicksort greater)
    where
        lesser = filter (< p) xs
        greater = filter (>= p) xs

contaOcs :: [String] -> [(Int, String)]
contaOcs []     = []
contaOcs l      = contaOcsAux xs x 1
  where (x:xs) = quicksort l

contaOcsAux :: [String] -> String -> Int -> [(Int, String)]
contaOcsAux [] x i = [(i,x)]
contaOcsAux (x:xs) y i
  | x /= y = (i, y) : contaOcsAux xs x 1
  | x == y = contaOcsAux xs x (i + 1)

filterRepeats :: [String] -> [String]
filterRepeats strs = map snd filtered
  where counted  = contaOcs strs
        filtered = filter ((2<=).fst) counted

tagsDeCasos :: [Case] -> S.Set String
tagsDeCasos = S.fromList . (map (idODefault . getTypeCase))

-- Usado en: tagsDeCasos
idODefault :: Token -> String
idODefault (TKType _ str)  = str
idODefault (TKDefault _)   = "default"
idODefault _               = "undefined"

-- Usado en: verificarCasosTag
tagsDeUnion :: S.Set (Nombre, (S.Set (Nombre, Type, Alcance))) -> S.Set Nombre
tagsDeUnion = S.map (\(n, _) -> n)
-------------------------------------------------------------------------------
-- TypeName
-------------------------------------------------------------------------------
-- Usado en: TYPE
obtenerTipoTypeName :: Nombre -> ECMonad Type
obtenerTipoTypeName nombre = do
  estado <- get
  return $ buscarCategoriaTipoTabla estado nombre

-- Usado en: obtenerTipoTypeName
buscarCategoriaTipoTabla :: Estado -> Nombre -> Type
buscarCategoriaTipoTabla estado nombre = case encontrados of Nothing -> ErrorType
                                                             Just lista -> case devolucion lista of [] -> ErrorType
                                                                                                    (x:xs) -> unTp $ getCategoria $ fromJust x
  where tabla = getLBC estado
        (pilaAlcance, _) = getPila estado
        encontrados = M.lookup nombre tabla
        devolucion y = filter isJust $ map (\x -> M.lookup x y) pilaAlcance
        unTp (Tp x) = x

-------------------------------------------------------------------------------
-- Records y Unions
-------------------------------------------------------------------------------

-- Usado en: LISTADEF, LISTADEFT
createListDef :: Identificador -> Estado -> [(Nombre, Type, Alcance)] -> [(Nombre, Type, Alcance)]
createListDef identificador estado lista = case alcance of Nothing -> lista
                                                           Just c  -> (nombre, tipo, getAlcanceC c):lista
  where nombre  = tknString identificador
        tipo    = extractTypeIdent estado $ nombre
        alcance = buscarIdentificador nombre estado

-------------------------------------------------------------------------------
-- Varificaciones de Records y Unions
-------------------------------------------------------------------------------

--Usado en: DEFVARIABLE, MODVARIABLE, DEFVARIABLEP
verificarTipoBlock :: Pos -> Type -> [(Identificador, Expresion)] -> ECMonad ()
verificarTipoBlock (f,_) tipo listaAsig = do
  let setAsigTipos = S.fromList $ map (\(i,ex) -> (tknString i, getTipoEx ex)) listaAsig
  case tipo of RegType setReg -> if setAsigTipos `S.isSubsetOf` (S.map (\(x,y,_) -> (x,y)) setReg) then return () else lift $ tell $ [TypeError $ "Linea " ++ show f ++ "\n\tLa inicializacion de bloque no es una inicializacion valida."]
               _              -> lift $ tell $ [TypeError $ "Linea " ++ show f ++ "\n\tSolo se puede inicializar una variable de tipo Reg de esta forma"]

  -- let RegType setReg = tipoAnalizado

-- Usado en: DEFVARIABLE, MODVARIABLE, DEFVARIABLEP
modificarTipoUnion :: Pos -> LValue -> Type -> DefinicionDeBloqueUnion -> ECMonad Type
modificarTipoUnion (linea, _) lval (UnionType comunes tags) (tagActivo, listaAsig)
  = case (lookup nombreTagVerificar listaTags) of Nothing  -> do {lift $ tell $ [TypeError $ "Linea " ++ show linea ++ "\n\tEl tag asignado no existe"]; return ErrorType}
                                                  (Just x) -> case subset (S.map (\(x,y,_) -> (x,y)) x) of False -> do {lift $ tell $ [TypeError $ "Linea " ++ show linea ++ "\n\tLa inicializacion de bloque no es una inicializacion valida."]; return ErrorType}
                                                                                                           True  -> return $ UnionType comunes tags
  where nombreTagVerificar = tknString tagActivo
        listaTags = S.toList tags
        subset x = S.isSubsetOf (S.fromList $ map (\(i,ex) -> (tknString i, getTipoEx ex)) listaAsig) $ S.union x $ comunesFix
        comunesFix = S.map (\(x,y,_) -> (x,y)) comunes

modificarTipoUnion (linea, _) _ tipoEntrante _ = do
  lift $ tell $ [TypeError $ "Linea " ++ show linea ++ "\n\tLa variable que se intenta modificar no es de tipo Union"]
  return ErrorType

-------------------------------------------------------------------------------
-- Obtener Tipo de un L-Value
-------------------------------------------------------------------------------

-- Usado en: MODVARIABLE, EXPRESION
tryObtenerTipoLVal :: LValue -> Pos -> ECMonad Type
tryObtenerTipoLVal lval (line, _) = do
  estado <- get
  let tipo = extractTypeLvalue estado lval
  case obtenerTipoLVal estado lval tipo of Right tipo -> return tipo
                                           Left str   -> do{ if str /= "" then do { lift $ tell $ [TypeError $ "Linea " ++ (show line) ++ "\n\t" ++ str]; return ErrorType } else return ErrorType }

-- Usado en: tryObtenerTipoLval,
obtenerTipoLVal :: Estado -> LValue -> Type -> Either String Type
obtenerTipoLVal estado (LIdentificador identificador _ _ _) tipoIn
  = case tipoIn of ErrorType -> Left $ "El identificador " ++ (tknString identificador) ++ " no ha sido declarado"
                   tipo      -> Right tipo

obtenerTipoLVal estado (LAccessPointer lval _) tipoIn
  = case tipoIn of PointerType tipoInterno -> obtenerTipoLVal estado lval tipoInterno
                   RegType set             -> case obtenerTipoLVal estado lval (RegType set) of Right (PointerType tipoInterno) -> Right tipoInterno
                                                                                                x                               -> x
                   UnionType g t           -> case obtenerTipoLVal estado lval (UnionType g t) of Right (PointerType tipoInterno) -> Right tipoInterno
                                                                                                  x                               -> x
                   _                       -> Left $ "Solo se puede dereferenciar un Pointer"

obtenerTipoLVal estado (LAccessArray identificador exps _ _ _) tipoIn
  = case desindexado of ErrorType -> Left $ "Solo se puede indexar sobre un Array"
                        _         -> Right desindexado
  where desindexado = indexarArray tipoIn $ length exps

obtenerTipoLVal estado (LAccessMember leftLval rightLval _) tipoIn
  = case leftType of Right (RegType rset)            -> case tipoMemberReg rset of Nothing   -> Left $ "No se puede acceder al miembro " ++ rightName
                                                                                   Just tipo -> obtenerTipoLVal estado rightLval tipo
                     Right (UnionType gset tset)     -> case tipoMemberUnion gset tset of Just tipo -> case tipoMemberReg gset of Nothing   -> Right $ NullType (coleccionTiposUnion rightName gset tset)
                                                                                                                                  Just tipo -> obtenerTipoLVal estado rightLval tipo
                                                                                          Nothing -> Left $ "No se puede acceder al miembro " ++ rightName
                     Right tipo                      -> Right tipo
                     err                             -> err
  where leftType = obtenerTipoLVal estado leftLval tipoIn
        rightName = tknString $ obtenerNombreMiembro rightLval
        tipoMemberReg rset = lookup rightName $ map (\(x,y,_) -> (x,y)) $ S.toList rset
        tipoMemberUnion gset tset = lookup rightName $ map (\(x,y,_) -> (x,y)) $ S.toList $ S.union gset $ S.unions $ map snd $ S.toList tset
        coleccionTiposUnion rightName gset tset = extractAll rightName $ map (\(x,y,_) -> (x,y)) $ S.toList $ S.unions $ map snd $ S.toList tset

extractAll :: Nombre -> [(Nombre, Type)] -> [Type]
extractAll x xs = foldl (\acc (n,t) -> if x == n then t:acc else acc) [] xs

-- Usado en: tryObtenerTipoLval
extractTypeLvalue :: Estado -> LValue -> Type
extractTypeLvalue estado (LIdentificador identificador _ _ _) = extractTypeIdent estado $ tknString identificador
extractTypeLvalue estado (LAccessPointer lval _) = extractTypeLvalue estado lval
extractTypeLvalue estado (LAccessArray identificador _ _ _ _) = extractTypeIdent estado $ tknString identificador
extractTypeLvalue estado (LAccessMember lval _ _) = extractTypeLvalue estado lval


-- Usado en: obtenerTipoLVal
obtenerNombreMiembro :: LValue -> Identificador
obtenerNombreMiembro (LIdentificador id _ _ _) = id
obtenerNombreMiembro (LAccessArray id _ _ _ _) = id
obtenerNombreMiembro (LAccessMember l _ _) = obtenerNombreMiembro l

-- Usado en: obtenerTipoLVal
indexarArray :: Type -> Int -> Type
indexarArray tipo 0               = tipo
indexarArray (ArrayType tipo _) n = indexarArray tipo $ n - 1
indexarArray t n                  = ErrorType

-- Usado en: MODVARIABLE
compararLconR :: Pos -> Type -> Type -> ECMonad ()
compararLconR (l,_) ltipo rtipo = do
  if ltipo <=> rtipo || ltipo == ErrorType || rtipo == ErrorType then return () else lift $ tell $ [TypeError $ "Linea " ++ (show l) ++ "\n\tNo se puede modificar una variable de tipo " ++ stringify' ltipo ++ " con una expresion de tipo " ++ stringify' rtipo ]

-------------------------------------------------------------------------------

inicializarDeclaracionVacia :: Type -> Expresion
inicializarDeclaracionVacia IntType         = ExpNumero (TKNumbers (420, 69) "0") IntType
inicializarDeclaracionVacia CharType        = ExpCaracter (TKChar (420, 69) 'a') CharType
inicializarDeclaracionVacia BoolType        = ExpFalse BoolType
inicializarDeclaracionVacia FloatType       = ExpNumero (TKNumbers (420, 69) "0.0") FloatType
inicializarDeclaracionVacia StringType      = ExpString (TKString (420, 69) "") StringType
inicializarDeclaracionVacia (ArrayType t _) = ExpArray [inicializarDeclaracionVacia t] t
inicializarDeclaracionVacia r@(RegType t)   = ExpBlock baseExpr r
  where baseExpr = S.toList $ S.map (\(x, t, _) -> ((TKIdentifiers (420,69) x), inicializarDeclaracionVacia t)) $ getSetT r
inicializarDeclaracionVacia u@(UnionType _ _)       = ExpUBlock ((TKType (420, 69) tag), baseExpr) u
  where tag     = fst $ head $ S.toList $ getTags u
        comunes = S.toList $ S.map (\(x, t, _) -> ((TKIdentifiers (420, 69) x), inicializarDeclaracionVacia t)) $ getComunes u
        baseExpr = comunes ++ (S.toList $ S.map (\(x, t, _) -> ((TKIdentifiers (420, 69) x), inicializarDeclaracionVacia t)) $ fromJust $ lookup tag $ S.toList $ getTags u)
inicializarDeclaracionVacia (TypeNameType _ t) = inicializarDeclaracionVacia t 



-------------------------------------------------------------------------------
-- Testing
-------------------------------------------------------------------------------

symbolErrorToStr :: ErrorLog -> String
symbolErrorToStr (SymbolError str) = str
symbolErrorToStr (TypeError str) = ""

typeErrorToStr :: ErrorLog -> String
typeErrorToStr (SymbolError str) = ""
typeErrorToStr (TypeError str) = str

-------------------------------------------------------------------------------
-- Extraer Funciones
-------------------------------------------------------------------------------

-- [nombre , [alcance, contenido _ (Func _ _) _ _]]

extraerFunciones :: LBC -> [(String, [Instruccion], [Extra])]
extraerFunciones tabla = map getLoQueImporta funciones
  where 
    mapaDeTuplas = M.map M.toList tabla
    mapaDeContenidos = M.map (map snd) mapaDeTuplas
    listaDeContenidos = M.toList mapaDeContenidos
    contenidos = map snd listaDeContenidos
    funciones = filter (\x -> (isFun . getCategoria) x) (concat contenidos)
    isFun categoria = case categoria of {(Func _ _ _ _ ) -> True; _ -> False}
    getLoQueImporta (Contenido nombre (Func instrucciones _ _ _) _ extra _) = (nombre, instrucciones, extra)

