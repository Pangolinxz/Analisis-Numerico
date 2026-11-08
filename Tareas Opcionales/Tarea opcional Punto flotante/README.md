# Tarea opcional: punto flotante

## Siete problemas resueltos en Julia

Esta carpeta contiene la entrega reproducible de siete problemas sobre representación, redondeo, cancelación, estabilidad y medición de rendimiento. El sustento matemático principal es Kincaid y Cheney, *Numerical Analysis: Mathematics of Scientific Computing* (2002), especialmente las secciones 1.1, 1.3 y 2.1–2.3 de la edición suministrada para el trabajo.

## Entregables

- `PuntoFlotante_Julia_final.ipynb`: cuaderno Jupyter final. Sus 13 celdas de código fueron ejecutadas con Julia 1.10.5; conserva resultados, tablas, comprobaciones y cuatro gráficas.
- `PuntoFlotante_Julia_final.jl`: versión interactiva para Pluto.
- `PuntoFlotante_Julia_final.html`: exportación estática de Pluto para revisar el trabajo sin instalar Julia.
- `PuntoFlotante_Julia_avance.ipynb`: avance recibido, conservado como referencia y rotulado con el título uniforme de la tarea.
- `Project.toml` y `Manifest.toml`: entorno exacto de Julia.
- `run_pluto.jl`: lanzador que abre directamente el cuaderno final.
- `test/runtests.jl`: 81 comprobaciones independientes de los resultados centrales.
- `scripts/`: scripts de construcción conservados para dejar trazabilidad.

El PDF del libro no se copia al repositorio porque fue suministrado como material externo y podría tener restricciones de redistribución. Las páginas y secciones usadas están citadas dentro del cuaderno.

## Abrir la entrega rápidamente

La forma más sencilla es abrir `PuntoFlotante_Julia_final.html` en un navegador. Esa versión permite leer todas las soluciones y resultados, aunque no recalcula las celdas.

Para trabajar de forma interactiva con Pluto, abre PowerShell en esta carpeta y ejecuta:

```powershell
julia --project=. -e 'import Pkg; Pkg.instantiate()'
julia --project=. run_pluto.jl
```

Pluto iniciará un servidor local y normalmente abrirá el cuaderno en `http://localhost:1234/`. Para detenerlo, vuelve a la terminal y presiona `Ctrl+C`.

Si el comando `julia` no está registrado en `PATH`, en este equipo se puede usar:

```powershell
& 'C:\Users\gabla\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe' --project=. run_pluto.jl
```

## Reproducir el cuaderno Jupyter

Después de instanciar el entorno, inicia Jupyter desde esta carpeta y abre `PuntoFlotante_Julia_final.ipynb` con el kernel Julia 1.10:

```powershell
jupyter notebook
```

También se puede volver a ejecutar de forma no interactiva:

```powershell
jupyter execute PuntoFlotante_Julia_final.ipynb --inplace --kernel_name=julia-1.10 --timeout=600
```

Los tiempos de los benchmarks dependen del computador y de la carga del sistema, por lo que es normal que cambien al repetirlos. El cuaderno usa `BenchmarkTools` para separar el tiempo de compilación de las mediciones repetidas.

## Verificación realizada

- Jupyter: 13 de 13 celdas de código ejecutadas, cero salidas de error y 10 de 10 comprobaciones finales aprobadas.
- Pluto: 24 celdas evaluadas, cero celdas con error y exportación HTML correcta.
- Pruebas independientes: 81 de 81 comprobaciones aprobadas con Julia.
- Problema 2: se confirmó la rama `1/2 -> 1`; para `x0 = 1/10`, `x50` exacto es `0.4` y el cálculo `Float64` produce `0.40625`.
- Problema 4: la expresión directa empieza a devolver cero en `x = 8^-9`.
- Problema 6: se separó la correlación de los errores iniciales de la perturbación local producida por las operaciones redondeadas.

## Fuentes técnicas

- [Números enteros y de punto flotante — documentación oficial de Julia](https://docs.julialang.org/en/v1/manual/integers-and-floating-point-numbers/)
- [Manual oficial de BenchmarkTools.jl](https://juliaci.github.io/BenchmarkTools.jl/stable/manual/)
- [Cómo iniciar Pluto](https://plutojl.org/en/docs/launch-pluto/)
