-- Parser de CodeyBoy
-- Integrantes:
--              Erick Flejan    12-11555
--              Carlos Perez    13-11089

-- CI-4721 Lenguajes de Programacion II

{
module ParserTabla where
import Lexer
import Tokens
import AST
import System.IO
import System.Environment
import Control.Monad.State
import Control.Monad.Writer
import qualified Data.Map.Strict as M
import LBC
import Debug.Trace
}

%name parserBoy
%monad { ECMonad }

%tokentype { Token }
%error { parseError }

%token
    Int               { TKIntType _ }
    Bool              { TKBoolType _ }
    Char              { TKCharType _ }
    Float             { TKFloatType _ }
    Void              { TKVoidType _ }
    Array             { TKArrayType _ }
    String            { TKStringType _ }
    Reg               { TKRegType _ }
    Boy               { TKBoyType _ }
    Union             { TKUnionType _ }
    Pointer           { TKPointerType _ }
    while             { TKWhile _ }
    for               { TKFor _ }
    from              { TKFrom _ }
    to                { TKTo _ }
    by                { TKBy _ }
    in                { TKIn _ }
    if                { TKIf _ }
    else              { TKElse _ }
    otherwise         { TKOtherwise _ }
    with              { TKWith _ }
    func              { TKFunc _ }
    let               { TKLet _ }
    equal             { TKAssign _ }
    colon             { TKTypeDef _ }
    begin             { TKOpenBracket _ }
    end               { TKCloseBracket _ }
    open              { TKOpenParenthesis _ }
    close             { TKCloseParenthesis _ }
    openSq            { TKOpenSqrBracket _ }
    closeSq           { TKCloseSqrBracket _ }
    not               { TKNot _ }
    eq                { TKEqual _ }
    uneq              { TKUnequal _ }
    and               { TKAnd _ }
    or                { TKOr _ }
    gt                { TKGreater _ }
    lt                { TKLesser _ }
    goet              { TKGreaterEqual _ }
    loet              { TKLesserEqual _ }
    plus              { TKPlus _ }
    minus             { TKMinus _ }
    mult              { TKMultiplication _ }
    wdiv              { TKWholeDivision _ }
    div               { TKDivision _ }
    mod               { TKMod _ }
    True              { TKTrue _ }
    False             { TKFalse _ }
    comma             { TKComma _ }
    point             { TKPoint _ }
    dollar            { TKDollar _ }
    return            { TKReturn _ }
    print             { TKPrint _ }
    input             { TKInput _ }
    malloc            { TKMalloc _ }
    free              { TKFree _ }

    bring             { TKBring _ }
    "the boys"        { TKTheBoys _ }
    all               { TKAll _ }
    who               { TKWho _ }
    aka               { TKAka _ }
    but               { TKBut _ }

    Tag               { TKTag _ }
    case              { TKCase _ }
    match             { TKMatch _ }

    Nl                { TKNewline _ }
    character         { TKChar _ _ }
    number            { TKNumbers _ _ }
    string            { TKString _ _ }
    TypeName          { TKType _ _ }
    identifier        { TKIdentifiers _ _ }

-- AQUI VAN LAS PRECEDENCIAS

%left or
%left and
%nonassoc eq uneq gt goet loet lt
%right not

%left plus minus
%left mult div mod wdiv
%right uminus

%nonassoc then
%nonassoc else

%%

-- Inicio
START: Nl PROGRAMA         { $2 }
       | PROGRAMA          { $1 }


PROGRAMA:     IMPORTS Nl INSTRUCCIONES { Programa (reverse $1) (reverse $3) }
              | INSTRUCCIONES          { Programa [] (reverse $1) }
              | IMPORTS                { Programa (reverse $1) [] }

------------------------------------------------------------------------------------------------------------------------

-- Lista de Imports
IMPORTS:      IMPORTS Nl IMPORT                                                          { $3:$1 }
              | IMPORT                                                                   { $1:[] }

-- Importacion de un modulo Quiza haya que restar 1
IMPORT:       bring all "the boys" from string                                           { ImportAll $5 [] Nothing }
              | bring all "the boys" from string but open LISTAIDENT close               { ImportAll $5 (reverse $8) Nothing }
              | bring all "the boys" from string aka TypeName                            { ImportAll $5 [] (Just $7) }
              | bring all "the boys" from string but open LISTAIDENT close aka TypeName  { ImportAll $5 (reverse $8) (Just $11) }
              | bring "the boys" from string who open LISTAIDENT close                   { ImportSome $4 (reverse $7) Nothing }
              | bring "the boys" from string who open LISTAIDENT close aka TypeName      { ImportSome $4 (reverse $7) (Just $10) }

-- Serie de identificadores seleccionados de un modulo
LISTAIDENT:   identifier                                                                 { $1:[] }
              | LISTAIDENT comma identifier                                              { $3:$1 }

----------------------------------------------------------------------------------------------------

-- Instrucciones
INSTRUCCIONES: INSTRUCCIONES Nl INSTRUCCION    { if ($3 /= DeclaracionVariable) then $3:$1 else $1 }
               | INSTRUCCION                   { if ($1 /= DeclaracionVariable) then $1:[] else [] }

-- Instruccion
INSTRUCCION:    DEFVARIABLE                   { $1 }
              | MODVARIABLE                   { $1 }
              | DEFDETIPO                     { $1 }
              | DEFFUNC                       { $1 }
              | SELECCIONIF                   { InstIf $1 }
              | SELECCIONMATCH                { InstMatch $1 }
              | REPETICIONDET                 { InstRepDet $1 }
              | REPETICIONINDET               { InstRepIndet $1 }
              | LLAMADA                       { InstLlamada $1 }
              | print open EXPRESION close    { Print $3 }
              | free open identifier close    { Free $3 }

-- Nuevo Bloque de Instrucciones
NUEVOBLOQUE: begin                            {% nuevoBloque }

----------------------------------------------------------------------------------------------------

-- Tipos Validos Posibles
-- LOS ULTIMOS TRES CAMBIAN LA TABLA Y NO LOS HEMOS HECHO
TYPE:         Int                                                       { IntType }
              | Bool                                                    { BoolType }
              | Char                                                    { CharType }
              | Float                                                   { FloatType }
              | Array lt SIMPLETYPE comma number gt                     { ArrayType }
              | String                                                  { StringType }
              | Pointer                                                 { PointerType }
              | TypeName                                                { TypeNameType $1 }
              | Void                                                    { VoidType }
              | Reg NUEVOBLOQUE LISTADEF Nl end                         {% do {finalizarBloqueU; return $ RegType (reverse $3)} } -- AQUIIIIIIIIIII!!!!!!!!!!!!!!!!!!
              | Union NUEVOBLOQUE LISTADEF Nl with Nl LISTATAG Nl end   {% do {finalizarBloqueU; return $ UnionType (Just (reverse $3)) (reverse $7)} } -- AQUIIIIIIIIIII!!!!!!!!!!!!!!!!!
              | Union begin LISTATAG Nl end                             { UnionType Nothing (reverse $3) } -- AQUIIIIIIIIIII!!!!!!!!!!!!!!!!!

----------------------------------------------------------------------------------------------------

-- Definicion de variables
DEFVARIABLE:  let identifier colon TYPE equal EXPRESION   {% do{ tryInsert $2 $4; return (ModificacionVariable $2 $6)} }
              | let identifier colon TYPE                 {% do{ tryInsert $2 $4; return DeclaracionVariable} }

-- Definiciones inline de registros
BLOCKDEF:     begin LISTASIG end                         { (reverse $2) }

-- Definiciones inline de unions
UNIONBLOCKDEF: TypeName begin end                          { ($1, []) }
               | TypeName begin LISTASIG end               { ($1, (reverse $3)) }

-- Lista de asignaciones de una definicion de bloque inline
LISTASIG:     identifier equal EXPRESION                   { ($1, $3):[] } -- AQUIIIIIIIIIII!!!!!!!!!!!!!!!!!
              | LISTASIG comma identifier equal EXPRESION  { ($3, $5):$1 } -- AQUIIIIIIIIIII!!!!!!!!!!!!!!!!!

-- Modificacion de variables existentes
MODVARIABLE:  identifier equal EXPRESION                   {% do { verificarTabla $1; return (ModificacionVariable $1 $3)} } -- Verificar si las variables existen en tabla
              | ACCESSMEMBER equal EXPRESION               { ModificacionMiembro $1 $3 }

-- Definicion de Tipo
--CAMBIA LA TABLA Y NO LA HEMOS HECHO
DEFDETIPO:    Boy TypeName equal TYPE                      {% do{ tryInsertTipo $2 ; return DeclaracionVariable }}  -- AQUIIIIIIIIIII!!!!!!!!!!!!!!!!! erick entrar en la tabla

--------------------------------------------------------------------------------------------------- -

-- Record
LISTADEF:     LISTADEF Nl DEFVARIABLE                                        { $3:$1 }
              | DEFVARIABLE                                                  { $1:[] }

-- Union
-- CAMBIA LA TABLA Y NO LA HEMOS HECHO
LISTATAG:     {- Vacio -}                                                  { [] }
              | LISTATAG Nl Tag TypeName                                   { ($4, []):$1 }  -- AQUIIIIIIIIIII!!!!!!!!!!!!!!!!!
              | Tag TypeName                                               { ($2, []):[] }  -- AQUIIIIIIIIIII!!!!!!!!!!!!!!!!!
              | LISTATAG Nl Tag TypeName equal NUEVOBLOQUE LISTADEF Nl end {% do {finalizarBloqueU; return $ ($4, (reverse $7)):$1} }  -- AQUIIIIIIIIIII!!!!!!!!!!!!!!!!!
              | Tag TypeName equal NUEVOBLOQUE LISTADEF Nl end             {% do {finalizarBloqueU; return $ ($2, (reverse $5)):[]} }  -- AQUIIIIIIIIIII!!!!!!!!!!!!!!!!!

-- Acceso para contenido de registros
-- VERIFICAR SI ESTAN EN LA TABLA, PERO DONDE?!?!?!?!?!?!?!?!?!?!?!?!?!?!?!
ACCESSMEMBER: identifier point identifier       { $3:$1:[] } -- AQUIIIIIIIIIII!!!!!!!!!!!!!!!!!
              | ACCESSMEMBER point identifier   { $3:$1 } -- AQUIIIIIIIIIII!!!!!!!!!!!!!!!!!
----------------------------------------------------------------------------------------------------

-- Definicion de funciones
-- En el bloque instrucciones hay que chequear no solo con el bloque activo sino con el bloque activo anterior tambien
DEFFUNC:      func identifier open PARAMLIST close colon SIMPLETYPE NUEVOBLOQUE INSTSFUNCP Nl end {% do {finalizarBloqueU; finalizarBloqueU; tryInsertF $2 $7 $4 $9; return $ DeclaracionVariable} } -- Cambia la tabla
              | func identifier open close colon SIMPLETYPE NUEVOBLOQUE INSTSFUNC Nl end         {% do {finalizarBloqueU; tryInsertF $2 $6 [] $8; return $ DeclaracionVariable} } -- Cambia la tabla

-- Tipos simples para devolucion de funciones
SIMPLETYPE:   Int                                                { IntType }
              | Bool                                             { BoolType }
              | Char                                             { CharType }
              | Float                                            { FloatType }
              | Void                                             { VoidType }

-- Uno o mas parametros
PARAMLIST:    identifier colon TYPE                              {% do {nuevoBloque; tryInsert $1 $3 ; return $ (PorValor $1):[]} }
              | PARAMLIST comma identifier colon TYPE            {% do {tryInsert $3 $5 ; return $ (PorValor $3):$1} }
              | dollar identifier colon TYPE                     {% do {nuevoBloque; tryInsert $2 $4 ; return $ (PorReferencia $2):[]} }
              | PARAMLIST comma dollar identifier colon TYPE     {% do {tryInsert $4 $6 ; return $ (PorReferencia $4):$1} }

----------------------------------------------------------------------------------------------------

-- Instrucciones de Funciones
INSTSFUNC:    INSTSFUNC Nl INSTRUCCIONF   { if ($3 /= DeclaracionVariable) then $3:$1 else $1 }
              | INSTRUCCIONF              { (if ($1 /= DeclaracionVariable) then $1:[] else []) }


-- Instruccion de Funcion Individual
INSTRUCCIONF: return                          { InstReturn Nothing }
              | return EXPRESION              { InstReturn (Just $2) }
              | SELECCIONIFF                  { InstIf $1 }
              | SELECCIONMATCHF               { InstMatch $1 }
              | REPETICIONDETF                { InstRepDet $1 }
              | REPETICIONINDETF              { InstRepIndet $1 }
              | DEFVARIABLE                   { $1 }
              | MODVARIABLE                   { $1 }
              | DEFDETIPO                     { $1 }
              | LLAMADA                       { InstLlamada $1 }
              | print open EXPRESION close    { Print $3 }
              | free open identifier close    { Free $3 }

-- Instrucciones de Funciones
INSTSFUNCP:    INSTSFUNCP Nl INSTRUCCIONFP   { if ($3 /= DeclaracionVariable) then $3:$1 else $1 }
              | INSTRUCCIONFP                { (if ($1 /= DeclaracionVariable) then $1:[] else []) }


-- Instruccion de Funcion Individual
INSTRUCCIONFP: return                          { InstReturn Nothing }
              | return EXPRESION              { InstReturn (Just $2) }
              | SELECCIONIFF                  { InstIf $1 }
              | SELECCIONMATCHF               { InstMatch $1 }
              | REPETICIONDETF                { InstRepDet $1 }
              | REPETICIONINDETF              { InstRepIndet $1 }
              | DEFVARIABLEP                  { $1 }
              | MODVARIABLE                   { $1 }
              | DEFDETIPO                     { $1 }
              | LLAMADA                       { InstLlamada $1 }
              | print open EXPRESION close    { Print $3 }
              | free open identifier close    { Free $3 }

DEFVARIABLEP:  let identifier colon TYPE equal EXPRESION   {% do{ tryInsertP $2 $4; return (ModificacionVariable $2 $6)} }
              | let identifier colon TYPE                  {% do{ tryInsertP $2 $4; return DeclaracionVariable} }
----------------------------------------------------------------------------------------------------

-- Selecciones de If
SELECCIONIF:  if EXPRESION NUEVOBLOQUE INSTRUCCIONESC Nl end   %prec then        {% do {finalizarBloqueU; return $ ($2, (reverse $4)):[] } }
              | if EXPRESION NUEVOBLOQUE INSTRUCCIONESC Nl end LISTAELSE         {% do {finalizarBloqueU; return $ ($2, (reverse $4)):(reverse $7) } }

-- Elses de los if
LISTAELSE:    LISTAELSE else EXPRESION NUEVOBLOQUE INSTRUCCIONESC Nl end         {% do {finalizarBloqueU; return $ ($3 , (reverse $5)):$1} }
              | else otherwise NUEVOBLOQUE INSTRUCCIONESC Nl end                 {% do {finalizarBloqueU; return $ [(ExpTrue, (reverse $4))]} }
              | else EXPRESION NUEVOBLOQUE INSTRUCCIONESC Nl end                 {% do {finalizarBloqueU; return $ [($2, (reverse $4))]} }
              | LISTAELSE else otherwise NUEVOBLOQUE INSTRUCCIONESC Nl end       {% do {finalizarBloqueU; return $ (ExpTrue , (reverse $5)):$1} }

-- Especial para Funcion
SELECCIONIFF:  if EXPRESION NUEVOBLOQUE INSTSFUNC Nl end   %prec then           {% do {finalizarBloqueU; return $ ($2, (reverse $4)):[] } }
              | if EXPRESION NUEVOBLOQUE INSTSFUNC Nl end LISTAELSEF            {% do {finalizarBloqueU; return $ ($2, (reverse $4)):(reverse $7) } }

-- Especial para Funcion
LISTAELSEF:    LISTAELSEF else EXPRESION NUEVOBLOQUE INSTSFUNC Nl end           {% do {finalizarBloqueU; return $ ($3 , (reverse $5)):$1} }
              | else otherwise NUEVOBLOQUE INSTSFUNC Nl end                     {% do {finalizarBloqueU; return $ [(ExpTrue, (reverse $4))]} }
              | else EXPRESION NUEVOBLOQUE INSTSFUNC Nl end                     {% do {finalizarBloqueU; return $ [($2, (reverse $4))]} }
              | LISTAELSEF else otherwise NUEVOBLOQUE INSTSFUNC Nl end          {% do {finalizarBloqueU; return $ (ExpTrue , (reverse $5)):$1} }

----------------------------------------------------------------------------------------------------

-- Seleccion match
SELECCIONMATCH: match identifier begin LISTACASOS Nl end                    {% do {verificarTabla $2; return $ Match $2 (reverse $4)} }

-- Especial para Funcion
SELECCIONMATCHF: match identifier begin LISTACASOSF Nl end                  {% do {verificarTabla $2; return $ Match $2 (reverse $4)} }


-- Casos para el match
-- CERRAR BLOQUE ABIERTO EN LAS INSTRUCCIONES
LISTACASOS:   case TypeName NUEVOBLOQUE INSTRUCCIONESC Nl end                      {% do {finalizarBloqueU; return $ Case $2 (reverse $4):[] } }
              | LISTACASOS Nl case TypeName NUEVOBLOQUE INSTRUCCIONESC Nl end      {% do {finalizarBloqueU; return $ (Case $4 (reverse $6)):$1 } }

-- Especial para Funcion
LISTACASOSF:   case TypeName NUEVOBLOQUE INSTSFUNC Nl end                         { Case $2 (reverse $4):[] }
              | LISTACASOSF Nl case TypeName NUEVOBLOQUE INSTSFUNC Nl end         { (Case $4 (reverse $6)):$1 }

----------------------------------------------------------------------------------------------------

-- Repeticion determinada
REPETICIONDET:   for REPDETITER from EXPRESION to EXPRESION NUEVOBLOQUE INSTRUCCIONESC Nl end               {% do {finalizarBloqueU; finalizarBloqueU; return $ RepDet (fst $2) (snd $2) $4 $6 Nothing (reverse $8) } }
                 | for REPDETITER from EXPRESION to EXPRESION by number NUEVOBLOQUE INSTRUCCIONESC Nl end   {% do {finalizarBloqueU; finalizarBloqueU; return $ RepDet (fst $2) (snd $2) $4 $6 (Just $8) (reverse $10) } }
                 | for REPDETITER in EXPRESION NUEVOBLOQUE INSTRUCCIONESC Nl end                            {% do {finalizarBloqueU; finalizarBloqueU; return $ RepDetArray (fst $2) (snd $2) $4 (reverse $6) } }

-- Especial para Funcion
REPETICIONDETF:  for REPDETITER from EXPRESION to EXPRESION NUEVOBLOQUE INSTSFUNC Nl end                   {% do {finalizarBloqueU; finalizarBloqueU; return $ RepDet (fst $2) (snd $2) $4 $6 Nothing (reverse $8) } }
                 | for REPDETITER from EXPRESION to EXPRESION by number NUEVOBLOQUE INSTSFUNC Nl end       {% do {finalizarBloqueU; finalizarBloqueU; return $ RepDet (fst $2) (snd $2) $4 $6 (Just $8) (reverse $10) } }
                 | for REPDETITER in EXPRESION NUEVOBLOQUE INSTSFUNC Nl end                                {% do {finalizarBloqueU; finalizarBloqueU; return $ RepDetArray (fst $2) (snd $2) $4 (reverse $6) } }

REPDETITER: identifier colon TYPE                         {% do { nuevoBloque; tryInsert $1 $3; return ($1,$3)}}
----------------------------------------------------------------------------------------------------

ARRAY:        openSq closeSq                { [] }
              | openSq CONTENIDO closeSq    { reverse $2 }

CONTENIDO:    CONTENIDO comma EXPRESION     { $3:$1 }
              | EXPRESION                   { $1:[] }

----------------------------------------------------------------------------------------------------

-- Repeticion Indeterminada
REPETICIONINDET: while EXPRESION NUEVOBLOQUE INSTRUCCIONESC Nl end {% do {finalizarBloqueU; return $ RepeticionIndet $2 (reverse $4) } }

-- Especial para Funcion
REPETICIONINDETF: while EXPRESION NUEVOBLOQUE INSTSFUNC Nl end    {% do {finalizarBloqueU; return $ RepeticionIndet $2 (reverse $4) } }

----------------------------------------------------------------------------------------------------

INSTRUCCIONESC: INSTRUCCIONESC Nl INSTRUCCIONC    { if ($3 /= DeclaracionVariable) then $3:$1 else $1 }
               | INSTRUCCIONC                     { if ($1 /= DeclaracionVariable) then $1:[] else [] }

-- Instruccion
INSTRUCCIONC: DEFVARIABLE                     { $1 }
              | MODVARIABLE                   { $1 }
              | DEFDETIPO                     { $1 }
              | SELECCIONIF                   { InstIf $1 }
              | SELECCIONMATCH                { InstMatch $1 }
              | REPETICIONDET                 { InstRepDet $1 }
              | REPETICIONINDET               { InstRepIndet $1 }
              | LLAMADA                       { InstLlamada $1 }
              | print open EXPRESION close    { Print $3 }
              | free open identifier close    { Free $3 }

----------------------------------------------------------------------------------------------------

-- Llamadas a funciones
-- Solo falta la parte de modulos aqui, las cuales no van para esta entrega
LLAMADA:      identifier open close                             {% do {verificarExistenciaFuncion $1 0; return $ Llamada $1 [] } }
              | identifier open ARGLIST close                   {% do {verificarExistenciaFuncion $1 (length $3); return $ Llamada $1 (reverse $3) } }
              | TypeName point identifier open close            { LlamadaModulo $1 $3 [] }
              | TypeName point identifier open ARGLIST close    { LlamadaModulo $1 $3 $5 }

-- Argumentos de una llamada a funcion
ARGLIST:      EXPRESION                       { $1:[] }
              | ARGLIST comma EXPRESION       { $3:$1 }

----------------------------------------------------------------------------------------------------
-- Expresiones. Faltan los Arreglos
EXPRESION:    LLAMADA                           { ExpLlamada $1 }
              | identifier                      {% do {verificarTabla $1; return $ ExpVariable $1} }
              | ACCESSMEMBER                    { ExpAcceso (reverse $1) }
              | ARRAY                           { ExpArray $1 }
              | number                          { ExpNumero $1 }
              | character                       { ExpCaracter $1 }
              | True                            { ExpTrue }
              | False                           { ExpFalse }
              | string                          { ExpString $1 }
              | malloc open EXPRESION close     { ExpMalloc $3 }
              | input open close                { ExpInput }
              | BLOCKDEF                        { ExpBlock $1 }
              | UNIONBLOCKDEF                   { ExpUBlock $1 }
              | not EXPRESION %prec not         { ExpNot $2 }
              | EXPRESION or EXPRESION          { ExpOr $1 $3 }
              | EXPRESION and EXPRESION         { ExpAnd $1 $3 }
              -- Comparacion
              | EXPRESION gt EXPRESION          { ExpGreater $1 $3 }
              | EXPRESION lt EXPRESION          { ExpLesser $1 $3 }
              | EXPRESION goet EXPRESION        { ExpGreaterEqual $1 $3 }
              | EXPRESION loet EXPRESION        { ExpLesserEqual $1 $3 }
              | EXPRESION eq EXPRESION          { ExpEqual $1 $3 }
              | EXPRESION uneq EXPRESION        { ExpNotEqual $1 $3 }
              -- Numericas
              | EXPRESION plus EXPRESION        { ExpPlus $1 $3 }
              | EXPRESION minus EXPRESION       { ExpMinus $1 $3 }
              | EXPRESION mult EXPRESION        { ExpProduct $1 $3 }
              | EXPRESION div EXPRESION         { ExpDivision $1 $3 }
              | EXPRESION mod EXPRESION         { ExpMod $1 $3 }
              | EXPRESION wdiv EXPRESION        { ExpWholeDivision $1 $3 }
              | minus EXPRESION %prec uminus    { ExpUminus $2 }
              | open EXPRESION close            { $2 }

{
parseError [] = error "Final Inesperado"
parseError ts = error $ "Token Inesperado: \n" ++ (printToken $ head ts)

testExample str = do
  handle <- openFile ("../Examples/" ++ str) ReadMode
  contents <- hGetContents handle
  ((arbol,tabla),logOcurrencias) <- runWriterT $ runStateT (parserBoy $ alexScanTokens contents) estadoInicial
  putStrLn $ unlines $ logOcurrencias
  putStrLn $ printLBC $ getLBC tabla
  putStrLn $ printPrograma arbol
}
