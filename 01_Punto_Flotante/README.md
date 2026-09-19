# Trabajo 01 — Cuando unos decimales cambian una decisión

Investigación sobre aritmética de punto flotante y cruces de medias móviles.

> **Pregunta:** ¿Puede el uso de `Float32` en lugar de `Float64` cambiar las decisiones producidas por un algoritmo financiero basado en comparaciones numéricas?

El trabajo sigue el recorrido pedido en clase: intuición inicial, pregunta, predicción, experimento reproducible, evidencia, explicación y transformación de la comprensión. Compara `Float16`, `Float32`, `Float64` y una referencia `BigFloat`; incluye tablas, seis gráficas, controles interactivos, simulaciones con semilla fija y una comprobación secundaria con datos de FRED integrados en el notebook.

## Entregables

- [`floating_point_finance.jl`](floating_point_finance.jl): cuaderno interactivo y reproducible de Pluto.
- [`floating_point_finance.html`](floating_point_finance.html): versión estática lista para leer en el navegador.
- [`Entrega_Punto_Flotante.zip`](Entrega_Punto_Flotante.zip): copia comprimida opcional de los entregables.

Para una revisión rápida, abra primero el archivo HTML. Para explorar los controles y volver a ejecutar los cálculos, utilice el cuaderno de Pluto.

## Ejecutar en Windows

La primera vez, abra Julia e instale Pluto:

```julia
import Pkg
Pkg.add("Pluto")
```

Después inicie Pluto:

```julia
import Pluto
Pluto.run()
```

En la interfaz, seleccione `floating_point_finance.jl`. El notebook contiene su propio entorno y los datos necesarios.

## Presentación y exportación

- Presentación: `Share → Slideshow`.
- Exportación: `Share → Static HTML`.

## Validación opcional

Desde esta carpeta puede ejecutarse:

```powershell
julia --project=. test/runtests.jl
```

Las pruebas verifican los tipos `Float32` y `Float64`, la reproducibilidad, el caso controlado, los extremos de los controles y la generación de tablas y gráficas.

## Archivos de apoyo

- `Project.toml` y `Manifest.toml`: entorno utilizado para validar el trabajo.
- `data/dexuseu_2025_h1.csv`: copia de respaldo de la serie DEXUSEU; los datos también están integrados en el notebook.
- `test/runtests.jl`: pruebas automatizadas del experimento.
