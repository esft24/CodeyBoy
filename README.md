# CI4721 Diseño del lenguage

## Integrantes

- Erick Flejan    12-11555
- Carlos Pérez    13-11089

## Requerimientos

- Haskell
https://www.haskell.org/
- Happy
```
  cabal update
  cabal install happy
```
- Alex
```
   cabal update
   cabal install alex
```
- Pretty Simple
```
   cabal update
   cabal install pretty-simple
```
## Caracteristicas del Lenguaje

1. Imperativo
2. Alcance estático con bloques anidados
3. Fuertemente tipado con verificación estática
4. Tipos:
   - Simples:
     - Entero
     - Booleano
     - Char
     - Punto Flotante
   - Compuestos:
     - Arreglos
     - Strings
   - Estructurados:
     - Registros
     - Uniones
   - Apuntadores (Pero solo al heap)
5. Instrucciones
   - De selección
   - De repetición determinada
   - de repetición indeterminada
6. Pasaje de parámetros:
   - Por valor
   - Por referencia
7. Retornos:
   - Vacío
   - De tipos simples
8. Recursión

## Herramientas a utilizar

- Haskell:
  - Alex
  - Happy

## Hello World

Primero empezaremos por escribir nuestro primer programa y si, lo adivinaron,es  un  Hello  World!  Para  seguir  tradiciones,  este  programa  lo  unico  que  hara  seraimprimir “Hello World” en consola unicamente.

```
print("Hello World!")
```

## Comentarios

Para poder tener nuestro codigo debidamente documentado, es necesario escribircomentarios en nuestro codigos, y en CodeyBoy, los comentarios se especifican de lasiguiente manera:

```
#Esto es un  comentario!
print("Hello  World")
```

## Tipos de Datos

### Tipos de Datos Simples

CodeyBoy cuenta con los siguientes tipos de datos simples:

#### Booleanos

Los booleanos estan representados por las palabras claves *True* y *False*

```
let x: Bool = True
let y: Bool = False
```

#### Enteros

Los numeros enteros estan compuestos de caracteres numericos con una longitud minima de un caracter, con un rango de entre 2^29 hasta 2^28-1.

```
let bestNumber: Int = 42
```

#### Caracteres

El tipo char representa un unico valor escalar Unicode, y representas un char encerrado en comillas simples

```
let thisIsaChar: Char = 'z'
#You bet it is
```

#### Punto Flotante

Los numeros en representacion punto flotante estan definidos por la parte entera del numero y la parte decimal del numero, separados por un '.'.

```
let bestestNumber: Float = 42.0
```

### Tipos de datos compuestos

Con respecto a los tipos de datos compuestos, los siguientes estan definidos:

#### Arreglos

# TODO

Por ahorra los arreglos son de solo enteros y de tamaño dinamico de la forma tradicional de corchetesBoys

#### Strings

Los strings estan definidos de la forma tradicional, encerrados entre comillas dobles '"'.

```
let whatDoesItSays: String = "It says HI!"
```

### Tipos de Datos Estructurados

Los tipos de datos estructurados presentes en nuestro confiable CodeyBoy son los siguientes:

#### Registros

Los registros no son mas que una coleccion de datos compuestos de los tipos simples, el cual definiremos con la palabra clave Reg en su definicion de tipo, seguido por un = y el contenido del registro encapsulado entre { y }.

```
Boy NuevoTipo = Reg {

}

#Podemos crear un registro para una variable unicamente asi:
Boy NuevoTipo = Reg {
    let a: Int
    let b: Float
    let c: Char = 's'
    let d: Reg {
        x: Int
        y: Float = 1.8
    } = { x = 1 }
}

#Podemos crear una variable de ese tipo de luego asignar el contenido
let x: NuevoTipo
x.a = 5
x.b = 8.2
print(x.c)
# >> s

#O asignarlo de una al inicializarla
let y: NuevoTipo = {
    a = 1, b = 2.3, c = 'a',
    d = {x = 5, y = 9.4}
}
```

#### Unions

Los unions de CodeyBoy son Tagged Unions, los cuales contienen tags (Du’h) yse elige uno de ellos que represente el tipo de la variable a asignar, y su sintaxis es la siguiente:

```
Boy Forma = Union {
    # Valores en comun
    let x: Int
    let y: Int
    with

    Tag Cuadrado = {
        # let x: Int
        # let y: Int
        let lado: Int
    }

    Tag Circulo = {
        # let x: Int
        # let y: Int
        let radio: Int
    }
}

Boy Arbol = Union {
    Tag Rama = {
        let hijo1: Arbol
        let hijo2: Arbol
    }
    Tag Hoja
    
    Tag OtraHojaPeroDiferente
}

let unionInLine : Union {
  Tag Nombre1 = {
    ...
  }
  ...
}

let cuadradito: Forma = Cuadrado { x = 0, y = 0, lado = 10}

match cuadradito {
    case Cuadrado {
        print(cuadradito.lado * cuadradito.lado)
    }
    case Circulo {
        print(cuadradito.radio * cuadradito.radio * 3.14)
    }
}
```

## Instrucciones

A continuacion se explicará brevemente la sintaxis de las instrucciones en CodeyBoy

### Instruccion de selección

Las instrucciones de seleccion esta definida por un bloque que abre con la palabra clave if, seguido de un predicado y las llaves del bloque que contendran el codigo a ejecutar en caso de que se cumpla la condicion, en caso contrario, estas llaves son seguidas de un pipe '\|' que indica otra instruccion, es decir un else if en cierto modo, con otra condicion. Si ninguna de las condiciones de cumplen, se puede especificar un catch-all al final, despues de su debido pipe, usando el simbolo _ seguido del bloque de codigo a ejecutar.

```
if condicion{
  ...
}
| condicion{
  ...
}
| _{ #Esta es la condicion cath-it-all
  ...
}
fi
```

### Instrucciones de repeticion

Las instrucciones de repeticion estan definidas de dos formas, donde una es la repeticion determinada y la otra es una repeticion indeterminada:

#### Repetición determinada

Para las repeticiones determinadas utilizaremos la palabra clave for seguido de una variable en donde se almacenara el numero actual de ejecucion definido por el rango expuesto justo a continuacion, con el valor incial despues de la palabra clave from, el rango final despues de la palabra clave to y el tamaño de cada paso despues de la palabra clave by.

```
#Repeticion determinada para Enteros y Flotantes (By es opcional y se toma 1 por defecto)
for i : Int from 1 to 10 by 1{
  ...
}
#Repeticion sin caracteres (El by no es posible en este caso)
for i : Char from 'a' to 'z'{
  ...
}
#Repeticion para elementos dentro de un arreglo
for x: Type in array{
  ...
}
```

#### Repetición indeterminada

Para las repeticiones indeterminadas utilizaremos la palabra clave while seguido de la condicion la cual determinara cuando ha de salirse del ciclo de repeticiones.

```
while condicion {
    ...
}
```

## Funciones

Las funciones en CodeyBoy seran definidas con la palabra clave func seguido de el nombre de la funcion a definir y parentesis los parametros de la funcion con su debido tipo especificado. Despues de definir el nombre y los parametros se especifica el tipo de retorno de la funcion al igual que la especificacion de los tipos de las variables y en caso de no retornar nada se especifica con la palabra clave Void. El cuerpo de la funcion esta encerrado entre llaves.

```
func funcion($a:Int, b:Bool):Void{
  ...
}
```

Las funciones en CodeyBoy solo retornaran tipos simples o nada, a traves de la palabra clave return.

```
func dameCinco():Int{
  return 5
}
```

## Apuntadores

# TODO

### Modulos

Nuestro lenguaje tendra la opcion de manejar funciones que no esten descritas en el
codigo de fuente en el que se trabaja, mediante la importacion de modulos externos.
Se usaran opciones de manejo de modulos abierta selectiva, por lo tanto se permitira
manejar nombres mediante los siguientes metodos.

```
bring all the boys from FILEPATH # Importamos todo lo que el archivo contiene

bring the boys from FILEPATH who ( push, pop ) # Selectivamente importar ciertas funciones

bring all the boys from FILEPATH aka identifier # Permitir un prefijo que evite el choque de nombres

bring all the boys from FILEPATH but ( enqueue, dequeue )  # Esconder ciertos nombres selectivamente

# Tambien se puede combinar

bring the boys from FILEPATH who ( push, pop ) aka identifier
```
