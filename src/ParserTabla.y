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
import qualified Data.Set as S
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
    break             { TKBreak _ }
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
    bring             { TKBring _ }
    "the boys"        { TKTheBoys _ }
    all               { TKAll _ }
    who               { TKWho _ }
    aka               { TKAka _ }
    but               { TKBut _ }

    Tag               { TKTag _ }
    case              { TKCase _ }
    match             { TKMatch _ }
    default           { TKDefault _ }

    --Funciones polimorficas
    print             { TKPrint _ }
    input             { TKInput _ }
    malloc            { TKMalloc _ }
    free              { TKFree _ }
    stringify         { TKStringify _ }

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
%right uminus deref
%left point

%nonassoc then
%nonassoc else

%%

-- Inicio del programa
START: {- Vacio -}           { Programa [] []}
       | Nl PROGRAMA         { % do { chequeoLlamadas; return $2} }
       | PROGRAMA            { % do { chequeoLlamadas; return $1} }


PROGRAMA:     IMPORTS Nl INSTRUCCIONES { Programa $1 $3 }
              | INSTRUCCIONES          { Programa [] $1 }
              | IMPORTS                { Programa $1 [] }

------------------------------------------------------------------------------------------------------------------------

-- Lista de Imports
IMPORTS:      IMPORTS Nl IMPORT                                                          { $3:$1 }
              | IMPORT                                                                   { $1:[] }

-- Importacion de un Modulo
IMPORT:       bring all "the boys" from string                                           { ImportAll $5 [] Nothing }
              | bring all "the boys" from string but open LISTAIDENT close               { ImportAll $5 $8 Nothing }
              | bring all "the boys" from string aka TypeName                            { ImportAll $5 [] (Just $7) }
              | bring all "the boys" from string but open LISTAIDENT close aka TypeName  { ImportAll $5 $8 (Just $11) }
              | bring "the boys" from string who open LISTAIDENT close                   { ImportSome $4 $7 Nothing }
              | bring "the boys" from string who open LISTAIDENT close aka TypeName      { ImportSome $4 $7 (Just $10) }

-- Serie de identificadores seleccionados de un modulo
LISTAIDENT:   identifier                                                                 { $1:[] }
              | LISTAIDENT comma identifier                                              { $3:$1 }

----------------------------------------------------------------------------------------------------

-- Instrucciones
INSTRUCCIONES: INSTRUCCIONES Nl INSTRUCCION    { case $3 of {DeclaracionVariable _ -> $1; _ -> $3:$1} }
               | INSTRUCCION                   { case $1 of {DeclaracionVariable _ -> []; _ -> $1:[]} }

-- Instruccion
INSTRUCCION:    DEFVARIABLE                   { $1 }
              | MODVARIABLE                   { $1 }
              | DEFDETIPO                     { $1 }
              | DEFFUNC                       { $1 }
              | SELECCIONIF                   { InstIf $1 }
              | SELECCIONMATCH                { InstMatch $1 }
              | REPETICIONDET                 { InstRepDet $1 }
              | REPETICIONINDET               { InstRepIndet $1 }
              | LLAMADA                       {% do{_ <- typeLlamadaMonadic (getTokenL $1) (map getTipoEx (getParametros $1)); return $ InstLlamada $1 }}
              | print open EXPRESION close    {% do{checkPrintFree (tknPos $1) (getTipoEx $3) StringType; return $ Print $3} }
              | free open EXPRESION close     {% do{checkPrintFree (tknPos $1) (getTipoEx $3) (PointerType (NullType [])); return $ Free $3} }

-- Nuevo Bloque de Instrucciones
NUEVOBLOQUE: begin                            {% nuevoBloque }

-- Nuevo Bloque Para Registros
NUEVOBLOQUER: begin                           {% do{insertOffsetReg; nuevoBloque} }
----------------------------------------------------------------------------------------------------

TYPE: Int                                                       { IntType }
      | Bool                                                    { BoolType }
      | Char                                                    { CharType }
      | Float                                                   { FloatType }
      | String                                                  { StringType }
      | TypeName                                                {% do{obtenerTipoTypeName (tknString $1)} }
      | Void                                                    { VoidType }
      | Reg NUEVOBLOQUER LISTADEF Nl end                        {% do {popOffset; finalizarBloqueU; return $ RegType $ S.fromList $3} }
      | Union NUEVOBLOQUE LISTADEF Nl with Nl LISTATAG Nl end   {% do {finalizarBloqueU; return $ UnionType (S.fromList $3) (S.fromList $7)} }
      | Union begin LISTATAG Nl end                             { UnionType S.empty (S.fromList $3) }
              
-- Tipos Validos Posibles
PARAMTYPE:    Pointer TYPE                                              { PointerType $2 }
              | Pointer PARAMTYPE                                       { PointerType $2 }
              | Array lt PARAMTYPE gt                                   { ArrayType $3 (ExpNumero $2 IntType) }


DEFTYPE:      Pointer TYPE                                              { PointerType $2 }
              | Pointer DEFTYPE                                         { PointerType $2 }
              | Array lt TYPE gt open EXPRESION close                   {%do {checkArrayLength (tknPos $4) (getTipoEx $6); return $ ArrayType $3 $6} }

----------------------------------------------------------------------------------------------------

-- Definicion de variables
DEFVARIABLE:  let identifier colon TYPE equal EXPRESION          {% do{ (offset, alcance) <- tryInsert $2 $4; verificarTipoDef $2 $4 (getTipoEx $6); return $ ModificacionSimple (LIdentificador $2 (tknPos $2) offset alcance) $6} }
              | let identifier colon TYPE                        {% do{ (offset, alcance) <- tryInsert $2 $4; return $ ModificacionSimple (LIdentificador $2 (tknPos $2) offset alcance) (inicializarDeclaracionVacia $4)} }
              | let identifier colon TYPE equal BLOCKDEF         {% do{ (offset, alcance) <- tryInsert $2 $4; verificarTipoBlock (tknPos $1) $4 $6; return $ ModificacionReg (LIdentificador $2 (tknPos $2) offset alcance) $6} }
              | let identifier colon TYPE equal UNIONBLOCKDEF    {% do{ tipo <- modificarTipoUnion (tknPos $1) (LIdentificador $2 (tknPos $2) ("dummy", 42069) (-1)) $4 $6; (offset, alcance) <- tryInsert $2 tipo; return $ ModificacionUnion (LIdentificador $2 (tknPos $2) offset alcance) $6}}
              | let identifier colon DEFTYPE equal EXPRESION     {% do{ (offset, alcance) <- tryInsert $2 $4; verificarTipoDef $2 $4 (getTipoEx $6); return $ ModificacionSimple (LIdentificador $2 (tknPos $2) offset alcance) $6} }
              | let identifier colon DEFTYPE                     {% do{ (offset, alcance) <- tryInsert $2 $4; return $ ModificacionSimple (LIdentificador $2 (tknPos $2) offset alcance) (inicializarDeclaracionVacia $4)} }
              | let identifier colon DEFTYPE equal BLOCKDEF      {% do{ (offset, alcance) <- tryInsert $2 $4; verificarTipoBlock (tknPos $1) $4 $6; return $ ModificacionReg (LIdentificador $2 (tknPos $2) offset alcance) $6} }
              | let identifier colon DEFTYPE equal UNIONBLOCKDEF {% do{ tipo <- modificarTipoUnion (tknPos $1) (LIdentificador $2 (tknPos $2) ("dummy", 42069) (-1)) $4 $6; (offset, alcance) <- tryInsert $2 tipo; return $ ModificacionUnion (LIdentificador $2 (tknPos $2) offset alcance) $6}}


-- Definiciones inline de registros
BLOCKDEF:     begin LISTASIG end                         { $2 }

-- Definiciones inline de unions
UNIONBLOCKDEF: TypeName begin end                          { ($1, []) }
               | TypeName begin LISTASIG end               { ($1, $3) }

-- Lista de asignaciones de una definicion de bloque inline
LISTASIG:     identifier equal EXPRESION                   { ($1, $3):[] }
              | LISTASIG comma identifier equal EXPRESION  { ($3, $5):$1 }

-- L-Values
LVALUE: identifier                                         {% do{estado <- get; return $ LIdentificador $1 (tknPos $1) (extractOffset estado (tknString $1)) (extractAlcance estado (tknString $1))}}
      | identifier ACCESSARRAY                             {% do{estado <- get; return $ LAccessArray $1 $2 (tknPos $1) (extractOffset estado (tknString $1)) (extractAlcance estado (tknString $1))}}
      | LVALUE point LVALUE2                               {LAccessMember $1 $3 (tknPos $2)}
      | mult LVALUE   %prec deref                          {LAccessPointer $2 (tknPos $1)}
      | mult open LVALUE point LVALUE2 close               {LAccessPointer (LAccessMember $3 $5 (tknPos $1)) (tknPos $1)}

LVALUE2: identifier                                        {% do{estado <- get; return $ LIdentificador $1 (tknPos $1) (extractOffset estado (tknString $1)) (extractAlcance estado (tknString $1))}}
       | identifier ACCESSARRAY                            {% do{estado <- get; return $ LAccessArray $1 $2 (tknPos $1) (extractOffset estado (tknString $1)) (extractAlcance estado (tknString $1))}}
       | LVALUE2 point LVALUE2                             {LAccessMember $1 $3 (tknPos $2)}

ACCESSARRAY: ACCESSARRAY openSq EXPRESION closeSq     { $3:$1 }
             | openSq EXPRESION closeSq               { $2:[] }


MODVARIABLE: LVALUE equal EXPRESION       {% do{ltipo <- tryObtenerTipoLVal $1 (tknPos $2); compararLconR (tknPos $2) ltipo (getTipoEx $3); return $ ModificacionSimple $1 $3}}
             | LVALUE equal BLOCKDEF      {% do{ltipo <- tryObtenerTipoLVal $1 (tknPos $2); verificarTipoBlock (tknPos $2) ltipo $3; return $ ModificacionReg $1 $3}}
             | LVALUE equal UNIONBLOCKDEF {% do{ltipo <- tryObtenerTipoLVal $1 (tknPos $2); modificarTipoUnion (tknPos $2) $1 ltipo $3; return $ ModificacionUnion $1 $3}}

-- Definicion de Tipo
DEFDETIPO:    Boy TypeName equal TYPE                      {% do{ tryInsertTipo $2 $4; return $ DeclaracionVariable $2}}
              | Boy TypeName equal DEFTYPE                 {% do{ tryInsertTipo $2 $4; return $ DeclaracionVariable $2}}


--------------------------------------------------------------------------------------------------- -

-- Record
LISTADEF:     LISTADEF Nl DEFVARIABLE                                        {% do{estado <- get ; return $ createListDef (getTokenDec $3) estado $1} }
              | DEFVARIABLE                                                  {% do{estado <- get ; return $ createListDef (getTokenDec $1) estado []} }

-- Union
LISTATAG:     Tag TypeName                                                  { ((tknString $2), (S.empty)):[] }
              | LISTATAG Nl Tag TypeName                                    { ((tknString $4), (S.empty)):$1 }
              | LISTATAG Nl Tag TypeName equal NUEVOBLOQUE LISTADEFT Nl end {% do {finalizarBloqueU; return $ ((tknString $4), (S.fromList $7)):$1} }
              | Tag TypeName equal NUEVOBLOQUE LISTADEFT Nl end             {% do {finalizarBloqueU; return $ ((tknString $2), (S.fromList $5)):[]} }

LISTADEFT:     LISTADEFT Nl DEFVARIABLEU                                    {% do{estado <- get ; return $ createListDef (getTokenDec $3) estado $1} }
              | DEFVARIABLEU                                                {% do{estado <- get ; return $ createListDef (getTokenDec $1) estado []} }

-- Definicion de variable con chequeo de parametros
DEFVARIABLEU:  let identifier colon TYPE equal EXPRESION         {% do{ (offset, alcance) <- tryInsertU $2 $4; verificarTipoDef $2 $4 (getTipoEx $6); return $ ModificacionSimple (LIdentificador $2 (tknPos $2) offset alcance) $6} }
              | let identifier colon TYPE                        {% do{ (offset, alcance) <- tryInsertU $2 $4; return $ ModificacionSimple (LIdentificador $2 (tknPos $2) offset alcance) (inicializarDeclaracionVacia $4) }}
              | let identifier colon TYPE equal BLOCKDEF         {% do{ (offset, alcance) <- tryInsertU $2 $4; verificarTipoBlock (tknPos $1) $4 $6; return $ ModificacionReg (LIdentificador $2 (tknPos $2) offset alcance) $6 }}
              | let identifier colon TYPE equal UNIONBLOCKDEF    {% do{ tipo <- modificarTipoUnion (tknPos $1) (LIdentificador $2 (tknPos $2) ("dummy", 42069) (-1)) $4 $6; (offset, alcance) <- tryInsertU $2 tipo; return $ ModificacionUnion (LIdentificador $2 (tknPos $2) offset alcance) $6 }}
              | let identifier colon DEFTYPE equal EXPRESION     {% do{ (offset, alcance) <- tryInsertU $2 $4; verificarTipoDef $2 $4 (getTipoEx $6); return $ ModificacionSimple (LIdentificador $2 (tknPos $2) offset alcance) $6} }
              | let identifier colon DEFTYPE                     {% do{ (offset, alcance) <- tryInsertU $2 $4; return $ ModificacionSimple (LIdentificador $2 (tknPos $2) offset alcance) (inicializarDeclaracionVacia $4) }}
              | let identifier colon DEFTYPE equal BLOCKDEF      {% do{ (offset, alcance) <- tryInsertU $2 $4; verificarTipoBlock (tknPos $1) $4 $6; return $ ModificacionReg (LIdentificador $2 (tknPos $2) offset alcance) $6 }}
              | let identifier colon DEFTYPE equal UNIONBLOCKDEF {% do{ tipo <- modificarTipoUnion (tknPos $1) (LIdentificador $2 (tknPos $2) ("dummy", 42069) (-1)) $4 $6; (offset, alcance) <- tryInsertU $2 tipo; return $ ModificacionUnion (LIdentificador $2 (tknPos $2) offset alcance) $6 }}


----------------------------------------------------------------------------------------------------

-- Definicion de funciones
DEFFUNC:      func FUNCNAMEP NUEVOBLOQUE INSTSFUNCP Nl end    {% do {finalizarBloqueU; finalizarBloqueU; agregarInstruccionesFunc $2 $4; popOffsetFunc; return $ DeclaracionVariable (TKIntType (1,2)) } }
              | func FUNCNAME NUEVOBLOQUE INSTSFUNCP Nl end   {% do {finalizarBloqueU; agregarInstruccionesFunc $2 $4; popOffsetFunc; return $ DeclaracionVariable (TKIntType (1,2))} }
              | func FUNCNAMEND                               {% do {popOffsetFunc; return $ DeclaracionVariable (TKIntType (1,2))}}
              | func FUNCNAMEPND                              {% do {popOffsetFunc; return $ DeclaracionVariable (TKIntType (1,2))}}


FUNCNAME: NOMBREFUNCION open close colon SIMPLETYPE               {% do{tryInsertF $1 $5 [] True; return $1 } } 
FUNCNAMEP: NOMBREFUNCION open PARAMLIST close colon SIMPLETYPE    {% do{tryInsertF $1 $6 $3 True; return $1 } }


FUNCNAMEND: NOMBREFUNCION open close colon SIMPLETYPE             {% do{tryInsertF $1 $5 [] False; return $1 } } 
FUNCNAMEPND: NOMBREFUNCION open PARAMLIST close colon SIMPLETYPE  {% do{tryInsertF $1 $6 $3 False; return $1 } }

NOMBREFUNCION: identifier {% do {insertOffsetFunc $1; return $1}}

-- Tipos simples para devolucion de funciones
SIMPLETYPE:   Int                                                { IntType }
              | Bool                                             { BoolType }
              | Char                                             { CharType }
              | Float                                            { FloatType }
              | Pointer TYPE                                     { PointerType $2 }
              | Pointer PARAMTYPE                                { PointerType $2 }
              | Void                                             { VoidType }

-- Parametros de una funcion
PARAMLIST:    identifier colon TYPE                                 {% do {nuevoBloque; (offset, alcance) <- tryInsert $1 $3 ; return $ (PorValor $1 offset):[]} } -- no
              | PARAMLIST comma identifier colon TYPE               {% do {(offset, alcance) <- tryInsert $3 $5 ; return $ (PorValor $3 offset):$1} }
              | dollar identifier colon TYPE                        {% do {nuevoBloque; (offset, alcance) <- tryInsertR $2 $4 ; return $ (PorReferencia $2 offset):[]} }
              | PARAMLIST comma dollar identifier colon TYPE        {% do {(offset, alcance) <- tryInsertR $4 $6 ; return $ (PorReferencia $4 offset):$1} }
              | identifier colon PARAMTYPE                          {% do {nuevoBloque; (offset, alcance) <- tryInsert $1 $3 ; return $ (PorValor $1 offset):[]} } -- no
              | PARAMLIST comma identifier colon PARAMTYPE          {% do {(offset, alcance) <- tryInsert $3 $5 ; return $ (PorValor $3 offset):$1} }
              | dollar identifier colon PARAMTYPE                   {% do {nuevoBloque; (offset, alcance) <- tryInsertR $2 $4 ; return $ (PorReferencia $2 offset):[]} }
              | PARAMLIST comma dollar identifier colon PARAMTYPE   {% do {(offset, alcance) <- tryInsertR $4 $6 ; return $ (PorReferencia $4 offset):$1} }

----------------------------------------------------------------------------------------------------

-- Instrucciones de Funciones
INSTSFUNC:    INSTSFUNC Nl INSTRUCCIONF   { case $3 of {DeclaracionVariable _ -> $1; _ -> $3:$1}  }
              | INSTRUCCIONF              { case $1 of {DeclaracionVariable _ -> []; _ -> $1:[]}  }


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
              | LLAMADA                       {% do{_ <- typeLlamadaMonadic (getTokenL $1) (map getTipoEx (getParametros $1)); return $ InstLlamada $1 }}
              | print open EXPRESION close    {% do{checkPrintFree (tknPos $1) (getTipoEx $3) StringType; return $ Print $3} }
              | free open EXPRESION close     {% do{checkPrintFree (tknPos $1) (getTipoEx $3) (PointerType (NullType [])); return $ Free $3} }

-- Instrucciones de Funciones con parametros
INSTSFUNCP:    INSTSFUNCP Nl INSTRUCCIONFP   { case $3 of {DeclaracionVariable _ -> $1; _ -> $3:$1}  }
              | INSTRUCCIONFP                { case $1 of {DeclaracionVariable _ -> []; _ -> $1:[]}  }


-- Instruccion de Funcion con parametros
INSTRUCCIONFP: return                         { InstReturn Nothing }
              | return EXPRESION              { InstReturn (Just $2) }
              | SELECCIONIFF                  { InstIf $1 }
              | SELECCIONMATCHF               { InstMatch $1 }
              | REPETICIONDETF                { InstRepDet $1 }
              | REPETICIONINDETF              { InstRepIndet $1 }
              | DEFVARIABLEP                  { $1 }
              | MODVARIABLE                   { $1 }
              | DEFDETIPO                     { $1 }
              | LLAMADA                       {% do{_ <- typeLlamadaMonadic (getTokenL $1) (map getTipoEx (getParametros $1)); return $ InstLlamada $1 }}
              | print open EXPRESION close    {% do{checkPrintFree (tknPos $1) (getTipoEx $3) StringType; return $ Print $3} }
              | free open EXPRESION close     {% do{checkPrintFree (tknPos $1) (getTipoEx $3) (PointerType (NullType [])); return $ Free $3} }

-- Definicion de variable con chequeo de parametros
DEFVARIABLEP:  let identifier colon TYPE equal EXPRESION         {% do{ (offset, alcance) <- tryInsertP $2 $4; verificarTipoDef $2 $4 (getTipoEx $6); return $ ModificacionSimple (LIdentificador $2 (tknPos $2) offset alcance) $6} }
              | let identifier colon TYPE                        {% do{ (offset, alcance) <- tryInsertP $2 $4; return $ ModificacionSimple (LIdentificador $2 (tknPos $2) offset alcance) (inicializarDeclaracionVacia $4) }}
              | let identifier colon TYPE equal BLOCKDEF         {% do{ (offset, alcance) <- tryInsertP $2 $4; verificarTipoBlock (tknPos $1) $4 $6; return $ ModificacionReg (LIdentificador $2 (tknPos $2) offset alcance) $6 }}
              | let identifier colon TYPE equal UNIONBLOCKDEF    {% do{ tipo <- modificarTipoUnion (tknPos $1) (LIdentificador $2 (tknPos $2) ("dummy", 42069) (-1)) $4 $6; (offset, alcance) <- tryInsertP $2 tipo; return $ ModificacionUnion (LIdentificador $2 (tknPos $2) offset alcance) $6 }}
              | let identifier colon DEFTYPE equal EXPRESION     {% do{ (offset, alcance) <- tryInsertP $2 $4; verificarTipoDef $2 $4 (getTipoEx $6); return $ ModificacionSimple (LIdentificador $2 (tknPos $2) offset alcance) $6} }
              | let identifier colon DEFTYPE                     {% do{ (offset, alcance) <- tryInsertP $2 $4; return $ ModificacionSimple (LIdentificador $2 (tknPos $2) offset alcance) (inicializarDeclaracionVacia $4) }}
              | let identifier colon DEFTYPE equal BLOCKDEF      {% do{ (offset, alcance) <- tryInsertP $2 $4; verificarTipoBlock (tknPos $1) $4 $6; return $ ModificacionReg (LIdentificador $2 (tknPos $2) offset alcance) $6 }}
              | let identifier colon DEFTYPE equal UNIONBLOCKDEF {% do{ tipo <- modificarTipoUnion (tknPos $1) (LIdentificador $2 (tknPos $2) ("dummy", 42069) (-1)) $4 $6; (offset, alcance) <- tryInsertP $2 tipo; return $ ModificacionUnion (LIdentificador $2 (tknPos $2) offset alcance) $6 }}


-- Instrucciones de Funciones dentro de Loops
INSTSFUNCL:    INSTSFUNCL Nl INSTRUCCIONFL   { case $3 of {DeclaracionVariable _ -> $1; _ -> $3:$1}  }
              | INSTRUCCIONFL                { case $1 of {DeclaracionVariable _ -> []; _ -> $1:[]}  }


-- Instruccion de Funcion Individual dentro de Loop
INSTRUCCIONFL: return                          { InstReturn Nothing }
              | return EXPRESION              { InstReturn (Just $2) }
              | SELECCIONIFF                  { InstIf $1 }
              | SELECCIONMATCHF               { InstMatch $1 }
              | REPETICIONDETF                { InstRepDet $1 }
              | REPETICIONINDETF              { InstRepIndet $1 }
              | DEFVARIABLE                   { $1 }
              | MODVARIABLE                   { $1 }
              | DEFDETIPO                     { $1 }
              | LLAMADA                       {% do{_ <- typeLlamadaMonadic (getTokenL $1) (map getTipoEx (getParametros $1)); return $ InstLlamada $1 }}
              | break                         { InstBreak }
              | print open EXPRESION close    {% do{checkPrintFree (tknPos $1) (getTipoEx $3) StringType; return $ Print $3} }
              | free open EXPRESION close     {% do{checkPrintFree (tknPos $1) (getTipoEx $3) (PointerType (NullType [])); return $ Free $3} }
----------------------------------------------------------------------------------------------------

-- Selecciones de If
SELECCIONIF:  if EXPRESION NUEVOBLOQUE INSTRUCCIONESC Nl end   %prec then       {% do {finalizarBloqueU; verificarTipoCond (fst $ tknPos $1) (getTipoEx $2); return $ ($2, $4):[] } }
              | IF LISTAELSE                                                    { $2 ++ [$1] }

IF: if EXPRESION NUEVOBLOQUE INSTRUCCIONESC Nl end                              {% do {finalizarBloqueU; verificarTipoCond (fst $ tknPos $1) (getTipoEx $2); return ($2,$4)}}

-- Elses de los if
LISTAELSE:    LISTAELSE else EXPRESION NUEVOBLOQUE INSTRUCCIONESC Nl end        {% do {finalizarBloqueU; verificarTipoCond (fst $ tknPos $2) (getTipoEx $3); return $ ($3 , $5):$1} }
              | else otherwise NUEVOBLOQUE INSTRUCCIONESC Nl end                {% do {finalizarBloqueU; return $ (ExpTrue BoolType, $4):[]} }
              | else EXPRESION NUEVOBLOQUE INSTRUCCIONESC Nl end                {% do {finalizarBloqueU; verificarTipoCond (fst $ tknPos $1) (getTipoEx $2); return $ ($2, $4):[]} }
              | LISTAELSE else otherwise NUEVOBLOQUE INSTRUCCIONESC Nl end      {% do {finalizarBloqueU; return $ (ExpTrue BoolType, $5):$1} }

-- Seleccion de If dentro de funciones
SELECCIONIFF:  if EXPRESION NUEVOBLOQUE INSTSFUNC Nl end   %prec then           {% do {finalizarBloqueU; verificarTipoCond (fst $ tknPos $1) (getTipoEx $2); return $ ($2, $4):[] } }
              | IFF LISTAELSEF                                                  { $2 ++ [$1] }

IFF: if EXPRESION NUEVOBLOQUE INSTSFUNC Nl end                                  {% do{finalizarBloqueU; verificarTipoCond (fst $ tknPos $1) (getTipoEx $2); return ($2,$4)}}

-- Elses de los ifs dentro de funciones
LISTAELSEF:    LISTAELSEF else EXPRESION NUEVOBLOQUE INSTSFUNC Nl end           {% do {finalizarBloqueU; verificarTipoCond (fst $ tknPos $2) (getTipoEx $3); return $ ($3 , $5):$1} }
              | else otherwise NUEVOBLOQUE INSTSFUNC Nl end                     {% do {finalizarBloqueU; return $ (ExpTrue BoolType, $4):[]} }
              | else EXPRESION NUEVOBLOQUE INSTSFUNC Nl end                     {% do {finalizarBloqueU; verificarTipoCond (fst $ tknPos $1) (getTipoEx $2); return $ [($2, $4)]} }
              | LISTAELSEF else otherwise NUEVOBLOQUE INSTSFUNC Nl end          {% do {finalizarBloqueU; return $ (ExpTrue BoolType, $5):$1} }

----------------------------------------------------------------------------------------------------

-- Seleccion match
SELECCIONMATCH: match LVALUE begin LISTACASOS Nl end                     {% do {ltipo <- tryObtenerTipoLVal $2 (tknPos $1); verificarCasosTag ltipo $4 (tknPos $1); return $ Match $2 $4}}
              | match LVALUE begin LISTACASOS Nl DEFAULTCASE Nl end      {% do {ltipo <- tryObtenerTipoLVal $2 (tknPos $1); verificarCasosTag ltipo ($6:$4) (tknPos $1); return $ Match $2 ($6:$4)}}

-- Seleccion match dentro de funciones
SELECCIONMATCHF: match LVALUE begin LISTACASOSF Nl end                   {% do {ltipo <- tryObtenerTipoLVal $2 (tknPos $1); verificarCasosTag ltipo $4 (tknPos $1); return $ Match $2 $4}}
              | match LVALUE begin LISTACASOSF Nl DEFAULTCASEF end       {% do {ltipo <- tryObtenerTipoLVal $2 (tknPos $1); verificarCasosTag ltipo ($6:$4) (tknPos $1); return $ Match $2 ($6:$4)}}

-- Casos para el match
LISTACASOS: case TypeName NUEVOBLOQUE INSTRUCCIONESC Nl end                  {% do {finalizarBloqueU; return $ Case $2 $4:[] } }
          | LISTACASOS Nl case TypeName NUEVOBLOQUE INSTRUCCIONESC Nl end    {% do {finalizarBloqueU; return $ (Case $4 $6):$1 } }

DEFAULTCASE: case default NUEVOBLOQUE INSTRUCCIONESC Nl end                  {% do {finalizarBloqueU; return $ (Case $2 $4)}}

-- Casos para match dentro de funciones
LISTACASOSF: case TypeName NUEVOBLOQUE INSTSFUNC Nl end                      {% do {finalizarBloqueU; return $ Case $2 $4:[] } } -- TODO Verificacion
           | LISTACASOSF Nl case TypeName NUEVOBLOQUE INSTSFUNC Nl end       {% do {finalizarBloqueU; return $ (Case $4 $6):$1 } } -- TODO Verificacion

DEFAULTCASEF: case default NUEVOBLOQUE INSTSFUNC Nl end                      {% do {finalizarBloqueU; return $ (Case $2 $4)}}

-- -- Instrucciones Match
-- INSTRUCCIONESM:
-- -- Instrucciones Match para funciones
-- INSTSFUNCM:
----------------------------------------------------------------------------------------------------

-- Repeticion determinada
REPETICIONDET:   for REPDETITER NUEVOBLOQUE INSTRUCCIONESL Nl end                 {% do {finalizarBloqueU; finalizarBloqueU; return $ RepDet (interIdent $2) (interType $2) (interFrom $2) (interTo $2) (interBy $2) $4 (interOffset $2)} }
                 | for REPDETARRAY NUEVOBLOQUE INSTRUCCIONESL Nl end              {% do {finalizarBloqueU; finalizarBloqueU; return $ RepDetArray (interIdent $2) (interType $2) (interExp $2) $4 (interOffset $2)} }

-- Repeticion determinadas dentro de funciones
REPETICIONDETF:  for REPDETITER NUEVOBLOQUE INSTSFUNCL Nl end                     {% do {finalizarBloqueU; finalizarBloqueU; return $ RepDet (interIdent $2) (interType $2) (interFrom $2) (interTo $2) (interBy $2) $4 (interOffset $2)} }
                 | for REPDETARRAY NUEVOBLOQUE INSTSFUNCL Nl end                  {% do {finalizarBloqueU; finalizarBloqueU; return $ RepDetArray (interIdent $2) (interType $2) (interExp $2) $4 (interOffset $2)} }

-- Declaracion del iterador dentro del for
REPDETITER: identifier colon TYPE from EXPRESION to EXPRESION                     {% do { verificarTipoRepDet (fst $ tknPos $1) $3 (getTipoEx $5) (getTipoEx $7); nuevoBloque; (offset, alcance) <- tryInsert $1 $3; return $ Inter $1 $3 $5 $7 Nothing offset} }
            | identifier colon TYPE from EXPRESION to EXPRESION by EXPRESION      {% do { verificarTipoRepDetBy (fst $ tknPos $1) $3 (getTipoEx $5) (getTipoEx $7) (getTipoEx $9); nuevoBloque; (offset, alcance) <- tryInsert $1 $3; return $ Inter $1 $3 $5 $7 (Just $9) offset}}
            | identifier colon PARAMTYPE from EXPRESION to EXPRESION              {% do { verificarTipoRepDet (fst $ tknPos $1) $3 (getTipoEx $5) (getTipoEx $7); nuevoBloque; (offset, alcance) <- tryInsert $1 $3; return $ Inter $1 $3 $5 $7 Nothing offset} }
            | identifier colon PARAMTYPE from EXPRESION to EXPRESION by EXPRESION {% do { verificarTipoRepDetBy (fst $ tknPos $1) $3 (getTipoEx $5) (getTipoEx $7) (getTipoEx $9); nuevoBloque; (offset, alcance) <- tryInsert $1 $3; return $ Inter $1 $3 $5 $7 (Just $9) offset}}

REPDETARRAY:  identifier colon TYPE in EXPRESION                                  {% do { verificarTipoRepDetArr (fst $ tknPos $1) ($3) (getTipoEx $5); nuevoBloque; (offset, alcance) <- tryInsert $1 $3; return $ InterArray $1 $3 $5 offset}}
              | identifier colon PARAMTYPE in EXPRESION                           {% do { verificarTipoRepDetArr (fst $ tknPos $1) ($3) (getTipoEx $5); nuevoBloque; (offset, alcance) <- tryInsert $1 $3; return $ InterArray $1 $3 $5 offset}}
----------------------------------------------------------------------------------------------------

-- Arreglos
ARRAY:        openSq CONTENIDO closeSq    { $2 }

-- Contenido de los arreglos
CONTENIDO:    CONTENIDO comma EXPRESION     { $3:$1 }
              | EXPRESION                   { $1:[] }

----------------------------------------------------------------------------------------------------

-- Repeticion Indeterminada
REPETICIONINDET: while EXPRESION NUEVOBLOQUE INSTRUCCIONESL Nl end {% do {finalizarBloqueU; verificarTipoCond (fst $ tknPos $1) (getTipoEx $2); return $ RepeticionIndet $2 $4 } }

-- Repeticion Indeterminada dentro de funciones
REPETICIONINDETF: while EXPRESION NUEVOBLOQUE INSTSFUNCL Nl end    {% do {finalizarBloqueU; verificarTipoCond (fst $ tknPos $1) (getTipoEx $2); return $ RepeticionIndet $2 $4 } }

----------------------------------------------------------------------------------------------------

-- Instrucciones para el If
INSTRUCCIONESC: INSTRUCCIONESC Nl INSTRUCCIONC    { case $3 of {DeclaracionVariable _ -> $1; _ -> $3:$1}  }
               | INSTRUCCIONC                     { case $1 of {DeclaracionVariable _ -> []; _ -> $1:[]}  }

-- Instrucciones para el If
INSTRUCCIONC: DEFVARIABLE                     { $1 }
              | MODVARIABLE                   { $1 }
              | DEFDETIPO                     { $1 }
              | SELECCIONIF                   { InstIf $1 }
              | SELECCIONMATCH                { InstMatch $1 }
              | REPETICIONDET                 { InstRepDet $1 }
              | REPETICIONINDET               { InstRepIndet $1 }
              | LLAMADA                       {% do{_ <- typeLlamadaMonadic (getTokenL $1) (map getTipoEx (getParametros $1)); return $ InstLlamada $1 }}
              | print open EXPRESION close    {% do{checkPrintFree (tknPos $1) (getTipoEx $3) StringType; return $ Print $3} }
              | free open EXPRESION close     {% do{checkPrintFree (tknPos $1) (getTipoEx $3) (PointerType (NullType [])); return $ Free $3} }


-- Instrucciones para los loops
INSTRUCCIONESL: INSTRUCCIONESL Nl INSTRUCCIONL    { case $3 of {DeclaracionVariable _ -> $1; _ -> $3:$1}  }
               | INSTRUCCIONL                     { case $1 of {DeclaracionVariable _ -> []; _ -> $1:[]}  }

-- Instrucciones para los loops
INSTRUCCIONL: DEFVARIABLE                     { $1 }
              | MODVARIABLE                   { $1 }
              | DEFDETIPO                     { $1 }
              | SELECCIONIF                   { InstIf $1 }
              | SELECCIONMATCH                { InstMatch $1 }
              | REPETICIONDET                 { InstRepDet $1 }
              | REPETICIONINDET               { InstRepIndet $1 }
              | LLAMADA                       {% do{_ <- typeLlamadaMonadic (getTokenL $1) (map getTipoEx (getParametros $1)); return $ InstLlamada $1 }}
              | break                         { InstBreak }
              | print open EXPRESION close    {% do{checkPrintFree (tknPos $1) (getTipoEx $3) StringType; return $ Print $3} }
              | free open EXPRESION close     {% do{checkPrintFree (tknPos $1) (getTipoEx $3) (PointerType (NullType [])); return $ Free $3} }
----------------------------------------------------------------------------------------------------

-- Llamadas a funciones
LLAMADA:      identifier open close                             {% do {verificarExistenciaFuncion $1 0; return $ Llamada $1 [] } }
              | identifier open ARGLIST close                   {% do {verificarExistenciaFuncion $1 (length $3); return $ Llamada $1 $3 } }
              | TypeName point identifier open close            { LlamadaModulo $1 $3 [] }
              | TypeName point identifier open ARGLIST close    { LlamadaModulo $1 $3 $5 }

-- Argumentos de una llamada a funcion
ARGLIST:      EXPRESION                       { $1:[] }
              | ARGLIST comma EXPRESION       { $3:$1 }

----------------------------------------------------------------------------------------------------
-- Expresiones
EXPRESION:    LLAMADA                           {% do{ tipo <- typeLlamadaMonadic (getTokenL $1) (map getTipoEx (getParametros $1)); return $ ExpLlamada $1 $ tipo}}
              | ARRAY                           { ExpArray $1 (getArrayType $1) }
              | number                          { ExpNumero $1 (floatOrInt (tknNumber $1)) }
              | character                       { ExpCaracter $1 CharType }
              | True                            { ExpTrue BoolType }
              | False                           { ExpFalse BoolType }
              | string                          { ExpString $1 StringType }
              | not EXPRESION %prec not         {% do{let {tipo = unary BoolType (getTipoEx $2)}; return $ ExpNot $2 tipo} }
              | EXPRESION or EXPRESION          {% do{let {tipo = binaryBoolean (getTipoEx $1) (getTipoEx $3)}; return $ ExpOr $1 $3 tipo} }
              | EXPRESION and EXPRESION         {% do{let {tipo = binaryBoolean (getTipoEx $1) (getTipoEx $3)}; return $ ExpAnd $1 $3 tipo} }

              -- Comparacion
              | EXPRESION gt EXPRESION          {% do{let {tipo = binaryNumberOp BoolType (getTipoEx $1) (getTipoEx $3)}; return $ ExpGreater $1 $3 tipo }}
              | EXPRESION lt EXPRESION          {% do{let {tipo = binaryNumberOp BoolType (getTipoEx $1) (getTipoEx $3)}; return $ ExpLesser $1 $3 tipo }}
              | EXPRESION goet EXPRESION        {% do{let {tipo = binaryNumberOp BoolType (getTipoEx $1) (getTipoEx $3)}; return $ ExpGreaterEqual $1 $3 tipo }}
              | EXPRESION loet EXPRESION        {% do{let {tipo = binaryNumberOp BoolType (getTipoEx $1) (getTipoEx $3)}; return $ ExpLesserEqual $1 $3 tipo }}
              | EXPRESION eq EXPRESION          {% do{let {tipo = binaryEquivalenceOp (getTipoEx $1) (getTipoEx $3)}; return $ ExpEqual $1 $3 tipo }}
              | EXPRESION uneq EXPRESION        {% do{let {tipo = binaryEquivalenceOp (getTipoEx $1) (getTipoEx $3)}; return $ ExpNotEqual $1 $3 tipo }}

              -- Numericas
              | EXPRESION plus EXPRESION        {% do{let {tipo = binaryNumberOpRestricted (getTipoEx $1) (getTipoEx $3)}; return $ ExpPlus $1 $3 tipo} }
              | EXPRESION minus EXPRESION       {% do{let {tipo = binaryNumberOpRestricted (getTipoEx $1) (getTipoEx $3)}; return $ ExpMinus $1 $3 tipo} }
              | EXPRESION mult EXPRESION        {% do{let {tipo = binaryNumberOpRestricted (getTipoEx $1) (getTipoEx $3)}; return $ ExpProduct $1 $3 tipo} }
              | EXPRESION div EXPRESION         {% do{let {tipo = binaryNumberOp FloatType (getTipoEx $1) (getTipoEx $3)}; return $ ExpDivision $1 $3 tipo} }
              | EXPRESION mod EXPRESION         {% do{let {tipo = binaryNumberOpRestricted (getTipoEx $1) (getTipoEx $3)}; return $ ExpMod $1 $3 tipo} }
              | EXPRESION wdiv EXPRESION        {% do{let {tipo = binaryNumberOp IntType (getTipoEx $1) (getTipoEx $3)}; return $ ExpWholeDivision $1 $3 tipo} }
              | minus EXPRESION %prec uminus    {% do{let {tipo = unary IntType (getTipoEx $2)}; return $ ExpUminus $2 tipo} }
              | open EXPRESION close            { $2 }

              --Rvalues
              | LVALUE                         {% do{tipo <- tryObtenerTipoLVal $1 (getLPos $1); return $ ExpRValue $1 tipo} }
              -- Funciones Cableadas
              | input open close               { ExpInput StringType }
              | malloc open TYPE close         { ExpMalloc (PointerType $3) }
              | malloc open DEFTYPE close      { ExpMalloc (PointerType $3) }
              | stringify open EXPRESION close {% do{checkStringify (tknPos $1) (getTipoEx $3); return $ ExpStringify $3 StringType} }

{
parseError [] = error "Final Inesperado"
parseError ts = error $ "Token Inesperado: \n" ++ (printToken $ head ts)

testExample str = do
  handle <- openFile ("../Examples/" ++ str) ReadMode
  contents <- hGetContents handle
  ((arbol,tabla),logOcurrencias) <- runWriterT $ runStateT (parserBoy $ alexScanTokens contents) estadoInicial
  putStrLn $ printLBC $ getLBC tabla
  --putStrLn "\n"
  -- putStrLn "\n"
  putStrLn $ unlines $ map symbolErrorToStr logOcurrencias
  putStrLn $ unlines $ map typeErrorToStr logOcurrencias
  --Pretty.pPrint arbol
}
