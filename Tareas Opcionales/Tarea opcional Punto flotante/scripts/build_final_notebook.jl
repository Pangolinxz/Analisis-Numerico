using JSON
using UUIDs

const ROOT = normpath(joinpath(@__DIR__, ".."))
const INPUT = joinpath(ROOT, "PuntoFlotante_Julia_avance.ipynb")
const OUTPUT = joinpath(ROOT, "PuntoFlotante_Julia_final.ipynb")

nb = JSON.parsefile(INPUT)
cells = nb["cells"]

function setsource!(index::Integer, source::AbstractString)
    cells[index + 1]["source"] = String(source)
    if cells[index + 1]["cell_type"] == "code"
        cells[index + 1]["execution_count"] = nothing
        cells[index + 1]["outputs"] = Any[]
    end
end

function codecell(source::AbstractString)
    Dict{String,Any}(
        "cell_type" => "code",
        "execution_count" => nothing,
        "id" => string(uuid4()),
        "metadata" => Dict{String,Any}(),
        "outputs" => Any[],
        "source" => String(source),
    )
end

function markdowncell(source::AbstractString)
    Dict{String,Any}(
        "cell_type" => "markdown",
        "id" => string(uuid4()),
        "metadata" => Dict{String,Any}(),
        "source" => String(source),
    )
end

setsource!(0, raw"""# Tarea opcional: punto flotante

## Siete problemas resueltos en Julia

**Autor:** Mateo Gabriel González Lara. **Curso:** Análisis Numérico.

**Solución y código:** Mateo Gabriel González Lara. **Enunciado de la actividad:** material de clase elaborado por [Juan Galvis](https://scholar.google.com/citations?user=lbfc2joAAAAJ&hl=en).

Este cuaderno presenta las soluciones matemáticas, implementaciones, gráficas y mediciones ejecutadas en un kernel Julia real. Las salidas que aparecen debajo de las celdas fueron producidas por Julia; no se presentan comprobaciones externas en Python como si fueran resultados del lenguaje.

**Fuente matemática principal:** Kincaid y Cheney, *Numerical Analysis: Mathematics of Scientific Computing* (2002), edición proporcionada: §1.1, §1.3 (pp. 28–36), §2.1 (pp. 37–54), §2.2 (pp. 55–63) y §2.3 (pp. 64–71). Las páginas indicadas son las impresas en el libro.

En el problema 2 se conserva literalmente la rama del enunciado que incluye $1/2$.
""")

# Conserva las atribuciones incluidas en el enunciado original de la actividad.
for cell in cells
    cell["cell_type"] == "markdown" || continue
    source = cell["source"] isa AbstractVector ? join(string.(cell["source"])) : String(cell["source"])
    source = replace(source,
        "## Problema 2. Sucesión por tramos" => "## Problema 2. Sucesión por tramos (Sullivan)",
        "## Problema 3. Softmax sin desbordamiento por exceso" => "## Problema 3. Softmax sin desbordamiento por exceso (Goodfellow et al.)",
        "## Problema 4. Cancelación en dos expresiones equivalentes" => "## Problema 4. Cancelación en dos expresiones equivalentes (Stoer)",
        "## Problema 5. Recurrencia de Viète: indexación y estabilidad" => "## Problema 5. Recurrencia de Viète: indexación y estabilidad (Quarteroni, Saleri y Gervasio)",
        "## Problema 6. Recurrencia de Stewart" => "## Problema 6. Recurrencia de Stewart",
    )
    cell["source"] = source
end

setsource!(1, raw"""## Preparación y convenciones

El entorno reproducible está registrado en `Project.toml` y `Manifest.toml`. Para reproducirlo desde esta carpeta se ejecuta primero `import Pkg; Pkg.instantiate()` y después se abre el notebook con el kernel `Julia 1.10`.

Se distinguen el resultado exacto, el valor calculado y una referencia de mayor precisión. Para una referencia no nula $r$ se usan
$$E_a=|\widehat y-r|,\qquad E_r=\frac{|\widehat y-r|}{|r|}.$$

`Float64` tiene 53 bits de precisión. Con redondeo al más cercano, su unidad de redondeo es $u=2^{-53}$, mientras que `eps(Float64)=2^{-52}` es la separación entre 1 y su sucesor. El modelo relativo de §2.1 se utiliza cuando no intervienen desbordamiento, subdesbordamiento ni operaciones excepcionales.
""")

setsource!(2, raw"""import Pkg
Pkg.activate(pwd())
ENV["GKSwstype"] = "100"

using Printf
using Statistics
using InteractiveUtils
using Dates
using BenchmarkTools
using Plots

gr()
default(size=(820, 450), linewidth=2.2, framestyle=:box, legend=:best)

println("Proyecto activo: ", Base.active_project())
println("Versión Julia: ", VERSION)
println("Bytes por Float64: ", sizeof(Float64))
println("eps(Float64): ", eps(Float64))
println("Unidad de redondeo: ", eps(Float64) / 2)
""")

setsource!(4, raw"""function memoria_float64(N::Integer)
    N > 0 || throw(ArgumentError("N debe ser positivo"))
    bytes = sizeof(Float64)
    return (vector=big(N) * bytes, matriz=big(N)^2 * bytes)
end

memoria_p1 = memoria_float64(100_000)
println("Vector: ", memoria_p1.vector, " bytes = ",
        Float64(memoria_p1.vector) / 10^6, " MB = ",
        Float64(memoria_p1.vector) / 2^10, " KiB")
println("Matriz: ", memoria_p1.matriz, " bytes = ",
        Float64(memoria_p1.matriz) / 10^9, " GB = ",
        Float64(memoria_p1.matriz) / 2^30, " GiB")

vector_control = zeros(Float64, 100)
@assert sizeof(vector_control) == 100 * sizeof(Float64)
@assert memoria_p1.vector == 800_000
@assert memoria_p1.matriz == 80_000_000_000
""")

setsource!(6, raw"""function orbita(x0, N::Integer)
    N >= 0 || throw(ArgumentError("N debe ser no negativo"))
    zero(x0) <= x0 <= one(x0) || throw(ArgumentError("x0 fuera de [0,1]"))
    xs = Vector{typeof(x0)}(undef, N + 1)
    xs[1] = x0
    for n in 1:N
        x = xs[n]
        # La igualdad 2x == 1 pertenece a la primera rama del enunciado.
        xs[n + 1] = 2 * x <= one(x) ? 2 * x : 2 * x - one(x)
    end
    xs
end

function tabla_orbita(q0::Rational, N=50)
    exactos = orbita(q0, N)
    flotantes = orbita(Float64(q0), N)
    println(" n      exacto                Float64             error absoluto")
    setprecision(BigFloat, 256) do
        for n in 1:N
            error = abs(BigFloat(flotantes[n + 1]) - BigFloat(exactos[n + 1]))
            @printf("%2d  %10s  % .17e  %.5e\n", n, string(exactos[n + 1]),
                    flotantes[n + 1], Float64(error))
        end
    end
    (exactos=exactos, flotantes=flotantes)
end

orbitas10 = tabla_orbita(big(1) // big(10))
orbitas8 = tabla_orbita(big(1) // big(8))

let q10 = big(1) // big(10), qhat = Rational{BigInt}(0.1)
    @assert qhat - q10 == big(1) // (big(5) * big(2)^55)
    exactos_dato_almacenado = orbita(qhat, 50)
    @assert all(Rational{BigInt}(orbitas10.flotantes[j]) == exactos_dato_almacenado[j] for j in 1:51)
    @assert all((2 * orbitas10.exactos[j] <= 1) == (2 * exactos_dato_almacenado[j] <= 1) for j in 1:50)
    @assert orbitas10.exactos[51] == big(2) // big(5)
    @assert orbitas10.flotantes[51] == 0.40625
    @assert orbitas8.exactos[3] == big(1) // big(2)
    @assert orbitas8.exactos[4] == 1
    @assert all(Rational{BigInt}(orbitas8.flotantes[j]) == orbitas8.exactos[j] for j in 1:51)
end

println("Verificación final x₀=1/10: x₅₀ exacto = ", orbitas10.exactos[51],
        " = ", Float64(orbitas10.exactos[51]),
        "; Float64 = ", orbitas10.flotantes[51])
println("Verificación de la rama x₀=1/8: x₂ = ", orbitas8.exactos[3],
        ", x₃ = ", orbitas8.exactos[4])
""")

p2_plot = codecell(raw"""errores_orbita10 = setprecision(BigFloat, 256) do
    [Float64(abs(BigFloat(orbitas10.flotantes[n + 1]) - BigFloat(orbitas10.exactos[n + 1]))) for n in 0:50]
end

grafica_p2 = plot(0:50, errores_orbita10;
    yscale=:log10, marker=:circle, markersize=2.5,
    xlabel="iteración n", ylabel="error absoluto",
    title="Problema 2 — Amplificación del error inicial (x₀=1/10)",
    label="|x̂ₙ-xₙ|")
display(grafica_p2)
""")

setsource!(8, raw"""softmax_directa(x::AbstractVector{<:AbstractFloat}) = exp.(x) ./ sum(exp.(x))

function softmax_estable(x::AbstractVector{T}) where {T<:AbstractFloat}
    isempty(x) && throw(ArgumentError("El vector no puede estar vacío"))
    all(isfinite, x) || throw(ArgumentError("Se requieren entradas finitas"))
    a = maximum(x)
    y = exp.(x .- a)
    y ./ sum(y)
end

let casos = ([1.0, 2.0, 3.0], [1000.0, 1001.0, 1002.0], [-1000.0, -1001.0, -1002.0])
    for x in casos
        directa = softmax_directa(x)
        estable = softmax_estable(x)
        println("x = ", x)
        println("Directa: ", directa)
        println("Estable: ", estable, "; suma = ", sum(estable))
        @assert all(isfinite, estable)
        @assert all(t -> t >= 0, estable)
        @assert isapprox(sum(estable), 1.0; atol=10 * eps(Float64), rtol=0)
    end
end

let p = softmax_estable([1000.0, 1001.0, 1002.0]),
    q = softmax_estable([0.0, 1.0, 2.0])
    @assert isapprox(p, q; atol=10 * eps(Float64), rtol=0)
end
""")

setsource!(10, raw"""f_cancelacion(x) = sqrt(one(x) + x * x) - one(x)
g_racionalizada(x) = (x * x) / (sqrt(one(x) + x * x) + one(x))

datos_cancelacion = setprecision(BigFloat, 256) do
    filas = NamedTuple[]
    for k in 1:30
        x = ldexp(1.0, -3 * k) # x = 8^(-k), exactamente en binario
        referencia = g_racionalizada(BigFloat(x))
        fx, gx = f_cancelacion(x), g_racionalizada(x)
        error_f = abs(BigFloat(fx) - referencia) / abs(referencia)
        error_g = abs(BigFloat(gx) - referencia) / abs(referencia)
        push!(filas, (k=k, x=x, f=fx, g=gx,
                      error_f=Float64(error_f), error_g=Float64(error_g)))
    end
    filas
end

println(" k         x                f(x)              g(x)          Er(f)       Er(g)")
for r in datos_cancelacion
    @printf("%2d  %.6e  %.10e  %.10e  %.3e  %.3e\n",
            r.k, r.x, r.f, r.g, r.error_f, r.error_g)
end

@assert datos_cancelacion[8].f > 0.0
@assert datos_cancelacion[9].f == 0.0
@assert all(r.f == 0.0 for r in datos_cancelacion[9:end])
@assert all(r.g > 0.0 for r in datos_cancelacion)
println("Primer k con f(x)=0 en Float64: ", findfirst(r -> r.f == 0.0, datos_cancelacion))
""")

setsource!(11, raw"""## Problema 5. Recurrencia de Viète: indexación y estabilidad (Quarteroni, Saleri y Gervasio)

La recurrencia estudiada aproxima $\pi$. Para implementarla de forma continua usamos la reindexación $w_k=z_{k+1}$, con
$$w_1=2,\qquad w_{k+1}=2^{k+1/2}\sqrt{1-\sqrt{1-4^{-k}w_k^2}},\quad k\ge1.$$

Esta sucesión satisface
$$w_k=2^k\sin\!\left(\frac{\pi}{2^k}\right).$$
En efecto, si $\theta=\pi/2^k$, entonces $4^{-k}w_k^2=\sin^2\theta$. Como $\theta\in(0,\pi/2]$, se tiene $\sqrt{1-\sin^2\theta}=\cos\theta$ y
$$1-\cos\theta=2\sin^2\!\left(\frac{\theta}{2}\right).$$
Al sustituir esta identidad en la recurrencia se obtiene la misma fórmula para $w_{k+1}$. Además, como $\sin t/t\to1$ cuando $t\to0$,
$$w_k=\pi\,\frac{\sin(\pi/2^k)}{\pi/2^k}\longrightarrow\pi.$$

La fórmula directa contiene la resta $1-\sqrt{1-a_k}$, donde $a_k=4^{-k}w_k^2$. A medida que $k$ crece, esa resta ocurre entre números cada vez más cercanos y pierde cifras significativas. Racionalizando,
$$1-\sqrt{1-a_k}=\frac{a_k}{1+\sqrt{1-a_k}},$$
se obtiene la forma más estable
$$\boxed{w_{k+1}=w_k\sqrt{\frac{2}{1+\sqrt{1-a_k}}}.}$$

Las dos expresiones son equivalentes en aritmética exacta, pero no se comportan igual en `Float64`. La comparación numérica muestra cuándo la forma directa empieza a perder información y cuánto tiempo conserva precisión la versión racionalizada. Por Taylor,
$$\pi-w_k=\frac{\pi^3}{6\,4^k}+O(16^{-k}),$$
de modo que al principio el error disminuye aproximadamente por un factor de cuatro; después termina dominando el redondeo.
""")

p4_plot = codecell(raw"""piso_visual = eps(Float64)
grafica_p4 = plot([r.k for r in datos_cancelacion],
    max.([r.error_f for r in datos_cancelacion], piso_visual);
    yscale=:log10, marker=:circle, xlabel="k, con x=8⁻ᵏ",
    ylabel="error relativo (piso visual = eps)",
    title="Problema 4 — Cancelación directa frente a racionalización",
    label="f directa")
plot!(grafica_p4, [r.k for r in datos_cancelacion],
    max.([r.error_g for r in datos_cancelacion], piso_visual);
    marker=:diamond, label="g racionalizada")
vline!(grafica_p4, [9]; linestyle=:dash, label="primer cero directo: k=9")
display(grafica_p4)
""")

setsource!(12, raw"""function viete(N::Integer, ::Type{T}=Float64; estable=false) where {T<:AbstractFloat}
    N >= 1 || throw(ArgumentError("N debe ser al menos 1"))
    w = Vector{T}(undef, N)
    w[1] = T(2)
    for k in 1:N-1
        a = ldexp(w[k], -k)^2
        radicando = one(T) - a
        radicando >= zero(T) || throw(DomainError(radicando, "Radicando negativo; revisar índice o redondeo"))
        interior = sqrt(radicando)
        if estable
            w[k + 1] = w[k] * sqrt(T(2) / (one(T) + interior))
        else
            # Forma propuesta, reindexada como w_k=z_{k+1}.
            w[k + 1] = ldexp(sqrt(T(2) * (one(T) - interior)), k)
        end
    end
    w
end

viete_directa64 = viete(40)
viete_estable64 = viete(40; estable=true)
datos_viete = setprecision(BigFloat, 256) do
    pi_ref = BigFloat(pi)
    [(k=k, directa=viete_directa64[k], estable=viete_estable64[k],
      error_directa=Float64(abs(BigFloat(viete_directa64[k]) - pi_ref)),
      error_estable=Float64(abs(BigFloat(viete_estable64[k]) - pi_ref))) for k in 1:40]
end

println(" k       directa             estable           Ea(directa)   Ea(estable)")
for r in datos_viete
    @printf("%2d  %.16e  %.16e  %.4e  %.4e\n",
            r.k, r.directa, r.estable, r.error_directa, r.error_estable)
end
@assert isapprox(viete_estable64[end], Float64(pi); atol=20 * eps(Float64), rtol=0)
println("Primer índice k donde la forma directa devuelve cero: ",
        findfirst(iszero, viete_directa64))

setprecision(BigFloat, 256) do
    alta = viete(80, BigFloat; estable=true)
    println("Error estable a 256 bits, k=80: ", abs(alta[end] - BigFloat(pi)))
end
""")

p5_plot = codecell(raw"""grafica_p5 = plot([r.k for r in datos_viete],
    max.([r.error_directa for r in datos_viete], eps(Float64));
    yscale=:log10, marker=:circle, xlabel="índice k", ylabel="error absoluto",
    title="Problema 5 — Recurrencia propuesta: forma directa y estable",
    label="forma directa")
plot!(grafica_p5, [r.k for r in datos_viete],
    max.([r.error_estable for r in datos_viete], eps(Float64));
    marker=:diamond, label="forma racionalizada")
display(grafica_p5)
""")

setsource!(14, raw"""function stewart(N::Integer, ::Type{T}=Float64) where {T<:AbstractFloat}
    N >= 2 || throw(ArgumentError("N debe ser al menos 2"))
    x = Vector{T}(undef, N)
    x[1], x[2] = one(T) / T(3), one(T) / T(12)
    for k in 2:N-1
        x[k + 1] = (T(9) / T(4)) * x[k] - (one(T) / T(2)) * x[k - 1]
    end
    x
end

function stewart_alternativa(N::Integer)
    x = Vector{Float64}(undef, N)
    x[1] = 1.0 / 3.0
    for k in 1:N-1
        x[k + 1] = x[k] / 4.0
    end
    x
end

stewart64 = stewart(80)
stewart_alt64 = stewart_alternativa(80)
datos_stewart = setprecision(BigFloat, 256) do
    [(k=k, calculado=stewart64[k], alternativo=stewart_alt64[k],
      referencia=inv(BigFloat(3) * BigFloat(4)^(k - 1)),
      error_relativo=Float64(abs(BigFloat(stewart64[k]) * BigFloat(3) * BigFloat(4)^(k - 1) - 1))) for k in 1:80]
end

println(" k       recurrencia          referencia          alternativa      Er(recurrencia)")
for k in (1, 2, 3, 10, 20, 30, 40, 50, 80)
    r = datos_stewart[k]
    @printf("%2d  %.12e  %.12e  %.12e  %.4e\n",
            r.k, r.calculado, Float64(r.referencia), r.alternativo, r.error_relativo)
end

# Los errores iniciales están correlacionados: 4e₂-e₁=0 exactamente.
q1, q2 = Rational{BigInt}(stewart64[1]), Rational{BigInt}(stewart64[2])
e1 = q1 - big(1) // big(3)
e2 = q2 - big(1) // big(12)
@assert stewart64[2] == stewart64[1] / 4
@assert 4 * e2 - e1 == 0
println("Errores iniciales exactos: e₁=", e1, ", e₂=", e2,
        "; 4e₂-e₁=", 4 * e2 - e1)

# La primera operación ya introduce una perturbación local no nula.
x3_operacion_exacta = (big(9) // 4) * q2 - (big(1) // 2) * q1
rho3 = Rational{BigInt}(stewart64[3]) - x3_operacion_exacta
@assert rho3 != 0
println("Perturbación local de redondeo en x₃: ρ₃=", rho3)

setprecision(BigFloat, 256) do
    alta = stewart(80, BigFloat)
    println("Error relativo a 256 bits, k=80: ",
            abs(alta[end] * BigFloat(3) * BigFloat(4)^79 - 1))
end
""")

p6_plot = codecell(raw"""indices_stewart = [r.k for r in datos_stewart]
grafica_p6a = plot(indices_stewart, abs.([r.calculado for r in datos_stewart]);
    yscale=:log10, xlabel="índice k", ylabel="magnitud",
    title="Valores calculados", label="recurrencia de orden 2")
plot!(grafica_p6a, indices_stewart, Float64.([r.referencia for r in datos_stewart]);
    linestyle=:dash, label="solución exacta")
plot!(grafica_p6a, indices_stewart, abs.([r.alternativo for r in datos_stewart]);
    linestyle=:dot, label="recurrencia xₖ₊₁=xₖ/4")

grafica_p6b = plot(indices_stewart,
    max.([r.error_relativo for r in datos_stewart], eps(Float64));
    yscale=:log10, xlabel="índice k", ylabel="error relativo",
    title="Crecimiento del error", label="error de la recurrencia")
display(plot(grafica_p6a, grafica_p6b; layout=(1, 2), size=(1000, 420)))
""")

setsource!(15, raw"""## Problema 7. `@time`, `@btime` y `@benchmark`

**Enunciado.** Investigar estas utilidades y mostrar ejemplos con operaciones de punto flotante.

| Utilidad | Qué hace | Qué observar |
|---|---|---|
| `@time` (Julia Base) | Ejecuta una vez, muestra tiempo y asignaciones y devuelve el resultado | La primera llamada puede incluir compilación |
| `@btime` (BenchmarkTools) | Realiza mediciones repetidas, imprime una estimación basada en el menor tiempo y devuelve el resultado | Las entradas externas se interpolan con `$` |
| `@benchmark` (BenchmarkTools) | Devuelve un `Trial` con muestras de tiempo y memoria | Permite comparar mínimo, mediana y dispersión |

Se mide una función sobre un vector construido previamente; la creación del vector y la impresión no forman parte de la operación medida. Se realiza calentamiento antes de `BenchmarkTools`. Los tiempos guardados debajo de la celda son resultados auténticos de esta ejecución y pueden variar en otro computador. No se usa `@fastmath`, porque modificaría las reglas de evaluación relevantes para los experimentos de redondeo.

**Fuentes técnicas:** documentación oficial de Julia, *Performance Tips*, y manual oficial de BenchmarkTools. Estas fuentes describen las herramientas; el fundamento matemático procede de Kincaid–Cheney.
""")

setsource!(16, raw"""function suma_cuadrados(v::AbstractVector{T}) where {T<:AbstractFloat}
    s = zero(T)
    for x in v
        s += x * x
    end
    s
end

vector_tiempos = collect(range(0.0, 1.0; length=100_000))

println("Primera llamada con @time (puede incluir compilación):")
resultado_primera = @time suma_cuadrados(vector_tiempos)
println("Segunda llamada con @time:")
resultado_segunda = @time suma_cuadrados(vector_tiempos)
@assert resultado_primera == resultado_segunda

suma_cuadrados(vector_tiempos) # calentamiento explícito
println("Medición con @btime:")
resultado_btime = @btime suma_cuadrados($vector_tiempos) seconds=1
ensayo = @benchmark suma_cuadrados($vector_tiempos) seconds=1

benchmark_resumen = (
    minimo_ns=minimum(ensayo).time,
    mediana_ns=median(ensayo).time,
    memoria_bytes=minimum(ensayo).memory,
    asignaciones=minimum(ensayo).allocs,
)
println("Resumen @benchmark: ", benchmark_resumen)
println("Nota: estos tiempos corresponden al entorno mostrado abajo y no son universales.")
display(ensayo)
""")

validation_cell = codecell(raw"""comprobaciones_finales = Dict(
    "P1 memoria" => memoria_p1.vector == 800_000 && memoria_p1.matriz == 80_000_000_000,
    "P2 x50 exacto" => orbitas10.exactos[51] == big(2) // big(5),
    "P2 x50 Float64" => orbitas10.flotantes[51] == 0.40625,
    "P2 rama inclusiva" => orbitas8.exactos[3] == big(1) // big(2) && orbitas8.exactos[4] == 1,
    "P3 softmax estable" => all(isfinite, softmax_estable([1000.0, 1001.0, 1002.0])),
    "P4 cero desde k=9" => datos_cancelacion[8].f > 0 && all(r.f == 0 for r in datos_cancelacion[9:end]),
    "P5 forma estable" => isapprox(viete_estable64[end], Float64(pi); atol=20 * eps(Float64), rtol=0),
    "P6 errores correlacionados" => 4 * e2 - e1 == 0,
    "P6 redondeo operacional" => rho3 != 0,
    "P7 benchmark ejecutado" => benchmark_resumen.minimo_ns > 0 && benchmark_resumen.mediana_ns > 0,
)
@assert all(values(comprobaciones_finales))
println("Comprobaciones Julia: ", count(values(comprobaciones_finales)), "/",
        length(comprobaciones_finales), " aprobadas")
for (nombre, resultado) in sort(collect(comprobaciones_finales))
    println(rpad(nombre, 32), resultado ? "OK" : "FALLÓ")
end

println("\nFecha y hora de ejecución: ", now())
versioninfo()
println("\nPaquetes del proyecto:")
Pkg.status()
""")

setsource!(17, raw"""## Conclusión

Estos ejercicios muestran que un computador no trabaja con los números reales tal como los imaginamos en el papel, sino con una colección finita de aproximaciones. La diferencia suele ser pequeña, pero puede crecer, esconderse durante varias iteraciones o cambiar por completo el resultado de una fórmula.

Lo más importante no fue solamente obtener un número final. Fue entender por qué dos expresiones que son iguales algebraicamente pueden comportarse de manera distinta al programarlas. La racionalización de los problemas 4 y 5 conserva información que la fórmula directa pierde, mientras que la recurrencia del problema 6 demuestra que un error diminuto puede despertar una componente creciente y terminar dominando una solución que, en teoría, debía acercarse a cero.

También quedó claro que usar más precisión ayuda, pero no reemplaza un buen algoritmo. `BigFloat` retrasa algunos efectos del redondeo; una formulación estable ataca la causa del problema.

## ¿Qué cambió en mi perspectiva?

Al comenzar, esperaba que los errores de punto flotante fueran pequeñas diferencias visibles solo en los últimos decimales. Después de ejecutar los experimentos entendí que su efecto depende de la estructura del cálculo. Una resta entre números cercanos puede borrar el resultado, una condición inicial aproximada puede amplificarse y una recurrencia puede hacer crecer errores producidos durante sus propias operaciones.

Ahora no basta con preguntarme si una fórmula es correcta. También debo preguntarme cómo usa los números el computador, qué operaciones pueden perder información y si existe otra forma equivalente que sea más estable.

## Uso de inteligencia artificial y alcance

Se utilizó OpenAI Codex para continuar el borrador, revisar demostraciones y citas, preparar el entorno reproducible, depurar Julia y organizar las visualizaciones. Ningún resultado independiente de Python se presenta como salida de Julia. Las tablas, gráficas, aserciones y benchmarks visibles en el cuaderno fueron producidos por el kernel Julia indicado en el registro del entorno.

## Referencias

- Kincaid, D. y Cheney, W. (2002). *Numerical Analysis: Mathematics of Scientific Computing*. Secciones 1.1, 1.3 y 2.1–2.3 de la edición proporcionada.
- Julia Documentation. *Performance Tips*. https://docs.julialang.org/en/v1/manual/performance-tips/
- JuliaCI. *BenchmarkTools.jl Manual*. https://juliaci.github.io/BenchmarkTools.jl/stable/manual/

**Fuentes atribuidas por el enunciado original:** Sullivan (2020), Stoer y Bulirsch (2002), Stewart (1996), Quarteroni, Saleri y Gervasio (2006), y Goodfellow, Bengio y Courville (2016). Se conservan como procedencia declarada de los ejercicios.

Las atribuciones a Sullivan, Goodfellow, Stoer, Quarteroni–Saleri–Gervasio y Stewart se conservan como parte del enunciado original.
""")

# Insertar las gráficas inmediatamente después de cada experimento y una celda final de validación.
newcells = Any[]
for (i, cell) in enumerate(cells)
    push!(newcells, cell)
    original_index = i - 1
    original_index == 6 && push!(newcells, p2_plot)
    original_index == 10 && push!(newcells, p4_plot)
    original_index == 12 && push!(newcells, p5_plot)
    original_index == 14 && push!(newcells, p6_plot)
    original_index == 16 && push!(newcells, validation_cell)
end

nb["cells"] = newcells
nb["metadata"]["kernelspec"] = Dict(
    "display_name" => "Julia 1.10",
    "language" => "julia",
    "name" => "julia-1.10",
)
nb["metadata"]["language_info"] = Dict(
    "file_extension" => ".jl",
    "mimetype" => "application/julia",
    "name" => "julia",
    "version" => "1.10.5",
)
nb["metadata"]["preparation_status"] = "READY_FOR_JULIA_EXECUTION"

open(OUTPUT, "w") do io
    JSON.print(io, nb, 2)
end
println("Notebook final generado en: ", OUTPUT)
