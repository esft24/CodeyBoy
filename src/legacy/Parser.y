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
}

%name parserBoy
-- %monad { IO }

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
IMPORT:       bring all "the boys" from string                                            { ImportAll $5 [] Nothing }
              | bring all "the boys" from string but open LISTAIDENT close                { ImportAll $5 (reverse $8) Nothing }
              | bring all "the boys" from string aka TypeName                             { ImportAll $5 [] (Just $7) }
              | bring all "the boys" from string but open LISTAIDENT close aka TypeName   { ImportAll $5 (reverse $8) (Just $11) }
              | bring "the boys" from string who open LISTAIDENT close                    { ImportSome $4 (reverse $7) Nothing }
              | bring "the boys" from string who open LISTAIDENT close aka TypeName       { ImportSome $4 (reverse $7) (Just $10) }

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

----------------------------------------------------------------------------------------------------

-- Tipos Validos Posibles
TYPE:         Int                                                       { IntType }
              | Bool                                                    { BoolType }
              | Char                                                    { CharType }
              | Float                                                   { FloatType }
              | Array lt SIMPLETYPE comma number gt                     { ArrayType }
              | String                                                  { StringType }
              | Pointer                                                 { PointerType }
              | TypeName                                                { TypeNameType $1 }
              | Void                                                    { VoidType }
              | Reg begin LISTADEF Nl end                               { RegType (reverse $3) }
              | Union begin LISTADEF Nl with Nl LISTATAG Nl end         { UnionType (Just (reverse $3)) (reverse $7) }
              | Union begin LISTATAG Nl end                             { UnionType Nothing (reverse $3) }

----------------------------------------------------------------------------------------------------

-- Definicion de variables
DEFVARIABLE:  let identifier colon TYPE equal EXPRESION   { ModificacionVariable $2 $6 } -- Cambia la tabla
              | let identifier colon TYPE                 { DeclaracionVariable }

-- Definiciones inline de registros
BLOCKDEF:     begin end                                    { [] }
              | begin LISTASIG end                         { (reverse $2) }

-- Definiciones inline de unions
UNIONBLOCKDEF: TypeName begin end                           { ($1, []) }
               | TypeName begin LISTASIG end                { ($1, (reverse $3)) }

-- Lista de asignaciones de una definicion de bloque inline
LISTASIG:     identifier equal EXPRESION                   { ($1, $3):[] }
              | LISTASIG comma identifier equal EXPRESION  { ($3, $5):$1 }

-- Modificacion de variables existentes
MODVARIABLE:  identifier equal EXPRESION                   { ModificacionVariable $1 $3 }
              | ACCESSMEMBER equal EXPRESION               { ModificacionMiembro  $1 $3 }

-- Definicion de Tipo
DEFDETIPO:    Boy TypeName equal TYPE                      { DeclaracionVariable }  -- Cambia la tabla

--------------------------------------------------------------------------------------------------- -

-- Record
LISTADEF:     LISTADEF Nl DEFVARIABLE                                        { $3:$1 }
              | DEFVARIABLE                                                  { $1:[] }

-- Union
LISTATAG:     {- Vacio -}                                             { [] }
              | LISTATAG Nl Tag TypeName                              { ($4, []):$1 }  -- Cambia la tabla
              | Tag TypeName                                          { ($2, []):[] }  -- Cambia la tabla
              | LISTATAG Nl Tag TypeName equal begin LISTADEF Nl end  { ($4, (reverse $7)):$1 }  -- Cambia la tabla
              | Tag TypeName equal begin LISTADEF Nl end              { ($2, (reverse $5)):[] }  -- Cambia la tabla

----------------------------------------------------------------------------------------------------

-- Definicion de funciones
DEFFUNC:      func identifier open PARAMLIST close colon SIMPLETYPE begin INSTSFUNC Nl end { <- Cambia la tabla
              | func identifier open close colon SIMPLETYPE begin INSTSFUNC Nl end         { <a tabla

-- Tipos simples para devolucion de funciones
SIMPLETYPE:   Int                                               { IntType }  -- Cambia la tabla
              | Bool                                            { BoolType }  -- Cambia la tabla
              | Char                                            { CharType }  -- Cambia la tabla
              | Float                                           { FloatType }  -- Cambia la tabla
              | Void                                            { VoidType }  -- Cambia la tabla

-- Uno o mas parametros
PARAMLIST:    identifier colon TYPE                             { (PorValor $1, $3):[] }  -- Cambia la tabla
              | PARAMLIST comma identifier colon TYPE           { (PorValor $3, $5):$1 }  -- Cambia la tabla
              | dollar identifier colon TYPE                    { (PorReferencia $2, $4):[] }  -- Cambia la tabla
              | PARAMLIST comma dollar identifier colon TYPE    { (PorReferencia $4, $6):$1 }  -- Cambia la tabla

----------------------------------------------------------------------------------------------------

-- Instrucciones de Funciones
INSTSFUNC:    INSTSFUNC Nl INSTRUCCIONF   { if ($3 /= DeclaracionVariable) then $3:$1 else $1 }
              | INSTRUCCIONF              { if ($1 /= DeclaracionVariable) then $1:[] else [] }


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

----------------------------------------------------------------------------------------------------

-- Selecciones de If
SELECCIONIF:  if EXPRESION begin INSTRUCCIONES Nl end   %prec then        { ($2, (reverse $4)):[] }
              | if EXPRESION begin INSTRUCCIONES Nl end LISTAELSE         { ($2, (reverse $4)):(reverse $7) }

-- Elses de los if
LISTAELSE:    LISTAELSE else EXPRESION begin INSTRUCCIONES Nl end         { ($3 , (reverse $5)):$1 }
              | else otherwise begin INSTRUCCIONES Nl end                 { (ExpTrue, (reverse $4)):[] }
              | else EXPRESION begin INSTRUCCIONES Nl end                 { ($2, (reverse $4)):[] }
              | LISTAELSE else otherwise begin INSTRUCCIONES Nl end       { (ExpTrue , (reverse $5)):$1 }

-- Especial para Funcion
SELECCIONIFF:  if EXPRESION begin INSTSFUNC Nl end   %prec then           { ($2, (reverse $4)):[] }
              | if EXPRESION begin INSTSFUNC Nl end LISTAELSEF            { ($2, (reverse $4)):(reverse $7) }

-- Especial para Funcion
LISTAELSEF:    LISTAELSEF else EXPRESION begin INSTSFUNC Nl end           { ($3 , (reverse $5)):$1 }
              | else otherwise begin INSTSFUNC Nl end                     { (ExpTrue, (reverse $4)):[] }
              | else EXPRESION begin INSTSFUNC Nl end                     { ($2, (reverse $4)):[] }
              | LISTAELSEF else otherwise begin INSTSFUNC Nl end          { (ExpTrue , (reverse $5)):$1 }

----------------------------------------------------------------------------------------------------

-- Seleccion match
SELECCIONMATCH: match identifier begin LISTACASOS Nl end               { Match $2 (reverse $4) }

-- Especial para Funcion
SELECCIONMATCHF: match identifier begin LISTACASOSF Nl end             { Match $2 (reverse $4) }


-- Casos para el match
LISTACASOS:   case TypeName begin INSTRUCCIONES Nl end                 { (Case $2 (reverse $4)):[] }
              | LISTACASOS Nl case TypeName begin INSTRUCCIONES Nl end { (Case $4 (reverse $6)):$1 }

-- Especial para Funcion
LISTACASOSF:   case TypeName begin INSTSFUNC Nl end                    { (Case $2 (reverse $4)):[] }
              | LISTACASOSF Nl case TypeName begin INSTSFUNC Nl end    { (Case $4 (reverse $6)):$1 }

----------------------------------------------------------------------------------------------------

-- Repeticion determinada
REPETICIONDET:   for identifier colon TYPE from character to character begin INSTRUCCIONES Nl end        { RepDet $2 $4 $6 $8 Nothing (reverse $10) }  -- Cambia la tabla
                 | for identifier colon TYPE from number to number begin INSTRUCCIONES Nl end            { RepDet $2 $4 $6 $8 Nothing (reverse $10) }  -- Cambia la tabla
                 | for identifier colon TYPE from number to number by number begin INSTRUCCIONES Nl end  { RepDet $2 $4 $6 $8 (Just $10) (reverse $12) }  -- Cambia la tabla
                 | for identifier colon TYPE in identifier begin INSTRUCCIONES Nl end                    { RepDetArray $2 $4 $6 (reverse $8) }  -- Cambia la tabla
                 | for identifier colon TYPE in ARRAY begin INSTRUCCIONES Nl end                         { RepDetArrayExplicit $2 $4 $6 (reverse $8) }  -- Cambia la tabla

-- Especial para Funcion
REPETICIONDETF:  for identifier colon TYPE from character to character begin INSTSFUNC Nl end            { RepDet $2 $4 $6 $8 Nothing (reverse $10) }  -- Cambia la tabla
                 | for identifier colon TYPE from number to number begin INSTSFUNC Nl end                { RepDet $2 $4 $6 $8 Nothing (reverse $10) }  -- Cambia la tabla
                 | for identifier colon TYPE from number to number by number begin INSTSFUNC Nl end      { RepDet $2 $4 $6 $8 (Just $10) (reverse $12) }  -- Cambia la tabla
                 | for identifier colon TYPE in identifier begin INSTSFUNC Nl end                        { RepDetArray $2 $4 $6 (reverse $8) }  -- Cambia la tabla
                 | for identifier colon TYPE in ARRAY begin INSTSFUNC Nl end                             { RepDetArrayExplicit $2 $4 $6 (reverse $8) }  -- Cambia la tabla

----------------------------------------------------------------------------------------------------

ARRAY:        openSq {-Vacio-} closeSq      { [] }
              | openSq CONTENIDO closeSq    { reverse $2 }

CONTENIDO:    CONTENIDO comma EXPRESION     { $3:$1 }
              | EXPRESION                   { $1:[] }

----------------------------------------------------------------------------------------------------

-- Repeticion Indeterminada
REPETICIONINDET: while EXPRESION begin INSTRUCCIONES Nl end { RepeticionIndet $2 (reverse $4) }

-- Especial para Funcion
REPETICIONINDETF: while EXPRESION begin INSTSFUNC Nl end    { RepeticionIndet $2 (reverse $4) }

----------------------------------------------------------------------------------------------------

-- Llamadas a funciones
LLAMADA:      identifier open close                           { Llamada $1 [] }
              | identifier open ARGLIST close                 { Llamada $1 (reverse $3) }
              | TypeName point identifier open close          { LlamadaModulo $1 $3 [] }
              | TypeName point identifier open ARGLIST close  { LlamadaModulo $1 $3 $5 }

-- Argumentos de una llamada a funcion
ARGLIST:      EXPRESION                       { $1:[] }
              | ARGLIST comma EXPRESION       { $3:$1 }

----------------------------------------------------------------------------------------------------
-- Expresiones. Faltan los Arreglos
EXPRESION:    LLAMADA                           { ExpLlamada $1 }
              | identifier                      { ExpVariable $1 }
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

-- Acceso para contenido de registros
ACCESSMEMBER: identifier point identifier       { $3:$1:[] }
              | ACCESSMEMBER point identifier   { $3:$1 }

{
parseError [] = error "Final Inesperado"
parseError ts = error $ "Token Inesperado: \n" ++ (printToken $ head ts)
}
