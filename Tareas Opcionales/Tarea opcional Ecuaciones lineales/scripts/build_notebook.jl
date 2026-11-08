using UUIDs

const ROOT = normpath(joinpath(@__DIR__, ".."))
const OUTPUT = joinpath(ROOT, "shamanskii_ecuacion_no_lineal.jl")

cell_blocks = String[]
cell_order = String[]

function markdown_expression(source::AbstractString)
    occursin("\"\"\"", source) && error("Una celda Markdown contiene comillas triples")
    "Markdown.parse(raw\"\"\"\n$(source)\n\"\"\")"
end

function add_cell!(source::AbstractString; markdown=false, id=string(uuid4()))
    expression = markdown ? markdown_expression(source) : "begin\n$(source)\nend"
    push!(cell_blocks, "# ╔═╡ $(id)\n$(expression)\n")
    push!(cell_order, (markdown ? "# ╟─" : "# ╠═") * id)
end

setup_source = raw"""ENV["GKSwstype"] = "100"

using BenchmarkTools
using Dates
using InteractiveUtils
using Plots
using PlutoUI
using Printf
using Statistics

gr()
default(size=(820, 450), linewidth=2.2, framestyle=:box, legend=:best)
"""

add_cell!(raw"""# Tarea opcional: método de Shamanskii y ecuaciones no lineales

## Implementación, verificación, tiempos y aplicación

**Autor:** Mateo Gabriel González Lara. **Curso:** Análisis Numérico.

Esta entrega resuelve los dos problemas propuestos en el cuaderno de ecuaciones no lineales del Laboratorio de Matemáticas: la implementación escalar del método de Shamanskii de orden $m$ y el cálculo de la tasa $\omega$ en el modelo del plano inclinado.

Los resultados, gráficas y mediciones de tiempo fueron producidos por Julia. El entorno exacto está registrado en `Project.toml` y `Manifest.toml`.
"""; markdown=true)

add_cell!(setup_source)

add_cell!("TableOfContents(title=\"Contenido\", indent=true, depth=3, aside=true)")

add_cell!(raw"""## Objetivos y criterio de verificación

El trabajo busca responder cuatro preguntas concretas:

1. ¿Cómo se implementa el método de Shamanskii permitiendo que el usuario elija $m$?
2. ¿El código converge a una raíz conocida y reproduce a Newton cuando $m=1$?
3. ¿Cómo cambia el tiempo de cálculo al aumentar $m$?
4. ¿Cuál es el valor de $\omega$ que produce un desplazamiento de un metro en un segundo, con 12 cifras decimales verificadas?

Para no confundir compilación con tiempo del algoritmo, las mediciones se hacen después de un calentamiento y mediante repeticiones de `BenchmarkTools`. Para el segundo problema se usa una referencia `BigFloat` de 256 bits y un intervalo obtenido por bisección.
"""; markdown=true)

add_cell!(raw"""# Problema 1. Método de Shamanskii de orden $m$

## Enunciado

Dado $x_n$, se calcula una derivada y se mantiene congelada durante $m$ correcciones:

```math
z_1=x_n-\frac{f(x_n)}{f'(x_n)},
```

```math
z_{j+1}=z_j-\frac{f(z_j)}{f'(x_n)},\qquad 1\le j\le m-1,
```

```math
x_{n+1}=z_m.
```

Cuando $m=1$ se obtiene exactamente el método de Newton. Para $m>1$, la primera corrección es de Newton y las siguientes son pasos de cuerda que reutilizan $f'(x_n)$. Kelley señala que esta alternancia produce un método de orden local $m+1$ bajo las hipótesis usuales de suavidad, raíz simple y punto inicial suficientemente cercano.

El ahorro potencial aparece cuando evaluar o factorizar la derivada es más costoso que evaluar $f$: se hacen $m$ correcciones por cada actualización de la derivada. Sin embargo, aumentar $m$ también añade evaluaciones y puede dejar de ser beneficioso.
"""; markdown=true)

add_cell!(raw"""function shamanskii(f, df, x0; m::Integer=1, atol=1e-14, rtol=0.0,
                     max_outer::Integer=50, guardar_historial::Bool=true)
    m >= 1 || throw(ArgumentError("m debe ser al menos 1"))
    max_outer >= 1 || throw(ArgumentError("max_outer debe ser positivo"))
    atol >= 0 || throw(ArgumentError("atol debe ser no negativo"))
    rtol >= 0 || throw(ArgumentError("rtol debe ser no negativo"))

    x = float(x0)
    fx = f(x)
    isfinite(fx) || throw(DomainError(fx, "f(x₀) no es finito"))

    evaluaciones_f = 1
    evaluaciones_df = 0
    pasos_cuerda = 0
    residuo_inicial = abs(fx)
    umbral = atol + rtol * residuo_inicial
    historial = guardar_historial ?
        [(ciclo=0, x=x, residuo=abs(fx), pasos=0)] : nothing

    if abs(fx) <= umbral
        return (root=x, converged=true, outer_iterations=0,
                chord_steps=0, f_evals=evaluaciones_f,
                df_evals=evaluaciones_df, residual=abs(fx), history=historial)
    end

    for ciclo in 1:max_outer
        dfx = df(x)
        evaluaciones_df += 1
        isfinite(dfx) || throw(DomainError(dfx, "f'(x) no es finita"))
        iszero(dfx) && throw(DomainError(dfx, "f'(x) es cero"))

        z = x
        for j in 1:m
            fz = if j == 1
                fx
            else
                evaluaciones_f += 1
                f(z)
            end
            isfinite(fz) || throw(DomainError(fz, "f(z) no es finita"))
            z -= fz / dfx
            pasos_cuerda += 1
        end

        x = z
        fx = f(x)
        evaluaciones_f += 1
        isfinite(fx) || throw(DomainError(fx, "f(x) no es finito"))

        if guardar_historial
            push!(historial, (ciclo=ciclo, x=x, residuo=abs(fx), pasos=pasos_cuerda))
        end

        if abs(fx) <= umbral
            return (root=x, converged=true, outer_iterations=ciclo,
                    chord_steps=pasos_cuerda, f_evals=evaluaciones_f,
                    df_evals=evaluaciones_df, residual=abs(fx), history=historial)
        end
    end

    return (root=x, converged=false, outer_iterations=max_outer,
            chord_steps=pasos_cuerda, f_evals=evaluaciones_f,
            df_evals=evaluaciones_df, residual=abs(fx), history=historial)
end
""")

add_cell!(raw"""## Verificación con una ecuación escalar

Se escoge

```math
f(x)=\cos x-x,\qquad f'(x)=-\sin x-1.
```

con $x_0=0.5$. Como $f'(x)=-\sin x-1\le0$ para todo $x$ y solo se anula en puntos aislados, $f$ es estrictamente decreciente. Además, $f(0)>0$ y $f(1)<0$; por continuidad existe una única raíz real en $(0,1)$. Una referencia calculada con 256 bits es

```math
x^*=0.73908513321516064165\ldots
```

La tabla compara órdenes $m=1,\ldots,10$. Se reportan ciclos externos, pasos de cuerda, evaluaciones y error frente a la referencia. La columna de derivadas permite ver directamente qué se ahorra al reutilizar $f'(x_n)$.
"""; markdown=true)

add_cell!(raw"""f_prueba(x) = cos(x) - x
df_prueba(x) = -sin(x) - one(x)

raiz_referencia = setprecision(BigFloat, 256) do
    r = BigFloat("0.7")
    for _ in 1:20
        r -= (cos(r) - r) / (-sin(r) - 1)
    end
    r
end

resultados_m = [shamanskii(f_prueba, df_prueba, 0.5; m=m, atol=1e-14) for m in 1:10]

println(" m  ciclos  pasos  eval f  eval f'      raíz calculada          |error|")
for (m, r) in enumerate(resultados_m)
    error = abs(BigFloat(r.root) - raiz_referencia)
    @printf("%2d  %6d  %5d  %6d  %7d  %.16f  %.3e\n",
            m, r.outer_iterations, r.chord_steps, r.f_evals,
            r.df_evals, r.root, Float64(error))
end

@assert all(r.converged for r in resultados_m)
@assert resultados_m[1].root == shamanskii(f_prueba, df_prueba, 0.5; m=1).root
@assert all(abs(BigFloat(r.root) - raiz_referencia) < big"2e-14" for r in resultados_m)
""")

add_cell!(raw"""grafica_convergencia = plot(
    xlabel="pasos de cuerda acumulados",
    ylabel="|f(x)|",
    yscale=:log10,
    title="Convergencia de Shamanskii para cos(x)-x",
)

for m in 1:6
    h = resultados_m[m].history
    plot!(grafica_convergencia,
          [fila.pasos for fila in h],
          max.([fila.residuo for fila in h], eps(Float64));
          marker=:circle, label="m=$m")
end

display(grafica_convergencia)
""")

add_cell!(raw"""## Exploración interactiva

El control permite elegir el orden $m$. Debajo se muestran la aproximación, el residuo y el número de evaluaciones correspondientes.
"""; markdown=true)

add_cell!("@bind m_usuario Slider(1:12; default=3, show_value=true)")

add_cell!(raw"""resultado_usuario = shamanskii(f_prueba, df_prueba, 0.5; m=m_usuario, atol=1e-14)

(
    m=m_usuario,
    raíz=resultado_usuario.root,
    residuo=resultado_usuario.residual,
    ciclos_externos=resultado_usuario.outer_iterations,
    pasos_de_cuerda=resultado_usuario.chord_steps,
    evaluaciones_f=resultado_usuario.f_evals,
    evaluaciones_derivada=resultado_usuario.df_evals,
)
""")

add_cell!(raw"""## ¿Cómo depende el tiempo de cómputo de $m$?

El costo de un ciclo externo puede resumirse como

```math
C_m\approx C_{f'}+mC_f.
```

sin contar el control de convergencia. Por eso el costo por ciclo crece aproximadamente de manera lineal con $m$. Al mismo tiempo, el orden local aumenta y suelen necesitarse menos ciclos externos. El tiempo total es el resultado de esas dos tendencias opuestas.

Para medirlo se resuelve 400 veces la misma ecuación dentro de cada muestra. Se hace calentamiento previo y se usa la mediana de mediciones repetidas. Los tiempos corresponden a este computador y pueden variar en otro; las cuentas de evaluaciones, en cambio, describen el algoritmo.
"""; markdown=true)

add_cell!(raw"""function resolver_lote(m::Integer, repeticiones::Integer)
    acumulado = 0.0
    for _ in 1:repeticiones
        r = shamanskii(f_prueba, df_prueba, 0.5;
                       m=m, atol=1e-14, guardar_historial=false)
        acumulado += r.root
    end
    acumulado
end

repeticiones_lote = 400
valores_m_tiempo = collect(1:12)

datos_tiempo = map(valores_m_tiempo) do m_actual
    resolver_lote(m_actual, repeticiones_lote) # calentamiento
    ensayo = @benchmark resolver_lote($m_actual, $repeticiones_lote) samples=80 seconds=0.30
    resultado = shamanskii(f_prueba, df_prueba, 0.5;
                           m=m_actual, atol=1e-14, guardar_historial=false)
    (
        m=m_actual,
        minimo_ns=minimum(ensayo).time / repeticiones_lote,
        mediana_ns=median(ensayo).time / repeticiones_lote,
        ciclos=resultado.outer_iterations,
        pasos=resultado.chord_steps,
        eval_f=resultado.f_evals,
        eval_df=resultado.df_evals,
    )
end

println(" m  mediana (μs)  mínimo (μs)  ciclos  pasos  eval f  eval f'")
for r in datos_tiempo
    @printf("%2d  %12.4f  %11.4f  %6d  %5d  %6d  %7d\n",
            r.m, r.mediana_ns / 1e3, r.minimo_ns / 1e3,
            r.ciclos, r.pasos, r.eval_f, r.eval_df)
end

mejor_tiempo = datos_tiempo[argmin(getfield.(datos_tiempo, :mediana_ns))]
println("Menor mediana observada: m=", mejor_tiempo.m,
        ", ", round(mejor_tiempo.mediana_ns / 1e3; digits=4), " μs por solución.")
""")

add_cell!(raw"""grafica_tiempo = plot(
    getfield.(datos_tiempo, :m),
    getfield.(datos_tiempo, :mediana_ns) ./ 1e3;
    marker=:circle,
    xlabel="orden m",
    ylabel="tiempo mediano por solución (μs)",
    title="Costo medido al variar m",
    label="tiempo",
)

grafica_trabajo = plot(
    getfield.(datos_tiempo, :m),
    getfield.(datos_tiempo, :eval_f);
    marker=:diamond,
    xlabel="orden m",
    ylabel="número de evaluaciones",
    title="Trabajo algorítmico",
    label="evaluaciones de f",
)
plot!(grafica_trabajo,
      getfield.(datos_tiempo, :m),
      getfield.(datos_tiempo, :eval_df);
      marker=:square, label="evaluaciones de f'")

display(plot(grafica_tiempo, grafica_trabajo; layout=(1, 2), size=(1000, 420)))
""")

add_cell!(raw"""### Lectura del experimento

No existe un valor de $m$ universalmente más rápido. En esta ecuación escalar, $f$ y $f'$ son baratas, así que reutilizar la derivada ofrece un ahorro limitado. Los primeros aumentos de $m$ reducen ciclos externos; después, los pasos adicionales dominan y el tiempo vuelve a crecer o se estabiliza dentro del ruido de medición.

En un sistema grande, donde actualizar y factorizar un Jacobiano es mucho más costoso, valores de $m>1$ pueden resultar más favorables. Por eso conviene acompañar el tiempo con las evaluaciones de $f$ y $f'$ y no convertir el mejor $m$ de este ejemplo en una regla general.
"""; markdown=true)

add_cell!(raw"""# Problema 2. Determinación de $\omega$

La posición al tiempo $t>0$ es

$$
s(t,\omega)=\frac{g}{2\omega^2}\left[\sinh(\omega t)-\sin(\omega t)\right],
\qquad g=9.8\ \mathrm{m/s^2}.
$$

Como el objeto recorre un metro en un segundo, debemos resolver

$$F(\omega)=s(1,\omega)-1=0,\qquad \omega>0.$$

La expansión

$$
\sinh y-\sin y=2\sum_{k=0}^{\infty}\frac{y^{4k+3}}{(4k+3)!}
$$

muestra que, después de dividir por $\omega^2$, $s(1,\omega)$ es una suma de potencias positivas estrictamente crecientes para $\omega>0$. Por ello $F$ es estrictamente creciente. Además, $F(\omega)\to-1$ cuando $\omega\to0^+$ y $F(2)>0$, así que existe una única raíz positiva.
"""; markdown=true)

add_cell!(raw"""function posicion(t, omega)
    T = promote_type(typeof(float(t)), typeof(float(omega)))
    tt, w = T(t), T(omega)
    g = T(49) / T(5)
    iszero(w) && return zero(T)
    g / (T(2) * w^2) * (sinh(w * tt) - sin(w * tt))
end

ecuacion_omega(w) = posicion(one(w), w) - one(w)

function biseccion_certificada(f, a, b; atol, maxiter::Integer=1000)
    a < b || throw(ArgumentError("se requiere a < b"))
    fa, fb = f(a), f(b)
    fa == 0 && return (root=a, lower=a, upper=a, iterations=0, residual=zero(fa))
    fb == 0 && return (root=b, lower=b, upper=b, iterations=0, residual=zero(fb))
    signbit(fa) != signbit(fb) || throw(ArgumentError("el intervalo no encierra una raíz"))

    for iteracion in 1:maxiter
        c = a + (b - a) / 2
        fc = f(c)
        if iszero(fc)
            return (root=c, lower=c, upper=c, iterations=iteracion, residual=fc)
        elseif signbit(fa) != signbit(fc)
            b, fb = c, fc
        else
            a, fa = c, fc
        end
        if b - a <= 2atol
            r = a + (b - a) / 2
            return (root=r, lower=a, upper=b, iterations=iteracion, residual=f(r))
        end
    end
    error("La bisección no alcanzó la tolerancia")
end
""")

add_cell!(raw"""resultado_omega = setprecision(BigFloat, 256) do
    biseccion_certificada(ecuacion_omega, BigFloat("0.1"), BigFloat("2");
                          atol=BigFloat("1e-60"), maxiter=1000)
end

omega_referencia = resultado_omega.root
omega_12 = round(omega_referencia; digits=12)
semiancho_redondeo = BigFloat("0.5e-12")
celda_redondeo = (omega_12 - semiancho_redondeo,
                  omega_12 + semiancho_redondeo)

@printf("ω con 12 decimales: %.12f\n", Float64(omega_referencia))
println("Referencia de 256 bits: ", omega_referencia)
println("Intervalo certificado: [", resultado_omega.lower, ", ", resultado_omega.upper, "]")
println("Ancho del intervalo: ", resultado_omega.upper - resultado_omega.lower)
println("F(ω) en la referencia: ", resultado_omega.residual)
println("s(1,ω redondeado)-1: ", ecuacion_omega(omega_12))

@assert resultado_omega.lower <= omega_referencia <= resultado_omega.upper
@assert celda_redondeo[1] < resultado_omega.lower < resultado_omega.upper < celda_redondeo[2]
@assert abs(resultado_omega.residual) < big"1e-59"
@assert @sprintf("%.12f", Float64(omega_referencia)) == "0.612142570703"
""")

add_cell!(raw"""valores_omega = range(0.1, 1.2; length=400)
grafica_omega = plot(
    valores_omega,
    ecuacion_omega.(valores_omega);
    xlabel="ω",
    ylabel="F(ω)=s(1,ω)-1",
    title="Única raíz positiva del modelo",
    label="F(ω)",
)
hline!(grafica_omega, [0.0]; color=:black, linestyle=:dash, label="cero")
vline!(grafica_omega, [Float64(omega_referencia)];
       color=:red, linestyle=:dot, label="ω ≈ 0.612142570703")
display(grafica_omega)
""")

add_cell!(raw"""function derivada_ecuacion_omega(w)
    g = oftype(w, 49) / oftype(w, 5)
    h = sinh(w) - sin(w)
    hp = cosh(w) - cos(w)
    g / 2 * (w * hp - 2h) / w^3
end

omega_shamanskii = shamanskii(ecuacion_omega, derivada_ecuacion_omega, 0.6;
                               m=3, atol=1e-15, max_outer=20)

println("Comprobación con Shamanskii m=3: ", omega_shamanskii.root)
println("Residuo: ", omega_shamanskii.residual)
println("Diferencia frente a BigFloat: ",
        abs(BigFloat(omega_shamanskii.root) - omega_referencia))

@assert omega_shamanskii.converged
@assert abs(BigFloat(omega_shamanskii.root) - omega_referencia) < big"2e-15"
""")

add_cell!(raw"""## Conclusión

El método de Shamanskii hace visible un intercambio que no aparece al mirar solamente el orden de convergencia. Aumentar $m$ permite avanzar más veces antes de actualizar la derivada y puede reducir los ciclos externos, pero cada aumento también añade trabajo. En la ecuación $\cos x-x=0$, donde tanto la función como la derivada son baratas, el beneficio se agota pronto. El mejor valor observado pertenece a este experimento y a este computador, no es una constante del método.

El segundo problema mostró otra parte importante del análisis numérico: entregar doce decimales no consiste únicamente en imprimirlos. La respuesta

$$\boxed{\omega=0.612142570703}$$

se respaldó con aritmética de 256 bits, un intervalo de bisección mucho más estrecho que $10^{-12}$ y una comprobación independiente con Shamanskii.

## ¿Qué cambió en mi perspectiva?

Al principio podía parecer que usar un $m$ mayor siempre debía ser mejor porque aumenta el orden local. El experimento muestra que rapidez y orden no son lo mismo: también importan el costo de la derivada, las evaluaciones adicionales y la cantidad de ciclos. Ahora entiendo que elegir un método exige observar tanto la convergencia matemática como el trabajo real que realiza el programa.

## Uso de inteligencia artificial

Se utilizó OpenAI Codex para revisar las fuentes, organizar la demostración, implementar y depurar Julia, diseñar las mediciones y verificar los resultados. Las salidas, gráficas, pruebas y tiempos visibles fueron generados por Julia en el entorno registrado en esta carpeta.

## Referencias

- Kelley, C. T. (1995). *Iterative Methods for Linear and Nonlinear Equations*. SIAM, §5.4.3.
- Quarteroni, A., Saleri, F. y Gervasio, P. (2010). *Scientific Computing with MATLAB and Octave*, 3.ª ed. Springer.
- Laboratorio de Matemáticas, Universidad Nacional de Colombia. *Ecuaciones no lineales*. https://labmatecc.github.io/Notebooks/AnalisisNumerico/EcuacionesNoLineales/
- JuliaCI. *BenchmarkTools.jl Manual*. https://juliaci.github.io/BenchmarkTools.jl/stable/manual/
"""; markdown=true)

add_cell!(raw"""comprobaciones = Dict(
    "m=1 coincide con Newton" => resultados_m[1].converged,
    "Shamanskii converge para m=1:10" => all(r.converged for r in resultados_m),
    "raíz escalar correcta" => all(abs(BigFloat(r.root) - raiz_referencia) < big"2e-14" for r in resultados_m),
    "benchmark ejecutado" => all(r.mediana_ns > 0 for r in datos_tiempo),
    "intervalo de ω certificado" => resultado_omega.upper - resultado_omega.lower < big"2e-60",
    "doce decimales de ω" => @sprintf("%.12f", Float64(omega_referencia)) == "0.612142570703",
    "Shamanskii confirma ω" => omega_shamanskii.converged,
)

@assert all(values(comprobaciones))
println("Comprobaciones finales: ", count(values(comprobaciones)), "/",
        length(comprobaciones), " aprobadas")
for (nombre, resultado) in sort(collect(comprobaciones))
    println(rpad(nombre, 39), resultado ? "OK" : "FALLÓ")
end

println("\nFecha y hora de ejecución: ", now())
versioninfo()
""")

project = read(joinpath(ROOT, "Project.toml"), String)
manifest = read(joinpath(ROOT, "Manifest.toml"), String)

project_id = "00000000-0000-0000-0000-000000000001"
manifest_id = "00000000-0000-0000-0000-000000000002"
push!(cell_blocks, "# ╔═╡ $(project_id)\nPLUTO_PROJECT_TOML_CONTENTS = \"\"\"\n$(project)\n\"\"\"\n")
push!(cell_blocks, "# ╔═╡ $(manifest_id)\nPLUTO_MANIFEST_TOML_CONTENTS = \"\"\"\n$(manifest)\n\"\"\"\n")
push!(cell_order, "# ╟─" * project_id)
push!(cell_order, "# ╟─" * manifest_id)

frontmatter = """### A Pluto.jl notebook ###
# v1.1.0

#> [frontmatter]
#> title = "Tarea opcional: método de Shamanskii y ecuaciones no lineales"
#> description = "Implementación, tiempos y aplicación del método de Shamanskii."
#> date = "2026-11-08"
#> tags = ["analisis-numerico", "ecuaciones-no-lineales", "julia"]
#>
#>     [[frontmatter.author]]
#>     name = "Mateo Gabriel González Lara"

using Markdown
using InteractiveUtils

"""

open(OUTPUT, "w") do io
    print(io, frontmatter)
    for block in cell_blocks
        println(io, block)
    end
    println(io, "# ╔═╡ Cell order:")
    println(io, join(cell_order, '\n'))
end

println("Notebook Pluto generado en: ", OUTPUT)
