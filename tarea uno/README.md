# Tarea uno — punto flotante y decisiones financieras

Investigación experimental reproducible que responde:

> ¿Puede el uso de `Float32` en lugar de `Float64` cambiar las decisiones producidas por un algoritmo financiero basado en comparaciones numéricas?

El entregable principal es [`floating_point_finance.jl`](floating_point_finance.jl), un notebook interactivo de Pluto.jl. Incluye experimentos de representabilidad, medias móviles, búsqueda automática de un cambio de señal, Monte Carlo, sensibilidad al umbral y a la escala, contraste con `Float16`, referencia `BigFloat`, seis gráficas y una validación secundaria con datos financieros reales locales.

## Requisitos

- Julia 1.10.12 LTS (recomendada; también es compatible con Julia 1.10.x posterior).
- Conexión a Internet solo durante la primera instalación de paquetes. Los experimentos y los datos incluidos funcionan después sin conexión.

## Ejecutar

Desde esta carpeta:

```julia
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pluto; Pluto.run(notebook="floating_point_finance.jl")'
```

También puede abrirse Julia con `julia --project=.` y ejecutar:

```julia
using Pluto
Pluto.run(notebook="floating_point_finance.jl")
```

## Validar sin interfaz

```julia
julia --project=. test/runtests.jl
```

La prueba incluye el notebook completo, comprueba tipos, ventanas, finitud, reproducibilidad, el caso controlado y la correspondencia de las seis gráficas con los datos calculados.

## Archivos

```text
tarea uno/
├── README.md
├── Project.toml
├── Manifest.toml                 # generado al resolver el entorno
├── floating_point_finance.jl     # notebook Pluto
├── data/
│   └── dexuseu_2025_h1.csv       # copia local; FRED, USD por euro
└── test/
    └── runtests.jl
```

## Reproducibilidad y alcance

- Todas las simulaciones usan semillas explícitas.
- Las tablas y cifras se calculan: no contienen resultados transcritos manualmente.
- La serie real es una validación secundaria. Su procedencia y fecha de descarga están documentadas en el propio CSV y en el notebook.
- El notebook está identificado a nombre de **Mateo Gabriel Gonzalez Lara** para la materia **Analisis Numerico**.
