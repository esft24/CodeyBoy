module MachineCode where
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import qualified Data.Graph as G
import qualified Data.Array as A
import Control.Monad.State
import Control.Monad.Writer
import System.IO
import System.Environment
import Data.Maybe
import Data.List
import AST
import Tokens
import Debug.Trace
import ParserTabla
import LBC
import Lexer
import TAC


-------------------------------------------------------------------------------
-- División en Bloques Básicos
-------------------------------------------------------------------------------


type Bloque = [TAC]
type Key    = Int


testTargetCode :: String -> IO ()
testTargetCode path = do
    cosa <- testTAC path
    -- let bloquesFinos = enumerarBloques $ bloquesBasicos cosa
    -- let bloquesMasFinos = map (aDondeVamos bloquesFinos) bloquesFinos
    -- let (grafo, _, _) = G.graphFromEdges bloquesMasFinos
    -- putStrLn $ unlines $ map show $ bloquesMasFinos
    putStrLn ""
    
    let mapa                                       = reverse $ fixedPointLiveness $ reverse $ initInOut $ genKill $ listarSucesores cosa
    let killout                                    = killOut mapa
    let operandos                                  = enumerarOperandos cosa
    let grafo                                      = crearAristasOperandos killout operandos
    let (grafoReal, verticeAOperando, keyAVertice) = apiGrafoInterferencia grafo
    let edgesColor                                 = fromJust $  kColoreable 10 grafoReal []
    let tablaColores                               = inicializarTablaColores (length operandos) 10
    let tablaColoresFinal                          = colorearGrafo edgesColor tablaColores
    let tablaOR                                    = tablaOperandoRegistro tablaColoresFinal verticeAOperando keyAVertice
    -- putStrLn $ unlines $ map show tablaOR

    putStrLn $ unlines $ map show $ concatMap (escribirCodigoSimple tablaOR) cosa
    return ()
    

bloquesBasicos :: Bloque -> [Bloque]
bloquesBasicos tac = (++ [[]]) $ reverse $ foldl lideres [[]] tac


lideres :: [Bloque] -> TAC -> [Bloque]
lideres (ultimoBloque:otrosBloques) tac@(TACGoto _)       = []:(ultimoBloque ++ [tac]):otrosBloques
lideres (ultimoBloque:otrosBloques) tac@(TACIfGoto _ _ _) = []:(ultimoBloque ++ [tac]):otrosBloques
lideres ([]:otrosBloques) tac@(TACLabel _ )               = [tac]:otrosBloques
lideres otrosBloques tac@(TACLabel _ )                    = [tac]:otrosBloques
lideres (ultimoBloque:otrosBloques) tac                   = (ultimoBloque ++ [tac]):otrosBloques


enumerarBloques :: [Bloque] -> [(Key, Bloque)]
enumerarBloques bloques = zip [0..] bloques


aDondeVamos :: [(Key, Bloque)] -> (Key, Bloque) -> (Bloque, Key, [Key])
aDondeVamos _ (key, []) = ([], key, [])
aDondeVamos bloques (key, bloque) 
  = case ultimo of
      (TACGoto label)       -> (bloque, key, [buscarBloqueLabel bloques label])
      (TACIfGoto _ _ label) -> (bloque, key, [key + 1, buscarBloqueLabel bloques label])
      _                     -> (bloque, key, [key + 1])

    where
      ultimo = last bloque


buscarBloqueLabel :: [(Key, Bloque)] -> Label -> Key
buscarBloqueLabel bloques label = fst . head $ dropWhile (\x -> labelQuerido /= (head $ snd x)) bloques
      where 
        labelQuerido = (TACLabel label)

-------------------------------------------------------------------------------
-- Encontrar Variables Vivas
-------------------------------------------------------------------------------

data TACConfiguration = TACConfiguration {
                                            tacC :: TAC,
                                            sucesoresC ::  [Key],
                                            genSetC :: S.Set Operando,
                                            killSetC :: S.Set Operando,
                                            inSetC :: S.Set Operando,
                                            outSetC :: S.Set Operando
                                         } deriving (Eq, Show)


type MapInOut         = [(Key, TACConfiguration)]


enumerarTACs :: [TAC] -> [(TAC, Key)]
enumerarTACs tacs = zip (tacs ++ [(TACVacio "That's all folks")]) [0..]


buscarSucesores :: [(TAC, Key)] -> (TAC, Key) -> (TAC, Key, [Key])
buscarSucesores tacs (tac, key) = 
  case tac of
    (TACGoto label)       -> (tac, key, [buscarTacLabel tacs label])
    (TACIfGoto _ _ label) -> (tac, key, [key + 1, buscarTacLabel tacs label])
    (TACVacio _)          -> (tac, key, [])
    _                     -> (tac, key, [key + 1])


buscarTacLabel :: [(TAC, Key)] -> Label -> Key
buscarTacLabel tacs label = snd . head $ dropWhile (\x -> labelQuerido /= fst x) tacs
  where
    labelQuerido = TACLabel label


listarSucesores :: [TAC] -> [(TAC, Key, [Key])]
listarSucesores tacs = map (buscarSucesores enumerados) enumerados
  where
    enumerados = enumerarTACs tacs


-- [TAC, Key, Succ, Gen, Kill]
genKill :: [(TAC, Key, [Key])] -> [(TAC, Key, [Key], S.Set Operando, S.Set Operando)]
genKill = map (\(x, y, z) -> (x, y, z, gen x, kill x))


gen :: TAC -> S.Set Operando
gen (TACOperationB _ _ opn1 opn2) = S.fromList $ filter (isTacVar) [opn1,opn2]
gen (TACOperationU _ _ opn)       = S.fromList $ filter (isTacVar) [opn]
gen (TACStore _ opn)              = S.fromList $ filter (isTacVar) [opn]
gen (TACIfGoto _ opn _)           = S.fromList $ filter (isTacVar) [opn]
gen _                             = S.empty


kill :: TAC -> S.Set Operando
kill (TACOperationB _ opn _ _) = S.singleton opn
kill (TACOperationU _ opn _)   = S.singleton opn
kill (TACStore opn _)          = S.singleton opn
kill _                         = S.empty


initInOut :: [(TAC, Key, [Key], S.Set Operando, S.Set Operando)] -> MapInOut
initInOut = map (\(a,b,c,d,e) -> (b, TACConfiguration a c d e S.empty S.empty))


lookUp :: MapInOut -> Key -> TACConfiguration
lookUp m k = fromJust result
 where 
   result = case lookup k m of
              Nothing -> Prelude.error $ (show k) ++ " " ++ (show m)
              x       -> x


calculateOut :: MapInOut -> TACConfiguration -> TACConfiguration
calculateOut mapInOut (TACConfiguration tac sucesores gen kill inS outS)
  = TACConfiguration tac sucesores gen kill inS newOut
    where
      newOut = S.unions $ map (inSetC . (lookUp mapInOut)) sucesores


calculateIn :: MapInOut -> TACConfiguration -> TACConfiguration
calculateIn mapInOut (TACConfiguration tac sucesores gen kill inS outS)
  = TACConfiguration tac sucesores gen kill newIn outS
    where
      newIn = S.union gen $ S.difference outS kill
  

split :: (a -> Bool) -> [a] -> ([a], a, [a])
split p l = (start, middle, tail end)
  where
    start  = takeWhile p l
    end    = dropWhile p l
    middle = head end 


fixedPointLiveness :: MapInOut  -> MapInOut
fixedPointLiveness mapOriginal = if mapOriginal == newMap then newMap else fixedPointLiveness newMap
  where
    newMap = modifyMap mapOriginal empiezo
    empiezo = (fst . head) mapOriginal
    modifyMap mapa iter = if iter == 0 then (first ++ [(key , (calculateIn mapa) $ (calculateOut mapa) tacMiddle)] ++ end)
                            else modifyMap (first ++ [(key, (calculateIn mapa) $ (calculateOut mapa) tacMiddle)] ++ end) (iter - 1)
      where 
        (first, (key, tacMiddle), end) = split ((iter /=) . fst) mapa 

-------------------------------------------------------------------------------
--  Crear Grafo de Interferencia
-------------------------------------------------------------------------------


killOut :: MapInOut -> S.Set (Operando, Operando)
killOut mapa = S.unions $ map (\(TACConfiguration _ _ _ kill _ out) -> S.cartesianProduct kill out) $ map snd mapa


enumerarOperandos :: [TAC] -> [(Operando, Key)]
enumerarOperandos tacs 
  = zip operandos [0..]
  where
    operandos = S.toList $ S.unions $ map kill tacs


crearAristasOperandos :: S.Set (Operando, Operando) -> [(Operando, Key)] -> [((Operando, Color), Key , [Key])]
crearAristasOperandos interf operandos = grafo
  where
    grafo = map (\(op, k) -> ((op, 0), k, filter (/=k) $ keysIntercepcion interf operandos op)) operandos


keysIntercepcion :: S.Set (Operando, Operando) -> [(Operando, Key)] -> Operando -> [Key]
keysIntercepcion interf operandos op = S.toList keys
    where
      primeros = S.map snd $ S.filter ((op ==) . fst) interf
      keys     = S.map (fromJust . (\ x -> (flip lookup) operandos x)) primeros 


apiGrafoInterferencia :: [((Operando, Color), Key , [Key])]
                          -> (G.Graph, G.Vertex -> ((Operando, Color), Key, [Key]), Key -> Maybe G.Vertex)
apiGrafoInterferencia initialEdges = (newGraph, nodeFromVertex, vertexFromKey)
  where
    (initialGraph, nodeFromVertex, vertexFromKey) = G.graphFromEdges initialEdges
    transposed                                    = G.edges $ G.transposeG initialGraph
    allEdges                                      = S.toList $ S.fromList $ transposed ++ G.edges initialGraph
    newGraph                                      = G.buildG (0, length initialEdges - 1) allEdges

-------------------------------------------------------------------------------
--  Colorear Nodos
-------------------------------------------------------------------------------

type MaxColores = Int
type Color      = Int

eliminarNodo :: MaxColores -> G.Graph -> Maybe (G.Graph, (Key, [G.Edge]))
eliminarNodo k grafo = if null validos then Nothing else Just (G.buildG (0, length listaGrados - 1) nuevosEdges, (elegido, edgesEliminados))
  where
    arregloGrados = G.outdegree grafo
    listaGrados   = A.assocs arregloGrados
    validos       = filter (\(i,d) -> d /= 0 && d < k) listaGrados
    elegido       = fst $ head validos
    edgesActuales = G.edges grafo
    (nuevosEdges, edgesEliminados) = foldl (\(keep, elim) (a,b) -> if a == elegido || b == elegido then (keep,(a,b):elim) else ((a,b):keep, elim)) ([],[]) edgesActuales


nullG :: G.Graph -> Bool
nullG grafo = null $ G.edges grafo


kColoreable :: MaxColores -> G.Graph -> [(Key, [G.Edge])] -> Maybe [(Key, [G.Edge])]
kColoreable k grafo acc = if nullG grafo then Just acc
                            else case eliminarNodo k grafo of
                                   Nothing -> Nothing
                                   Just (nuevoGrafo, edgesExtraidos) -> kColoreable k nuevoGrafo (acc ++ [edgesExtraidos])


colorearGrafo :: [(Key, [G.Edge])] -> [(Key, [Color])] -> [(Key, Color)]
colorearGrafo [] tablaColores = map (\(a, b) -> (a, head b)) tablaColores 
colorearGrafo ((elegido, x):edgesExtraidos) tablaColores
  = colorearGrafo edgesExtraidos nuevaTabla
    where
      otrasEdges   = filter (/= elegido) $ (map fst x) ++ (map snd x)
      colorElegido = head $ fromJust $ lookup elegido tablaColores
      nuevaTabla   = foldl (\acc (key, colores) -> if key == elegido 
                                                     then (key, [colorElegido]):acc 
                                                     else if key `elem` otrasEdges 
                                                       then (key, filter (/= colorElegido) colores):acc 
                                                       else (key, colores):acc) [] tablaColores
    
      
inicializarTablaColores :: Int -> MaxColores -> [(Key, [Color])]
inicializarTablaColores nOperandos k = zip [0..nOperandos - 1] $ repeat [0..k-1]


tablaOperandoRegistro :: [(Key, Color)] -> (G.Vertex -> ((Operando, Color), Key, [Key])) -> (Key -> Maybe G.Vertex) -> [(Operando, Color)]
tablaOperandoRegistro colores verticeAOperando keyAVertice 
  = map (\(key, color) -> (keyAOperando key, color)) colores
    where
      keyAOperando                    = limpiarOperando . verticeAOperando . fromJust . keyAVertice 
      limpiarOperando ((op, _), _, _) = op


-------------------------------------------------------------------------------
-- Codigo de Maquina
-------------------------------------------------------------------------------

data MCVal = MCReg Int | MCLiteral String | Zero | Hi | Lo deriving (Eq)
data MC = ADD  MCVal MCVal MCVal -- add  $d, $s, $t --> $d = $s + $t 
        | ADDi MCVal MCVal MCVal -- addi $d, $s, i  --> $d = $s + i
        | SUB  MCVal MCVal MCVal -- sub  $d, $s, $t --> $d = $s - $t
        | AND  MCVal MCVal MCVal -- and  $d, $s, $t --> $d = $s & $t
        | OR   MCVal MCVal MCVal -- or   $d, $s, $t --> $d = $s | $t
        | ORi  MCVal MCVal MCVal -- ori  $d, $s, i  --> $d = $s | i
        | XORi MCVal MCVal MCVal 
        | MULT MCVal MCVal       -- mult $s, $t     --> hi:lo = $s * $t
        | DIV  MCVal MCVal       -- div  $s, $t     --> lo = $s / $t; hi = $s % $t
        
        | MFHI  MCVal            -- mfhi $d         --> $d = hi
        | MFLO  MCVal            -- mflo $d         --> $d = lo

        | Li    MCVal MCVal      -- li $d, i        --> $d = i

        | SLT  MCVal MCVal MCVal -- slt  $d, $s, $t --> $d = ($s < $t)
        | SLTi MCVal MCVal MCVal -- slti $d, $s, i  --> $d = ($s < i)

        | Message String
        | TODO TAC deriving (Eq)
        
instance Show MCVal where
  show (MCReg i)       = "$t" ++ show i
  show (MCLiteral str) = str
  show Zero            = "$0"
  show Hi              = "$hi"
  show Lo              = "$lo"

instance Show MC where
  show (ADD d t s)  = "add "  ++ addcommas [d,t,s]
  show (ADDi d t s) = "addi " ++ addcommas [d,t,s]
  show (SUB d t s)  = "sub "  ++ addcommas [d,t,s]
  show (AND d t s)  = "and "  ++ addcommas [d,t,s]
  show (OR d t s)   = "or "   ++ addcommas [d,t,s]
  show (XORi d t s) = "xor "  ++ addcommas [d,t,s]
  show (ORi d t s)  = "ori "  ++ addcommas [d,t,s]
  show (MULT t s)   = "mult " ++ addcommas [t,s]
  show (DIV t s)    = "div "  ++ addcommas [t,s]
  show (MFHI t)     = "mfhi " ++ show t
  show (MFLO t)     = "mflo " ++ show t
  show (Li d t)     = "li "   ++ addcommas [d,t]
  show (SLT d t s)  = "slt "  ++ addcommas [d,t,s]
  show (SLTi d t s) = "slti " ++ addcommas [d,t,s]
  show (Message s)  = s
  show (TODO tac)   = show tac


addcommas :: Show a => [a] -> String
addcommas [s]   = show s
addcommas (s:t) = show s ++ ", " ++ addcommas t

escribirCodigoSimple :: [(Operando, Color)] -> TAC -> [MC]

escribirCodigoSimple tablaDeRegistros (TACOperationU "-" str op1)
  | mczero == s                    = []
  | isLiteral op1                  = [Li d s']
  | otherwise                      = [SUB d Zero s]
  where
    d = operandoAMaquina str tablaDeRegistros
    s = operandoAMaquina op1 tablaDeRegistros
    s' = operandoAMaquina (negateLiteral op1) tablaDeRegistros

escribirCodigoSimple tablaDeRegistros (TACOperationU "!" str op1)
  | s == mczero                    = [Li d mcone]
  | s == mcone                     = [Li d mczero]
  | otherwise                      = [XORi d s mcone]
  where
    d = operandoAMaquina str tablaDeRegistros
    s = operandoAMaquina op1 tablaDeRegistros

escribirCodigoSimple tablaDeRegistros tac@(TACOperationB "+" str op1 op2)
  | isLiteral op1 && isLiteral op2 = [ORi d Zero s, ADDi d d t]
  | isLiteral op1                  = [ADDi d t s]
  | isLiteral op2                  = [ADDi d s t]
  | otherwise                      = [ADD d s t]
  where
    d = operandoAMaquina str tablaDeRegistros
    s = operandoAMaquina op1 tablaDeRegistros
    t = operandoAMaquina op2 tablaDeRegistros

escribirCodigoSimple tablaDeRegistros (TACOperationB "-" str op1 op2)
  | s == t                         = [Li d mczero]
  | isLiteral op1 && isLiteral op2 = [Li d s, ADDi d d t']
  | isLiteral op1                  = [Li d s, SUB d d t]
  | isLiteral op2                  = [ADDi d s t']
  | otherwise                      = [SUB d s t]
  where
    d  = operandoAMaquina str tablaDeRegistros
    s  = operandoAMaquina op1 tablaDeRegistros
    t  = operandoAMaquina op2 tablaDeRegistros
    t' = operandoAMaquina (negateLiteral op2) tablaDeRegistros
    

escribirCodigoSimple tablaDeRegistros (TACOperationB "<" str op1 op2)
  | s == t                         = [Li d mczero]
  | isLiteral op1 && isLiteral op2 = [ORi d Zero s, SLTi d d t]
  | isLiteral op1                  = [Li d s, SLT d d t]
  | isLiteral op2                  = [SLTi d s t]
  | otherwise                      = [SLT d s t]
  where
    d   = operandoAMaquina str tablaDeRegistros
    s   = operandoAMaquina op1 tablaDeRegistros
    t   = operandoAMaquina op2 tablaDeRegistros

escribirCodigoSimple tablaDeRegistros (TACOperationB ">" str op1 op2)  
  = escribirCodigoSimple tablaDeRegistros (TACOperationB "<" str op2 op1)

-- 2 parts
escribirCodigoSimple tablaDeRegistros (TACOperationB "*" str op1 op2)
  | s == mczero || t == mczero     = [Li d Zero]
  | s == mcone                     = escribirCodigoSimple tablaDeRegistros (TACStore str op2) 
  | t == mcone                     = escribirCodigoSimple tablaDeRegistros (TACStore str op1)
  | isLiteral op1 && isLiteral op2 = [ORi d Zero s, MULT d t, MFLO d]
  | isLiteral op1                  = [Li d s, MULT d t, MFLO d]
  | isLiteral op2                  = [Li d t, MULT d s, MFLO d]
  | otherwise                      = [ORi d Zero s, MULT d t, MFLO d]
  where
    d   = operandoAMaquina str tablaDeRegistros
    s   = operandoAMaquina op1 tablaDeRegistros
    t   = operandoAMaquina op2 tablaDeRegistros

-- escribirCodigoSimple (TACOperationB "/" str op1 op2)  =
escribirCodigoSimple tablaDeRegistros (TACOperationB "%" str op1 op2) 
  | t == mcone                     = escribirCodigoSimple tablaDeRegistros (TACStore str op1)
  | isLiteral op1 && isLiteral op2 = [ORi d Zero s, MULT d t, MFHI d]
  | isLiteral op1                  = [Li d s, DIV d t, MFHI d]
  | isLiteral op2                  = [Li d t, DIV d s, MFHI d]
  | otherwise                      = [ORi d Zero s, DIV d t, MFHI d]
  where
    d   = operandoAMaquina str tablaDeRegistros
    s   = operandoAMaquina op1 tablaDeRegistros
    t   = operandoAMaquina op2 tablaDeRegistros


escribirCodigoSimple tablaDeRegistros (TACOperationB "//" str op1 op2)
  | t == mcone                     = escribirCodigoSimple tablaDeRegistros (TACStore str op1)
  | isLiteral op1 && isLiteral op2 = [ORi d Zero s, MULT d t, MFLO d]
  | isLiteral op1                  = [Li d s, DIV d t, MFLO d]
  | isLiteral op2                  = [Li d t, DIV d s, MFLO d]
  | otherwise                      = [ORi d Zero s, DIV d t, MFLO d]
  where
    d   = operandoAMaquina str tablaDeRegistros
    s   = operandoAMaquina op1 tablaDeRegistros
    t   = operandoAMaquina op2 tablaDeRegistros

-- escribirCodigoSimple (TACOperationB ">=" str op1 op2) =
-- escribirCodigoSimple (TACOperationB "<=" str op1 op2) = 
-- escribirCodigoSimple (TACOperationB "==" str op1 op2) =
-- escribirCodigoSimple (TACOperationB "/=" str op1 op2) =

escribirCodigoSimple tablaRegistros (TACStore store opn) 
  | d == s        = []
  | isLiteral opn = [Li d s]
  | otherwise     = [ORi d s Zero]
    where
      d = operandoAMaquina store tablaRegistros
      s = operandoAMaquina opn tablaRegistros

escribirCodigoSimple tablaRegistros tac = [TODO tac]

operandoAMaquina :: Operando -> [(Operando, Color)] -> MCVal
operandoAMaquina (Literal "True") _  = MCLiteral "1"
operandoAMaquina (Literal "False") _ = MCLiteral "0"
operandoAMaquina (Literal str) _    = MCLiteral str
operandoAMaquina opn tablaRegistros = MCReg $ (fromJust . ((flip $ lookup) tablaRegistros)) opn

isLiteral :: Operando -> Bool
isLiteral (Literal _) = True
isLiteral _           = False 

negateLiteral :: Operando -> Operando
negateLiteral (Literal str) = Literal $ "-" ++ str
negateLiteral x             = x

mczero, mcone :: MCVal
mczero = MCLiteral "0"
mcone  = MCLiteral "1"