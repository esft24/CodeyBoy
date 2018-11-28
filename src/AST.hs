-- AST de CodeyBoy
-- Integrantes:
--              Erick Flejan    12-11555
--              Carlos Perez    13-11089

-- CI-4721 Lenguajes de Programacion II

module AST where
import Lexer
import Tokens
import qualified Data.Set as S
import Debug.Trace
--import Parser

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
type Alcance = Int
type IdentConAlcance = (Token, Alcance)

type Offset = (String, Int)

data Parametro =        PorValor {getTokenP :: Token, getOffsetP :: Offset}
                        | PorReferencia {getTokenP :: Token, getOffsetP :: Offset}
                        deriving(Show,Eq)

data Instruccion =      DeclaracionVariable {getTokenI :: Identificador}
                        | ModificacionSimple LValue Expresion
                        | ModificacionReg LValue DefinicionDeBloque
                        | ModificacionUnion LValue DefinicionDeBloqueUnion
                        | DefinicionDeFuncion Identificador [Instruccion]
                        | InstIf If
                        | InstMatch Match
                        | InstRepDet RepeticionDet
                        | InstRepIndet RepeticionIndet
                        | InstLlamada Llamada
                        | Print Expresion
                        | Free Expresion
                        | InstReturn (Maybe Expresion)
                        | InstBreak
                        deriving(Show,Eq)



getTokenDec :: Instruccion -> Identificador
getTokenDec (ModificacionSimple lval _) = getIdentL lval
getTokenDec (ModificacionReg lval _) = getIdentL lval
getTokenDec (ModificacionUnion lval _) = getIdentL lval
getTokenDec (DeclaracionVariable id)    = id

data LValue =           LAccessMember    {getLeft :: LValue, getRight :: LValue, getLPos :: Pos}
                        | LIdentificador {getIdentL :: Identificador, getLPos :: Pos, getOffsetL :: Offset, getAlcanceL :: Int}
                        | LAccessArray   {getIdentL :: Identificador, getListaExpL :: [Expresion], getLPos :: Pos, getOffsetL :: Offset, getAlcanceL :: Int}
                        | LAccessPointer {getL :: LValue, getLPos :: Pos}
                        deriving(Show,Eq,Ord)

data Type =             IntType
                        | CharType
                        | BoolType
                        | FloatType
                        | ArrayType {getTypeT :: Type, getExpresionT :: Expresion} -- Por que no tiene funciones de acceso?
                        | StringType
                        | PointerType { getTypeT :: Type }
                        | TypeNameType { getTypeNameT :: TypeName, getTypeT :: Type}  -- Por que no tiene funciones de acceso?
                        | VoidType
                        | RegType { getSetT :: (S.Set (Nombre, Type, Alcance)) } -- Por que no tiene funciones de acceso?
                        | UnionType { getComunes :: (S.Set (Nombre, Type, Alcance)), getTags :: S.Set (Nombre, (S.Set (Nombre, Type, Alcance)))}
                        | ErrorType
                        | NullType [Type]
                        deriving(Show,Eq,Ord)
                        -- RegType (S.Set (Nombre, (Alcance, Type)))

type Nombre =           String
type TypeName =         Token

type If =               [(Expresion, [Instruccion])]

data Match =            Match LValue [Case] deriving(Show,Eq)

data Case =             Case {getTypeCase :: TypeName, getInstCase :: [Instruccion]} deriving(Show,Eq)

data RepeticionDet =    RepDet {getIdentDet :: Identificador, getTypeDet :: Type, getExpFrom :: Expresion, getExpTo :: Expresion, getExpBy :: (Maybe Expresion), getInstDet :: [Instruccion], getOffsetRep :: Offset}
                       | RepDetArray {getIdentDet :: Identificador, getTypeDet :: Type, getExpDet :: Expresion, getInstDet :: [Instruccion], getOffsetRep :: Offset}
                        deriving(Show,Eq)

-- Tipo Intermedio para realizar las repeticiones
data InterRepDet =      Inter {interIdent :: Identificador, interType :: Type, interFrom :: Expresion, interTo :: Expresion, interBy :: (Maybe Expresion), interOffset :: Offset}
                        | InterArray {interIdent :: Identificador, interType :: Type, interExp :: Expresion, interOffset :: Offset}

data RepeticionIndet =  RepeticionIndet {getExpIndet :: Expresion, getInstIndet :: [Instruccion]} deriving(Show,Eq)

data Expresion =        ExpLlamada {getLlamada :: Llamada, getTipoEx :: Type}
                        | ExpAcceso {getAccessMember :: AccessMember, getTipoEx :: Type}
                        | ExpArray {getExpresiones :: [Expresion], getTipoEx :: Type}
                        | ExpNumero { getToken :: Number, getTipoEx :: Type}
                        | ExpCaracter { getToken :: Token, getTipoEx :: Type}
                        | ExpTrue { getTipoEx :: Type}
                        | ExpFalse { getTipoEx :: Type}
                        | ExpString { getToken :: StringBoy, getTipoEx :: Type}
                        | ExpMalloc { getTipoEx :: Type }
                        | ExpInput { getTipoEx :: Type }
                        | ExpStringify {getExpresion :: Expresion, getTipoEx :: Type}
                        | ExpBlock {getDefDeBloque :: DefinicionDeBloque, getTipoEx :: Type }
                        | ExpUBlock {getDefDeBloqueU :: DefinicionDeBloqueUnion, getTipoEx :: Type }
                        | ExpNot { getExpresion :: Expresion, getTipoEx :: Type}
                        | ExpOr { operadorIzq, operadorDer :: Expresion, getTipoEx :: Type }
                        | ExpAnd { operadorIzq, operadorDer :: Expresion, getTipoEx :: Type }
                        | ExpGreater { operadorIzq, operadorDer :: Expresion, getTipoEx :: Type }
                        | ExpLesser { operadorIzq, operadorDer :: Expresion, getTipoEx :: Type }
                        | ExpGreaterEqual { operadorIzq, operadorDer :: Expresion, getTipoEx :: Type }
                        | ExpLesserEqual { operadorIzq, operadorDer :: Expresion, getTipoEx :: Type }
                        | ExpEqual { operadorIzq, operadorDer :: Expresion, getTipoEx :: Type }
                        | ExpNotEqual { operadorIzq, operadorDer :: Expresion, getTipoEx :: Type }
                        | ExpPlus { operadorIzq, operadorDer :: Expresion, getTipoEx :: Type }
                        | ExpMinus { operadorIzq, operadorDer :: Expresion, getTipoEx :: Type }
                        | ExpProduct { operadorIzq, operadorDer :: Expresion, getTipoEx :: Type }
                        | ExpDivision { operadorIzq, operadorDer :: Expresion, getTipoEx :: Type }
                        | ExpMod { operadorIzq, operadorDer :: Expresion, getTipoEx :: Type }
                        | ExpWholeDivision { operadorIzq, operadorDer :: Expresion, getTipoEx :: Type }
                        | ExpUminus { getExpresion :: Expresion, getTipoEx :: Type}
                        | ExpArrayAccess { getToken :: Identificador, getExpresion :: Expresion, getTipoEx :: Type }
                        | ExpRValue { getRValue :: LValue , getTipoEx :: Type }
                        deriving(Show,Eq,Ord)

type Number =           Token
type StringBoy =        Token

type AccessMember =     [Identificador]

data Llamada =        Llamada {getTokenL :: Identificador, getParametros :: [Expresion]}
                      | LlamadaModulo TypeName Identificador [Expresion]
                      deriving(Show,Eq,Ord)

type DefinicionDeBloque = [(Identificador, Expresion)]
type DefinicionDeBloqueUnion = (TypeName, DefinicionDeBloque)

(<=>) :: Type -> Type -> Bool
NullType [] <=> _ = True
_ <=> NullType [] = True
NullType xs <=> t = elem t xs
t <=> NullType xs = elem t xs
(PointerType t1) <=> (PointerType t2) = t1 <=> t2
(ArrayType t1 _) <=> (ArrayType t2 _) = t1 <=> t2
(RegType set1) <=> (RegType set2) = typeseteq
  where typeseteq = foldl1 (&&) $ zipWith (eqNameType) (toNameSet set1) (toNameSet set2)
        toNameSet = S.toDescList . S.map (\(n,t,_) -> (n,t))
(UnionType gset1 tset1) <=> (UnionType gset2 tset2) = gSetEq && tSetEq && (tTags tset1 == tTags tset2)
 where gSetEq  = (null (gSetFix gset1) && null (gSetFix gset2)) || (foldl1 (&&) $ zipWith (eqNameType) (gSetFix gset1) (gSetFix gset2))
       tSetEq  = if null (tSetFix tset1) || null (tSetFix tset2)
                 then tSetEmptyness
                 else foldl1 (&&) $ zipWith (eqNameTypeTag) (tSetFix tset1) (tSetFix tset2)
       gSetFix = S.toDescList . S.map (\(n,t,_) -> (n,t))
       tSetFix = S.toDescList . (S.foldl S.union S.empty) . S.map (\(tag, contenido) -> S.map (\(n,t,_)->(tag,n,t)) contenido)
       tTags = S.map (\(tag, contenido) -> tag)
       tSetEmptyness = null (tSetFix tset1) && tTags tset1 == tTags tset2 && null (tSetFix tset2)
ErrorType <=> _ = False
_ <=> ErrorType = False
t1 <=> t2      = t1 == t2

eqNameType :: (Nombre, Type) -> (Nombre, Type) -> Bool
eqNameType (n1,t1) (n2,t2) = n1 == n2 && t1 <=> t2

eqNameTypeTag :: (Nombre, Nombre, Type) -> (Nombre, Nombre, Type) -> Bool
eqNameTypeTag (tag1,n1,t1) (tag2,n2,t2) = tag1 == tag2 && n1 == n2 && t1 <=> t2

--------------------------------------------------------------------------------

tabs :: Int -> String
tabs n = replicate n '\t'