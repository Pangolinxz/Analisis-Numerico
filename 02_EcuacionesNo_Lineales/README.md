# Newton ante raíces múltiples

Este trabajo estudia cómo la multiplicidad de una raíz cambia la convergencia y los criterios de parada del método de Newton, y cómo esos efectos interactúan con `Float16`, `Float32` y `Float64`.

## Archivos de la entrega

- `newton_multiple_roots.jl`: cuaderno interactivo de Pluto y fuente principal.
- `newton_multiple_roots.html`: versión estática para leer en el navegador sin instalar Julia (se genera al validar la entrega).
- `Project.toml` y `Manifest.toml`: entorno reproducible.
- `test/runtests.jl`: validaciones automáticas de algoritmos, tipos y resultados.

## Cómo abrir el cuaderno en Windows

1. Instala [Julia](https://julialang.org/downloads/) si aún no está instalada.
2. Abre Julia y ejecuta una sola vez:

   ```julia
   import Pkg
   Pkg.add("Pluto")
   ```

3. Inicia Pluto:

   ```julia
   import Pluto
   Pluto.run()
   ```

4. En la pantalla de Pluto, pulsa **Open a notebook** y abre:

   ```text
   02_EcuacionesNo_Lineales/newton_multiple_roots.jl
   ```

El cuaderno contiene su propio entorno de paquetes. La primera ejecución puede tardar unos minutos mientras Julia prepara las dependencias.

Como alternativa, desde PowerShell dentro de esta carpeta puedes abrir el cuaderno directamente con:

```powershell
julia --project=. run_pluto.jl
```

## Cómo exportarlo a HTML

Con el cuaderno abierto y todas las celdas ejecutadas, ve a **Share** (esquina superior derecha), elige **Static HTML** y luego **Download HTML file**. El HTML conserva los resultados y puede abrirse sin Julia; los controles quedan como una instantánea y para modificarlos debe abrirse el archivo `.jl` en Pluto.

## Cómo reproducir y validar desde PowerShell

Desde esta carpeta:

```powershell
julia --project=. -e 'import Pkg; Pkg.instantiate()'
julia --project=. test/runtests.jl
```

No se usan datos externos, rutas absolutas ni números aleatorios. Todas las tablas, razones y gráficas se calculan al ejecutar el cuaderno.

## Guía breve para la sustentación

La idea central se defiende en tres pasos: para una raíz de multiplicidad `m`, Newton estándar tiene razón asintótica de error `(m-1)/m`; el Newton modificado cancela ese efecto en esta familia; y un residuo pequeño no mide el error de la misma forma cuando `f(x)` se aplana cerca de una raíz múltiple. La sección final del cuaderno reúne las conclusiones y las comprobaciones experimentales.
