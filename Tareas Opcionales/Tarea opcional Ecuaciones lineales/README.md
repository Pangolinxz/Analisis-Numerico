# Tarea opcional: método de Shamanskii y ecuaciones no lineales

Esta carpeta contiene la solución reproducible de dos problemas de ecuaciones no lineales: la implementación escalar del método de Shamanskii de orden configurable y el cálculo de la tasa `ω` en el modelo del plano inclinado.

El nombre de la carpeta se conserva según la organización solicitada para el repositorio, aunque las ecuaciones resueltas son no lineales.

## Entregables

- `shamanskii_ecuacion_no_lineal.jl`: cuaderno interactivo de Pluto y fuente principal.
- `shamanskii_ecuacion_no_lineal.html`: versión estática ejecutada, con tablas, gráficas y resultados.
- `Project.toml` y `Manifest.toml`: entorno reproducible de Julia.
- `run_pluto.jl`: abre directamente el cuaderno en el navegador.
- `test/runtests.jl`: comprobaciones independientes de los algoritmos y resultados.
- `scripts/build_notebook.jl`: generador conservado para dar trazabilidad al cuaderno.

## Resultados principales

- Para `f(x)=cos(x)-x`, todos los valores `m=1,…,10` convergen a `0.7390851332151607` desde `x₀=0.5`.
- `m=1` reproduce el método de Newton.
- Al aumentar `m`, disminuyen inicialmente las actualizaciones de la derivada, pero crece la cantidad de pasos de cuerda. En la ejecución guardada, el menor tiempo mediano se observó en `m=4`; este valor depende del computador y de la función estudiada.
- La segunda ecuación tiene una única raíz positiva y el resultado certificado es:

  ```text
  ω = 0.612142570703
  ```

## Cómo abrir Pluto

Abre PowerShell en esta carpeta y ejecuta:

```powershell
julia --project=. -e 'import Pkg; Pkg.instantiate()'
julia --project=. run_pluto.jl
```

Pluto abrirá normalmente `http://127.0.0.1:1234/`. Para detenerlo, vuelve a la terminal y presiona `Ctrl+C`.

En este computador también se puede usar la ruta completa de Julia:

```powershell
& 'C:\Users\gabla\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe' --project=. run_pluto.jl
```

## Ver la entrega sin ejecutar Julia

Abre `shamanskii_ecuacion_no_lineal.html` en cualquier navegador. El HTML conserva las salidas y gráficas de la ejecución validada.

## Ejecutar las pruebas

Desde esta carpeta:

```powershell
julia --project=. test/runtests.jl
```

## Fuentes

- C. T. Kelley, *Iterative Methods for Linear and Nonlinear Equations*, SIAM, 1995, §5.4.3.
- A. Quarteroni, F. Saleri y P. Gervasio, *Scientific Computing with MATLAB and Octave*, Springer.
- [Cuaderno de ecuaciones no lineales del Laboratorio de Matemáticas](https://labmatecc.github.io/Notebooks/AnalisisNumerico/EcuacionesNoLineales/).
- [Manual de BenchmarkTools.jl](https://juliaci.github.io/BenchmarkTools.jl/stable/manual/).
