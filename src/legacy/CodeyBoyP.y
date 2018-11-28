-- Parser de CodeyBoy
-- Integrantes:
--              Erick Flejan    12-11555
--              Carlos Perez    13-11089

-- CI-4721 Lenguajes de Programacion II

{
module CodeyBoyP where
import Lexer
import Tokens
import System.IO
import System.Environment
}

%name parserBoy
%monad { IO }

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
    fi                { TKFi _ }
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
    else              { TKElse _ }
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

%%

-- Inicio
START: Nl PROGRAMA         {%putStrLn "START -> PROGRAMA"} 
       | PROGRAMA          {%putStrLn "START -> PROGRAMA"} 
       

PROGRAMA:     IMPORTS Nl INSTRUCCIONES { %putStrLn "PROGRAMA -> IMPORTS INSTRUCCIONES" }
              | INSTRUCCIONES          { %putStrLn "PROGRAMA -> INSTRUCCIONES" }
              | IMPORTS                { %putStrLn "PROGRAMA -> IMPORTS" }

------------------------------------------------------------------------------------------------------------------------

-- Lista de Imports
IMPORTS:      IMPORTS Nl IMPORT                                                          { %putStrLn "IMPORTS -> IMPORTS IMPORT" }
              | IMPORT                                                                   { %putStrLn "IMPORTS -> IMPORT" }

-- Importacion de un modulo Quiza haya que restar 1
IMPORT:       bring all "the boys" from string                                            { %putStrLn "IMPORT -> bring all the boys from string" }
              | bring all "the boys" from string but open LISTAIDENT close                { %putStrLn "IMPORT -> bring all the boys from string but (LISTAIDENT)" }
              | bring all "the boys" from string aka TypeName                             { %putStrLn "IMPORT -> bring all the boys from string aka TypeName" }
              | bring all "the boys" from string but open LISTAIDENT close aka TypeName   { %putStrLn "IMPORT -> bring all the boys from string but (LISTAIDENT) aka TypeName" }
              | bring "the boys" from string who open LISTAIDENT close                    { %putStrLn "IMPORT -> bring all the boys from string who (LISTAIDENT)" }
              | bring "the boys" from string who open LISTAIDENT close aka TypeName       { %putStrLn "IMPORT -> bring all the boys from string who (LISTAIDENT) aka TypeName" }

-- Serie de identificadores seleccionados de un modulo
LISTAIDENT:   identifier                                                                 { %putStrLn "LISTAIDENT -> identifier" }
              | LISTAIDENT comma identifier                                              { %putStrLn "LISTAIDENT -> LISTAIDENT , identifier" }

----------------------------------------------------------------------------------------------------

-- Instrucciones
INSTRUCCIONES: INSTRUCCIONES Nl INSTRUCCION    { %putStrLn "INSTRUCCIONES -> INSTRUCCIONES INSTRUCCION"  }
               | INSTRUCCION                   { %putStrLn "INSTRUCCIONES -> INSTRUCCION" }

-- Instruccion
INSTRUCCION:    DEFVARIABLE                   { %putStrLn "INSTRUCCION -> DEFVARIABLE" }
              | MODVARIABLE                   { %putStrLn "INSTRUCCION -> MODVARIABLE" }
              | DEFDETIPO                     { %putStrLn "INSTRUCCION -> DEFDETIPO" }
              | DEFFUNC                       { %putStrLn "INSTRUCCION -> DEFFUNC" }
              | SELECCIONIF                   { %putStrLn "INSTRUCCION -> SELECCIONIF" }
              | SELECCIONMATCH                { %putStrLn "INSTRUCCION -> SELECCIONMATCH" }
              | REPETICIONDET                 { %putStrLn "INSTRUCCION -> REPETICIONDET" }
              | REPETICIONINDET               { %putStrLn "INSTRUCCION -> REPETICIONINDET" }
              | LLAMADA                       { %putStrLn "INSTRUCCION -> LLAMADA" }
              | print open EXPRESION close    { %putStrLn "INSTRUCCION -> print {EXPRESION} " }
              | free open identifier close    { %putStrLn "INSTRUCCION -> free  {identifier} " }

----------------------------------------------------------------------------------------------------

-- Tipos Validos Posibles
TYPE:         Int                                                       { %putStrLn "TYPE -> Int" }
              | Bool                                                    { %putStrLn "TYPE -> Bool" }
              | Char                                                    { %putStrLn "TYPE -> Char" }
              | Float                                                   { %putStrLn "TYPE -> Float" }
              | Array                                                   { %putStrLn "TYPE -> Array" }
              | String                                                  { %putStrLn "TYPE -> String" }
              | Pointer                                                 { %putStrLn "TYPE -> Pointer" }
              | TypeName                                                { %putStrLn "TYPE -> TypeName" }
              | Void                                                    { %putStrLn "TYPE -> Void" }
              | Reg begin LISTADEF Nl end                               { %putStrLn "TYPE -> Reg {LISTADEF} end" }
              | Union begin LISTADEF Nl with Nl LISTATAG Nl end         { %putStrLn "TYPE -> Union {LISTADEF with LISTATAG}" }
              | Union begin LISTATAG Nl end                             { %putStrLn "TYPE -> Union {LISTATAG}" }

----------------------------------------------------------------------------------------------------

-- Definicion de variables
DEFVARIABLE:    let identifier colon TYPE ACTUALDEF        { %putStrLn "DEFVARIABLE -> let identifier colon TYPE ACTUALDEF" }

-- Definicion real
ACTUALDEF:    {- Vacio -}                                  { %putStrLn "ACTUALDEF -> |" }
              | equal EXPRESION                            { %putStrLn "ACTUALDEF -> = EXPRESION" }                          

-- Definiciones inline de registros
BLOCKDEF:     begin end                                    { %putStrLn "BLOCKDEF -> {}" }
              | begin LISTASIG end                         { %putStrLn "BLOCKDEF -> {LISTASIG}" }

-- Definiciones inline de unions
UNIONBLOCKDEF: TypeName begin end                           { %putStrLn "UNIONBLOCKDEF -> TypeName {}" }
               | TypeName begin LISTASIG end                { %putStrLn "UNIONBLOCKDEF -> TypeName {LISTASIG}" }

-- Lista de asignaciones de una definicion de bloque inline
LISTASIG:     identifier equal EXPRESION                   { %putStrLn "LISTASIG -> identifier = EXPRESION" }
              | LISTASIG comma identifier equal EXPRESION  { %putStrLn "LISTASIG -> LISTASIG , identifier = EXPRESION" }

-- Modificacion de variables existentes
MODVARIABLE:  identifier equal EXPRESION                   { %putStrLn "MODVARIABLE -> identifier = EXPRESION" }
              | ACCESSMEMBER equal EXPRESION               { %putStrLn "MODVARIABLE -> ACCESSMEMBER = EXPRESION" }

-- Definicion de Tipo
DEFDETIPO:    Boy TypeName equal TYPE                      { %putStrLn "DEFDETIPO -> Boy TypeName = TYPE" }

--------------------------------------------------------------------------------------------------- -

-- Record
LISTADEF:     LISTADEF Nl DEFVARIABLE                                        { %putStrLn "LISTADEF -> LISTADEF DEFVARIABLE" }
              | DEFVARIABLE                                                  { %putStrLn "LISTADEF -> DEFVARIABLE" }

-- Union
LISTATAG:     {- Vacio -}                                                    { %putStrLn "LISTATAG -> |" }
              | LISTATAG Nl Tag TypeName                                     { %putStrLn "LISTATAG -> LISTATAG Tag TypeName" } 
              | Tag TypeName                                                 { %putStrLn "LISTATAG -> Tag TypeName" }
              | LISTATAG Nl Tag TypeName equal begin LISTADEF Nl end         { %putStrLn "LISTATAG -> LISTATAG Tag TypeName = {LISTADEF}" }
              | Tag TypeName equal begin LISTADEF Nl end                     { %putStrLn "LISTATAG -> Tag TypeName = {LISTADEF}" }

----------------------------------------------------------------------------------------------------

-- Definicion de funciones
DEFFUNC:      func identifier open PARAMLIST close colon SIMPLETYPE begin INSTSFUNC Nl end { %putStrLn "DEFFUNC -> func identifier(PARAMLIST): SIMPLETYPE {INSTSFUNC}" }
              | func identifier open close colon SIMPLETYPE begin INSTSFUNC Nl end         { %putStrLn "DEFFUNC -> func identifier(): SIMPLETYPE {INSTSFUNC}" }

-- Tipos simples para devolucion de funciones
SIMPLETYPE:   Int                                                                                 { %putStrLn "SIMPLETYPE -> Int" }
              | Bool                                                                              { %putStrLn "SIMPLETYPE -> Bool" }
              | Char                                                                              { %putStrLn "SIMPLETYPE -> Char" }
              | Float                                                                             { %putStrLn "SIMPLETYPE -> Float" }
              | Void                                                                              { %putStrLn "SIMPLETYPE -> Void" }

-- Uno o mas parametros
PARAMLIST:    identifier colon TYPE                                                               { %putStrLn "PARAMLIST -> identifier: TYPE" }
              | PARAMLIST comma identifier colon TYPE                                             { %putStrLn "PARAMLIST -> PARAMLIST, identifier: TYPE" }
              | dollar identifier colon TYPE                                                      { %putStrLn "PARAMLIST -> $identifier: TYPE" }
              | PARAMLIST comma dollar identifier colon TYPE                                      { %putStrLn "PARAMLIST -> PARAMLIST, $identifier: TYPE" }  

----------------------------------------------------------------------------------------------------

-- Instrucciones de Funciones
INSTSFUNC:    INSTSFUNC Nl INSTRUCCIONF   { %putStrLn "INSTSFUNC -> INSTSFUNC INSTRUCCIONF" }
              | INSTRUCCIONF              { %putStrLn "INSTSFUNC -> INSTRUCCIONF" }


-- Instruccion de Funcion Individual
INSTRUCCIONF: return                          { %putStrLn "INSTRUCCIONF -> return" }
              | return EXPRESION              { %putStrLn "INSTRUCCIONF -> return EXPRESION" }
              | SELECCIONIFF                  { %putStrLn "INSTRUCCIONF -> SELECCIONIFF" }
              | SELECCIONMATCHF               { %putStrLn "INSTRUCCIONF -> SELECCIONMATCHF" }
              | REPETICIONDETF                { %putStrLn "INSTRUCCIONF -> REPETICIONDETF" }
              | REPETICIONINDETF              { %putStrLn "INSTRUCCIONF -> REPETICIONINDETF" }
              | DEFVARIABLE                   { %putStrLn "INSTRUCCIONF -> DEFVARIABLE" }
              | MODVARIABLE                   { %putStrLn "INSTRUCCIONF -> MODVARIABLE" }
              | DEFDETIPO                     { %putStrLn "INSTRUCCIONF -> DEFDETIPO" }
              | LLAMADA                       { %putStrLn "INSTRUCCIONF -> LLAMADA" }
              | print open EXPRESION close    { %putStrLn "INSTRUCCIONF -> print (EXPRESION)" }
              | free open identifier close    { %putStrLn "INSTRUCCIONF -> free (identifier)" }

----------------------------------------------------------------------------------------------------

-- Selecciones de If
SELECCIONIF:  if EXPRESION begin INSTRUCCIONES Nl end Nl fi                  { %putStrLn "SELECCIONIF -> if EXPRESION {INSTRUCCIONES} end fi" }
              | if EXPRESION begin INSTRUCCIONES Nl end Nl LISTAELSE Nl fi   { %putStrLn "SELECCIONIF -> if EXPRESION {INSTRUCCIONES} end LISTAELSE fi" }

-- Elses de los if
LISTAELSE:    LISTAELSE Nl else EXPRESION begin INSTRUCCIONES Nl end      { %putStrLn "LISTAELSE -> LISTAELSE | EXPRESION {INSTRUCCIONES}" }
              | LISTAELSE Nl else otherwise begin INSTRUCCIONES Nl end    { %putStrLn "LISTAELSE -> LISTAELSE | _ {INSTRUCCIONES}" }
              | else EXPRESION begin INSTRUCCIONES Nl end                 { %putStrLn "LISTAELSE -> | EXPRESION {INSTRUCCIONES}" }
              | else otherwise begin INSTRUCCIONES Nl end                 { %putStrLn "LISTAELSE -> | _ {INSTRUCCIONES}" }

-- Especial para Funcion
SELECCIONIFF:  if EXPRESION begin INSTSFUNC Nl end Nl fi                     { %putStrLn "SELECCIONIFF -> if EXPRESION {INSTSFUNC} end fi" }
              | if EXPRESION begin INSTSFUNC Nl end Nl LISTAELSEF Nl fi      { %putStrLn "SELECCIONIFF -> if EXPRESION {INSTSFUNC} end LISTAELSEF fi" }

-- Especial para Funcion
LISTAELSEF:    LISTAELSEF Nl else EXPRESION begin INSTSFUNC Nl end        { %putStrLn "LISTAELSEF -> LISTAELSEF | EXPRESION {INSTSFUNC}" }
              | else otherwise begin INSTSFUNC Nl end                     { %putStrLn "LISTAELSEF -> | _ {INSTSFUNC}" }
              | else EXPRESION begin INSTSFUNC Nl end                     { %putStrLn "LISTAELSEF -> | EXPRESION {INSTSFUNC}" }
              | LISTAELSEF Nl else otherwise begin INSTSFUNC Nl end       { %putStrLn "LISTAELSEF -> LISTAELSEF | _ {INSTSFUNC}" }

----------------------------------------------------------------------------------------------------

-- Seleccion match
SELECCIONMATCH: match identifier begin LISTACASOS Nl end               { %putStrLn "SELECCIONMATCH -> match identifier {LISTACASOS}" }

-- Especial para Funcion
SELECCIONMATCHF: match identifier begin LISTACASOSF Nl end             { %putStrLn "SELECCIONMATCHF -> match identifier {LISTACASOSF}" }


-- Casos para el match
LISTACASOS:   case TypeName begin INSTRUCCIONES Nl end                 { %putStrLn "LISTACASOS -> case TypeName {INSTRUCCIONES} end" }
              | LISTACASOS Nl case TypeName begin INSTRUCCIONES Nl end { %putStrLn "LISTACASOS -> LISTACASOS case TypeName {INSTRUCCIONES} end" }

-- Especial para Funcion
LISTACASOSF:   case TypeName begin INSTSFUNC Nl end                    { %putStrLn "LISTACASOSF -> case TypeName {INSTSFUNC}" }
              | LISTACASOSF Nl case TypeName begin INSTSFUNC Nl end    { %putStrLn "LISTACASOSF -> LISTACASOSF case TypeName {INSTSFUNC}" }

----------------------------------------------------------------------------------------------------
-- Repeticion determinada
REPETICIONDET:   for identifier colon TYPE from character to character begin INSTRUCCIONES Nl end        { %putStrLn "REPETICIONDET -> for identifier:TYPE from character to character {INSTRUCCIONES}" }
                 | for identifier colon TYPE from number to number begin INSTRUCCIONES Nl end            { %putStrLn "REPETICIONDET -> for identifier:TYPE from number to number {INSTRUCCIONES}" }
                 | for identifier colon TYPE from number to number by number begin INSTRUCCIONES Nl end  { %putStrLn "REPETICIONDET -> for identifier:TYPE from number to number by number {INSTRUCCIONES}" }
                 | for identifier colon TYPE in identifier begin INSTRUCCIONES Nl end                    { %putStrLn "REPETICIONDET -> for identifier:TYPE in identifier {INSTRUCCIONES}" }
                 | for identifier colon TYPE in ARRAY begin INSTRUCCIONES Nl end                         { %putStrLn "REPETICIONDET -> for identifier:TYPE in ARRAY {INSTRUCCIONES}" }

-- Especial para Funcion
REPETICIONDETF:  for identifier colon TYPE from character to character begin INSTSFUNC Nl end            { %putStrLn "REPETICIONDETF -> for identifier:TYPE from character to character {INSTSFUNC}" }
                 | for identifier colon TYPE from number to number begin INSTSFUNC Nl end                { %putStrLn "REPETICIONDETF -> for identifier:TYPE from number to number {INSTSFUNC}" }
                 | for identifier colon TYPE from number to number by number begin INSTSFUNC Nl end      { %putStrLn "REPETICIONDETF -> for identifier:TYPE from number to number by number {INSTSFUNC}" }
                 | for identifier colon TYPE in identifier begin INSTSFUNC Nl end                        { %putStrLn "REPETICIONDETF -> for identifier:TYPE in identifier {INSTSFUNC}" }
                 | for identifier colon TYPE in ARRAY begin INSTSFUNC Nl end                             { %putStrLn "REPETICIONDETF -> for identifier:TYPE in ARRAY {INSTSFUNC}" }

----------------------------------------------------------------------------------------------------

ARRAY:        openSq {-Vacio-} closeSq   { %putStrLn "ARRAY -> [] " }
              | openSq CONTENIDO closeSq { %putStrLn "ARRAY -> [CONTENIDO] " }

CONTENIDO:    CONTENIDO comma number     { %putStrLn "CONTENIDO -> CONTENIDO , number" }
              | number                   { %putStrLn "CONTENIDO -> number" }

----------------------------------------------------------------------------------------------------

-- Repeticion Indeterminada
REPETICIONINDET: while EXPRESION begin INSTRUCCIONES Nl end { %putStrLn "REPETICIONINDET -> while EXPRESION {INSTRUCCIONES}" }

-- Especial para Funcion
REPETICIONINDETF: while EXPRESION begin INSTSFUNC Nl end    { %putStrLn "REPETICIONINDETF -> while EXPRESION {INSTSFUNC}" }

----------------------------------------------------------------------------------------------------

-- Llamadas a funciones
LLAMADA:      identifier open close           { %putStrLn "LLAMADA -> identifier()" }
              | identifier open ARGLIST close { %putStrLn "LLAMADA -> identifier(ARGLIST)" }
              | TypeName point identifier open close { %putStrLn "LLAMADA -> TypeName.identifier()" }
              | TypeName point identifier open ARGLIST close { %putStrLn "LLAMADA -> TypeName.identifier(ARGLIST)" }

-- Argumentos de una llamada a funcion
ARGLIST:      EXPRESION                       { %putStrLn "ARGLIST comma EXPRESION -> EXPRESION" }
              | ARGLIST comma EXPRESION       { %putStrLn "ARGLIST comma EXPRESION -> ARGLIST, EXPRESION" }

----------------------------------------------------------------------------------------------------
-- Expresiones. Faltan los Arreglos
EXPRESION:    LLAMADA                           { %putStrLn "EXPRESION -> LLAMADA" }
              | identifier                      { %putStrLn "EXPRESION -> identifier" }
              | ACCESSMEMBER                    { %putStrLn "EXPRESION -> ACCESSMEMBER" }
              | ARRAY                           { %putStrLn "EXPRESION -> ARRAY" }
              | number                          { %putStrLn "EXPRESION -> number" }
              | character                       { %putStrLn "EXPRESION -> character" }
              | True                            { %putStrLn "EXPRESION -> True" }
              | False                           { %putStrLn "EXPRESION -> False" }
              | string                          { %putStrLn "EXPRESION -> string" }
              | malloc open EXPRESION close     { %putStrLn "EXPRESION -> malloc(EXPRESION)" }
              | input open close                { %putStrLn "EXPRESION -> input()" }
              | BLOCKDEF                        { %putStrLn "EXPRESION -> BLOCKDEF" }
              | UNIONBLOCKDEF                   { %putStrLn "EXPRESION -> UNIONBLOCKDEF" }
              | not EXPRESION %prec not         { %putStrLn "EXPRESION -> !EXPRESION" }
              | EXPRESION or EXPRESION          { %putStrLn "EXPRESION -> EXPRESION || EXPRESION" }
              | EXPRESION and EXPRESION         { %putStrLn "EXPRESION -> EXPRESION && EXPRESION" }
              -- Comparacion
              | EXPRESION gt EXPRESION          { %putStrLn "EXPRESION -> EXPRESION > EXPRESION" }
              | EXPRESION lt EXPRESION          { %putStrLn "EXPRESION -> EXPRESION < EXPRESION" }
              | EXPRESION goet EXPRESION        { %putStrLn "EXPRESION -> EXPRESION >= EXPRESION" }
              | EXPRESION loet EXPRESION        { %putStrLn "EXPRESION -> EXPRESION <= EXPRESION" }
              | EXPRESION eq EXPRESION          { %putStrLn "EXPRESION -> EXPRESION == EXPRESION" }
              | EXPRESION uneq EXPRESION        { %putStrLn "EXPRESION -> EXPRESION /= EXPRESION " }
              -- Numericas
              | EXPRESION plus EXPRESION        { %putStrLn "EXPRESION -> EXPRESION + EXPRESION " }
              | EXPRESION minus EXPRESION       { %putStrLn "EXPRESION -> EXPRESION - EXPRESION" }
              | EXPRESION mult EXPRESION        { %putStrLn "EXPRESION -> EXPRESION * EXPRESION" }
              | EXPRESION div EXPRESION         { %putStrLn "EXPRESION -> EXPRESION / EXPRESION" }
              | EXPRESION mod EXPRESION         { %putStrLn "EXPRESION -> EXPRESION % EXPRESION" }
              | EXPRESION wdiv EXPRESION        { %putStrLn "EXPRESION -> EXPRESION // EXPRESION" }
              | minus EXPRESION %prec uminus    { %putStrLn "EXPRESION -> -EXPRESION" }
              | open EXPRESION close            { %putStrLn "EXPRESION -> (EXPRESION)" }

-- Acceso para contenido de registros
ACCESSMEMBER: identifier point identifier       { %putStrLn "ACCESSMEMBER -> identifier.identifier" }
              | ACCESSMEMBER point identifier   { %putStrLn "ACCESSMEMBER -> ACCESSMEMBER.identifier" }
{
parseError [] = error "Final Inesperado"
parseError ts = error $ "Token Inesperado: \n" ++ (printToken $ head ts)
}