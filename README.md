# Análisis Numérico

Repositorio académico de **Mateo Gabriel Gonzalez Lara** para reunir ejercicios, experimentos y entregables de la materia Análisis Numérico.



## Trabajos disponibles

| N.º | Tema | Estado | Acceso |
|---:|---|---|---|
| 01 | Aritmética de punto flotante y decisiones financieras | Completo | [Carpeta del trabajo](01_Punto_Flotante/) · [Cuaderno Pluto](01_Punto_Flotante/floating_point_finance.jl) · [Versión HTML](01_Punto_Flotante/floating_point_finance.html) |
| 02 | Newton, raíces múltiples y precisión finita | Completo | [Carpeta del trabajo](02_EcuacionesNo_Lineales/) · [Cuaderno Pluto](02_EcuacionesNo_Lineales/newton_multiple_roots.jl) · [Versión HTML](02_EcuacionesNo_Lineales/newton_multiple_roots.html) |

## Tareas opcionales

| Tema | Estado | Acceso |
|---|---|---|
| Tarea opcional: método de Shamanskii y ecuaciones no lineales | Completo y verificado | [Instrucciones](Tareas%20Opcionales/Tarea%20opcional%20Ecuaciones%20lineales/) · [Pluto](Tareas%20Opcionales/Tarea%20opcional%20Ecuaciones%20lineales/shamanskii_ecuacion_no_lineal.jl) · [HTML](Tareas%20Opcionales/Tarea%20opcional%20Ecuaciones%20lineales/shamanskii_ecuacion_no_lineal.html) |
| Tarea opcional: punto flotante | Completo y verificado | [Instrucciones y entregables](Tareas%20Opcionales/Tarea%20opcional%20Punto%20flotante/) · [Jupyter](Tareas%20Opcionales/Tarea%20opcional%20Punto%20flotante/PuntoFlotante_Julia_final.ipynb) · [Pluto](Tareas%20Opcionales/Tarea%20opcional%20Punto%20flotante/PuntoFlotante_Julia_final.jl) · [HTML](Tareas%20Opcionales/Tarea%20opcional%20Punto%20flotante/PuntoFlotante_Julia_final.html) |

## Posibles ejercicios de la materia

El repositorio crecerá a medida que avance el curso. Algunos temas que podrían convertirse en próximos ejercicios son:

- **Error, estabilidad y condicionamiento:** distinguir el error propio de los datos del error introducido por un algoritmo.
- **Búsqueda de raíces:** comparar bisección, Newton y secante en velocidad, robustez y sensibilidad a la condición inicial.
- **Sistemas de ecuaciones lineales:** estudiar eliminación gaussiana, factorizaciones y el efecto del condicionamiento de una matriz.
- **Interpolación y aproximación:** observar cuándo un polinomio aproxima bien y cuándo aparecen oscilaciones como el fenómeno de Runge.
- **Derivación e integración numérica:** medir el equilibrio entre error de truncamiento y error de redondeo.
- **Ecuaciones diferenciales ordinarias:** comparar métodos de Euler y Runge–Kutta, estabilidad y elección del tamaño de paso.
- **Valores propios y métodos iterativos:** explorar convergencia, costo computacional y criterios de parada.

Estos temas son una guía inicial, no trabajos ya realizados. Cada nueva entrega tendrá su propia carpeta y su propio README.

## Organización

```text
Analisis-Numerico/
├── README.md
├── 01_Punto_Flotante/
│   ├── README.md
│   ├── floating_point_finance.jl
│   ├── floating_point_finance.html
│   ├── Project.toml
│   ├── Manifest.toml
│   ├── data/
│   └── test/
├── 02_EcuacionesNo_Lineales/
│   ├── README.md
│   ├── newton_multiple_roots.jl
│   ├── newton_multiple_roots.html
│   └── test/
└── Tareas Opcionales/
    ├── Tarea opcional Ecuaciones lineales/
    │   ├── README.md
    │   ├── shamanskii_ecuacion_no_lineal.jl
    │   ├── shamanskii_ecuacion_no_lineal.html
    │   └── test/
    └── Tarea opcional Punto flotante/
        ├── README.md
        ├── PuntoFlotante_Julia_final.ipynb
        ├── PuntoFlotante_Julia_final.jl
        ├── PuntoFlotante_Julia_final.html
        └── test/
```

Los archivos `.jl` son los cuadernos reproducibles; los archivos `.html` permiten revisar los resultados directamente desde el navegador.
