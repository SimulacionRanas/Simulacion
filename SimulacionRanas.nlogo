breed [ranas rana]
breed [marcas marca]

;; definición de variables globales
globals
[
  ;; constantes de estado
  reposo
  movimiento
  conflicto
]

;; inicialización de variables globales
to init-globals
  set reposo 0
  set movimiento 1
  set conflicto 2
end



;;*******************************
;; setup:                       *
;;*******************************
to setup
  ;; Equivale a clear-ticks + clear-ranas + clear-patches +
  ;; clear-drawing + clear-all-plots + clear-output.
  ca

  init-globals

  ;; inicialización de parcelas
  ask patches
  [
    P-init
  ]

  ;; inicialiación de agentes
  ;; la primitiva cro crea tortugas distribuidas
  ;; uniformemente alrededor del (0, 0). Este
  ;; centro se localiza en el centro del mundo
  create-ranas cantidad-ranas ;; crt cantidad-ranas ;; cro cantidad-ranas
  [
    setxy random-pxcor random-pycor
    ;;jump (floor max-pxcor * 1.2 / 2)
    R-init
  ]

  ask patches
  [
    P-update
  ]
  if file-exists? "salida-movimientos.csv"
  [
    file-close
    file-delete "salida-movimientos.csv"
  ]
  file-open "salida-movimientos.csv"
  reset-ticks
end

;;*******************************
;; go:                          *
;;*******************************
to go
  ;; revisa si se le debe dar alimento
  ;; 1 tic es 1 hora
  ;; se les aumenta el peso cada 10 horas
  if ticks mod 10 = 0
  [ ask ranas [R-subirPeso] ]
  ask marcas
  [
    if edad = tiempo-vida-marca [ die ]
    set edad edad + 1

  ]

  ;; llama al metodo principal de cada rana
  ask ranas [
    R-comportamientoPrincipal
    R-guardar-posicion
  ]

  ask patches [
    P-update
  ]

  tick

  ;; actualizar-salidas

  if ticks >= read-from-string ticsMax
    [
      export-view "vista-final.png"
      file-close
      stop
    ]
end



;;***********************************
;; Definición de agentes:           *
;;***********************************
marcas-own
[
  edad
  who-padre
]

ranas-own ;;
[
  estado-actual
  tamano
  peso
  pesoInicial
  otro-en-conflicto
  ;; esto aun no lo uso acá
  frecuenciaCanto
  nivelAgresividad

  agentes-amenaza
  agentes-conflictos-previos
]

to R-init
  set color who * 10 - 6

  ;; Tamaño segun documento "Apuntes lluvia ideas"
  set tamano random-float 1.76 + 23.04

  ;; Función de Condición que está en el documento "Apuntes luvia ideas"
  set peso -0.795 + (0.779 * tamano)
  set pesoInicial peso

  ;; Función de frecuencia en documento "Apuntes lluvia idea"
  set frecuenciaCanto (-3760 * peso) + 3316

  set size 10

  R-pintar-parcela-actual

  set estado-actual reposo

  set agentes-amenaza []
  set agentes-conflictos-previos []

  set label (word who " " agentes-amenaza)
  set label-color black
end

to R-comportamientoPrincipal
  ;; primero se evalua si cambio de estado no
  R-reevaluar-estado

  ;; ejecutar la accion del estado
  R-ejecutar-accion
end

to R-guardar-posicion
  file-print (word ticks ";" who ";" pxcor ";"  pycor)
end

to R-pintar-parcela-actual
  ask neighbors
  [
    set colorActual [color] of myself
    set tiempoColor tiempo-vida-marca
  ]
  ask patch-here
  [
    set colorActual [color] of myself
    set tiempoColor tiempo-vida-marca
  ]
end

to R-reevaluar-estado
  if estado-actual = reposo
  [
    if peso > pesoInicial * (UmbralDesnutricion + UmbralRecuperacion)
    [
      set estado-actual movimiento
    ]
  ]
  ;;**************************************************************************************
  ;;Quizás hay que eliminar esta evaluación
  ;;***********************************************************************************
  if estado-actual = conflicto
  [
    ;; aca deberia evaluar si ya termino conflicto y si si, determina a cual estado
    ;; cambiar
    ;set estado-actual movimiento
  ]
  if estado-actual = movimiento
  [
   ifelse peso <= pesoInicial * UmbralDesnutricion
    [
      set estado-actual reposo
    ]
    [
      set peso peso - (peso * ( CostoMovPorTic / 100 ) )

    ]

  ]
end

to R-ejecutar-accion
  if estado-actual = reposo
  [
    ;; set peso peso + CostoMovPorTic
  ]
  if estado-actual = movimiento
  [
   R-moverse
  ]
  if estado-actual = conflicto
  [
    R-conflicto
  ]
end

to R-subirPeso ;;Correo del 23 de Julio => Aumen de peso por hora entre 0 y 3.6% de la masa inicial. Se límite superior se deja como un parámetro slider.
  let aumentoPeso  pesoInicial * ((Random-float ProbPesoPorHora) / 100)
  set peso peso + 24 * aumentoPeso
end

to R-moverse
  random-seed new-seed

  let cantidad-secciones 8
  let arco 360 / cantidad-secciones ;; para la detección en cono
  let caminos-nuevos []
  let caminos-conocidos []

  repeat cantidad-secciones
  [
    let amenazas other ranas
      with [R-en-lista [agentes-amenaza] of myself [who] of self]
      in-cone movimiento-por-tic arco

    if not any? amenazas and can-move? movimiento-por-tic
    [
      let marcas-terreno marcas with [who-padre = [who] of myself]
        in-cone movimiento-por-tic arco

      ifelse any? marcas-terreno
      [
        set caminos-conocidos lput heading caminos-conocidos
      ]
      [
        set caminos-nuevos lput heading caminos-nuevos
      ]
    ]
    rt arco + ((random 60) - 30)
  ]

  ifelse empty? caminos-nuevos
  [
    if not empty? caminos-conocidos
    [
      let camino-elegido one-of caminos-conocidos
      set heading camino-elegido
      random-seed new-seed
      jump random movimiento-por-tic
    ]
    ;; si no hay donde moverse no se mueva
  ]
  [
    ifelse empty? caminos-conocidos
    [
      let camino-elegido one-of caminos-nuevos
      set heading camino-elegido
    ]
    [
      random-seed new-seed
      let p random-float 1
      ifelse p < prob-exploracion
      [
        let camino-elegido one-of caminos-nuevos
        set heading camino-elegido
      ]
      [
        let camino-elegido one-of caminos-conocidos
        set heading camino-elegido
      ]
    ]
  ]


  jump movimiento-por-tic

  R-pintar-parcela-actual
  R-dejar-marca

  R-revisar-amenazas
end

to R-dejar-marca
  hatch-marcas 1 [
    ask other marcas-here[die]
    set color [color] of myself
    set edad 0
    set size 5
    set who-padre [who] of myself
    set label ""
  ]
end


to R-conflicto
  ;;Lo pongo antes de que se decida el resultado del conflicto porque me parece que, en caso de que el conflicto dura más de un tick
  ;;debería perderse más peso que si sólo dura un tick.
  let pesoPerdido pesoInicial * (CostoMovPorTic / 100)
  set pesoPerdido pesoPerdido + 2
  set peso peso - pesoPerdido

    ask otro-en-conflicto [set peso peso - [pesoPerdido] of myself]
  let probContinue random-float 1
  ifelse probContinue > probConflictoContinue
  [

    ;;Se define el ganador con una probabilidad basada en el peso de la rana
    let sumaPesos peso +  [peso] of otro-en-conflicto
    let probGana random sumaPesos
    ifelse probGana <= peso
    [
      ;; Ganó la rana que está ejecutando en el momento, definir consecuencias por ganar
      print "ganó el agente: "
      print who

      set agentes-conflictos-previos lput [who] of otro-en-conflicto agentes-conflictos-previos
      ;; Se le pide a la rana que perdió que almacene el id de la rana ganadora
      ask otro-en-conflicto
      [
        set agentes-conflictos-previos lput [who] of myself agentes-conflictos-previos
        set agentes-amenaza lput [who] of myself agentes-amenaza
        set label (word who " " agentes-amenaza)
        print agentes-amenaza
      ]
    ]
    [
      ;; Ganó la otra rana, definir consecuencias por perder
      print "ganó el agente: "
      print [who] of otro-en-conflicto

      set agentes-conflictos-previos lput [who] of otro-en-conflicto agentes-conflictos-previos
      ask otro-en-conflicto
      [
        set agentes-conflictos-previos lput [who] of myself agentes-conflictos-previos
      ]
      ;; Se le pide a la rana que perdió que almacene el id de la rana ganadora
      set agentes-amenaza lput [who] of otro-en-conflicto agentes-amenaza
      set label (word who " " agentes-amenaza)
      print agentes-amenaza
    ]
    ;; TODO: esto hay que reepensarlo luego de que implementemos los "castigos"
    ;; luego de una pelea
    set estado-actual movimiento
    ask otro-en-conflicto
    [
      set estado-actual movimiento
    ]
  ]
  [
    print "Se mantiene el conflicto al menos durante un tic más"
  ]
end

to R-revisar-amenazas
  ;;******************************************************************************************
  ;; Muevo esto para otro método para que se ejecute luego de que las ranas se muevan, sino,
  ;; luego de cada conflicto siguen apareciendo las mismas amenazas
  ;; ese comportamiento sucede porque no teníamos una lista guardada con los conflictos previos,
  ;; sea que se ganaron o no, entonces por eso se repetían
  ;;*******************************************************************************************


  ;;Lo siguiente revisa que la rana que se mueva, no está en la lista de amenaza de las ranas cercanas.
    let posibles-agentes-conflicto (other ranas in-radius radioDeteccionConflicto) with [not R-en-lista [agentes-conflictos-previos] of myself who]

    ;;***************************************************************************************************
    ;; Y si la siguiente comparación la hacemos con un OR, en vez de un AND, para dejar la posibilidad de
    ;; que yo vuelva a pelear con una rana con la que perdí??
    ;; Sólo pregunto
    ;;
    ;; es una AND porque si lo dejamos en OR y la lista está vacía el programa se cae porque no encuentra
    ;; el min-one-of posibles-agentes-conflicto [distance myself]
    ;;
    ;; TODO: preguntarle a los biologos si luego que la rana pierde conflicto no se puede enfrentar entre
    ;; ellos de nuevo
    ;;***************************************************************************************************
    if any? posibles-agentes-conflicto and (random-float 1) < probConflicto
    [
      print "conflicto iniciado por "
      print who
      set estado-actual conflicto
      set otro-en-conflicto  min-one-of posibles-agentes-conflicto [distance myself]
      ask otro-en-conflicto
      [
        print "con el agente "
        print who
        set estado-actual conflicto
        set otro-en-conflicto myself
      ]
    ]
end


to-report R-en-lista [lista a]
  let enLista? member? a lista
  report enLista?
end


;;*******************************
;; Definición de agentes parcela:
;;*******************************
patches-own
[
  colorActual
  tiempoColor
]

to P-init
  set colorActual -1
  set tiempoColor -1
end

to P-update
  ifelse colorActual = -1
  [
    set pcolor white
  ]
  [
    ifelse tiempoColor = 0
    [
      set colorActual -1
      set tiempoColor -1
    ]
    [
      set pcolor scale-color colorActual tiempoColor (4 * tiempo-vida-marca) 0
      set tiempoColor tiempoColor - 1
    ]
  ]
end

;;***************************************
;; Definición de agentes vínculo (links):
;;***************************************

links-own ;; Para definir los atributos de los links o conexiones.
[

]

to L-init ;; Para inicializar un link o conexión a la vez.

end
@#$#@#$#@
GRAPHICS-WINDOW
425
10
1126
732
230
230
1.5
1
14
1
1
1
0
0
0
1
-230
230
-230
230
0
0
1
ticks
30.0

BUTTON
141
51
204
84
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
141
11
204
44
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
227
101
399
134
cantidad-ranas
cantidad-ranas
1
14
14
1
1
NIL
HORIZONTAL

BUTTON
131
89
206
122
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
31
201
203
234
ProbPesoPorHora
ProbPesoPorHora
0
10
3.5
0.1
1
NIL
HORIZONTAL

SLIDER
31
279
203
312
UmbralDesnutricion
UmbralDesnutricion
0
1
0.23
0.01
1
NIL
HORIZONTAL

SLIDER
31
315
203
348
UmbralRecuperacion
UmbralRecuperacion
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
25
239
203
272
CostoMovPorTic
CostoMovPorTic
0
20
2.8
0.1
1
NIL
HORIZONTAL

SLIDER
228
146
400
179
movimiento-por-tic
movimiento-por-tic
0
200
10
1
1
NIL
HORIZONTAL

SLIDER
227
56
399
89
tiempo-vida-marca
tiempo-vida-marca
0
100
50
1
1
NIL
HORIZONTAL

TEXTBOX
227
10
428
66
Cantidad de tics para que la marca se borre, el color va desvaneciendo conforme los tics
11
0.0
1

SLIDER
220
242
400
275
radioDeteccionConflicto
radioDeteccionConflicto
0
100
26
1
1
NIL
HORIZONTAL

SLIDER
25
409
197
442
probConflicto
probConflicto
0
1
0.573
0.001
1
NIL
HORIZONTAL

INPUTBOX
12
19
109
79
ticsMax
1000
1
0
String

SLIDER
16
518
198
551
probConflictoContinue
probConflictoContinue
0
1
0.1
1
1
NIL
HORIZONTAL

SLIDER
228
198
400
231
prob-exploracion
prob-exploracion
0
1
0.72
0.01
1
NIL
HORIZONTAL

PLOT
214
339
414
489
Peso promedio de las ranas
Tics
Peso Promedio
0.0
1000.0
0.0
35.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [peso] of ranas"

PLOT
18
571
218
721
Peso máximo y mínimo de las Ranas
Tics
Peso
0.0
1000.0
0.0
35.0
true
false
"" ""
PENS
"default" 1.0 0 -14070903 true "" "plot max [peso] of ranas"
"pen-1" 1.0 0 -12087248 true "" "plot min [peso] of ranas"

@#$#@#$#@
## ¿DE QUÉ SE TRATA?

(una descripción general de lo que el modelo trata de modelar o explicar)

## ¿CÓMO FUNCIONA?

(qué reglas usan los agentes para orginar el funcionamiento del modelo)

## ¿CÓMO USARLO?

(cómo usar el modelo, incluye una descripción de cada uno de los controles en la interfaz)

## ¿QUÉ TOMAR EN CUENTA?

(cosas que debe tener en cuenta el usuario al ejecutar el modelo)

## ¿QUÉ PROBAR?

(sugerencias para el usuario sobre qué pruebas realizar (mover los "sliders", los "switches", etc.) con el modelo)

## EXTENDIENDO EL MODELO

(sugerencias sobre cómo realizar adiciones o cambios en el código del modelo para hacerlo más complejo, detallado, preciso, etc.)

## CARACTERÍSTICAS NETLOGO

(características interesantes o inusuales de NetLogo que usa el modelo, particularmente de código; o cómo se logra implementar características inexistentes)

## MODELOS RELACIONADOS

(otros modelos de interés disponibles en la Librería de Modelos de NetLogo o en otros repositorios de modelos)

## CRÉDITOS AND REFERENCIAS

(referencia a un URL en Internet si es que el modelo tiene una, así como los créditos necesarios, citas y otros hipervínculos)

## ODD - ESPECIFICACIÓN DETALLADA DEL MODELO

## Título
(nombre del modelo)

## Autores
(nombre de los autores del modelo)

## Visión
## 1  Objetivos:
( 1.1  )
## 2  Entidades, variables de estado y escalas:
( 2.1 )
## 3  Visión del proceso y programación:
( 3.1  )

## Conceptos del diseño
## 4  Propiedades del modelo:
##  4.1  Básicas:
()
##  4.2  Emergentes:
()
##  4.3  Adaptabilidad:
()
##  4.4  Metas:
()
##  4.5  Aprendizaje:
()
##  4.6  Predictibilidad:
()
##  4.7  Sensibilidad:
()
##  4.8  Interacciones:
()
##  4.9  Estocasticidad:
()
##  4.10  Colectividades:
()
##  4.11  Salidas:
()
## Detalles
##  5  Inicialización:
()
##  6  Datos de entrada:
()
##  7  Submodelos:
()
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -7500403 true true 135 285 195 285 270 90 30 90 105 285
Polygon -7500403 true true 270 90 225 15 180 90
Polygon -7500403 true true 30 90 75 15 120 90
Circle -1 true false 183 138 24
Circle -1 true false 93 138 24

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
