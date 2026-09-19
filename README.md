# Análisis Numérico

Repositorio académico de **Mateo Gabriel Gonzalez Lara** para reunir ejercicios, experimentos y entregables de la materia Análisis Numérico.



## Trabajos disponibles

| N.º | Tema | Estado | Acceso |
|---:|---|---|---|
| 01 | Aritmética de punto flotante y decisiones financieras | Completo | [Carpeta del trabajo](01_Punto_Flotante/) · [Cuaderno Pluto](01_Punto_Flotante/floating_point_finance.jl) · [Versión HTML](01_Punto_Flotante/floating_point_finance.html) |

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
└── 01_Punto_Flotante/
    ├── README.md
    ├── floating_point_finance.jl
    ├── floating_point_finance.html
    ├── Project.toml
    ├── Manifest.toml
    ├── data/
    └── test/
```

Los archivos `.jl` son los cuadernos reproducibles; los archivos `.html` permiten revisar los resultados directamente desde el navegador.
