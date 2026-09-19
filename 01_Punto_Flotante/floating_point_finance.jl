### A Pluto.jl notebook ###
# v0.20.28

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ 1f1dd7f7-55cb-4cb0-80b4-58b0ed069101
begin
	using Random
	using Statistics
	using Printf
	using DelimitedFiles
	using PlutoUI
	using Plots
	gr()
end

# ╔═╡ 6fdb3e8d-82b6-40dc-b857-a73a0d1d9102
begin
	AUTOR = "Mateo Gabriel Gonzalez Lara"
	md"""
	# Cuando unos decimales cambian una decisión
	## Aritmética de punto flotante y cruces de medias móviles

	**Autor/a:** $(AUTOR)  
	**Materia:** Analisis Numerico  
	**Entregable:** investigación experimental interactiva en Julia/Pluto.jl

	> **El recorrido:** una intuición sencilla → una pregunta incómoda → un experimento → una forma distinta de entender la precisión.
	"""
end

# ╔═╡ ccbab3d6-3453-4ae1-861e-3e96dbbcb103
md"""
## 1. Intuición inicial

Al comenzar, un precio cercano a 100 no me parecía un reto para un computador moderno. Mi intuición era sencilla: si `Float32` conserva varios decimales, cambiar desde `Float64` apenas debería alterar cifras invisibles. La duda apareció al recordar que una estrategia no siempre devuelve otro número; a veces toma una decisión tajante —comprar o no comprar— a partir de una comparación.

## 2. Pregunta de investigación

> **¿Puede el uso de `Float32` en lugar de `Float64` cambiar las decisiones producidas por un algoritmo financiero basado en comparaciones numéricas?**

Estudiaremos la regla

```math
\operatorname{SMA}_{s}>\operatorname{SMA}_{l}\Rightarrow \text{COMPRAR},
```

y preguntaremos si puede ocurrir

```math
\operatorname{sign}(\operatorname{SMA}_{s}^{(64)}-\operatorname{SMA}_{l}^{(64)})
\ne
\operatorname{sign}(\operatorname{SMA}_{s}^{(32)}-\operatorname{SMA}_{l}^{(32)}).
```

## 3. ¿Por qué es interesante?

Me interesó esta pregunta porque conecta dos mundos que parecen separados: una diferencia diminuta en la representación y una decisión completamente distinta en el algoritmo. Usar menos precisión puede ahorrar memoria y ancho de banda, pero no basta con contar los decimales perdidos. Importa qué hace el programa con ellos. Cerca de un umbral, algo casi imperceptible puede cambiar una respuesta de “no” a “sí”.

## 4. Predicción inicial — registrada antes de observar resultados

> Mi predicción fue que `Float32` y `Float64` producirían prácticamente las mismas decisiones. Para precios ordinarios, `Float32` parecía tener precisión suficiente; esperaba que las diferencias quedaran escondidas en los últimos decimales y que los desacuerdos, si aparecían, fueran excepcionalmente raros.

Dejo escrita esta predicción tal como era antes de mirar los resultados, porque equivocarse de una manera razonable también forma parte de investigar.
"""

# ╔═╡ f371d73f-1996-42de-a30a-f5a4dbdb7104
md"""
## 5. Conceptos necesarios

Para seguir la pista de esos decimales hay que mirar cómo se guardan. IEEE 754 define los formatos y las operaciones de punto flotante. Un número binario normal se representa, esquemáticamente, como

```math
(-1)^s\,(1.f)_2\,2^e.
```

El bit de signo fija el signo, el exponente fija la escala y la fracción almacena los bits significativos. En números normales hay un bit líder implícito; por eso 23 bits de fracción en `Float32` corresponden a **24 bits de precisión del significando**.

- **Epsilon de máquina** `eps(T)`: separación entre `one(T)` y el siguiente número de tipo `T`.
- **ULP local**: aquí usamos `nextfloat(x)-x`, la separación al representable siguiente cerca de `x`. No es constante: crece con la escala.
- **Redondeo**: una operación ideal suele caer entre dos representables y debe aproximarse. Julia/IEEE usa por defecto redondeo al más cercano, con empates al par, para estos formatos.
- **Error absoluto**: ``|\hat x-x|``. **Error relativo**: ``|\hat x-x|/|x|`` cuando ``x\ne0``.
- **Acumulación**: cada suma puede redondearse; el orden de las operaciones puede cambiar el error.
- **Cancelación**: restar números cercanos elimina dígitos comunes y hace visible el error previo de los operandos.
- **Overflow**: un resultado excede el mayor valor finito y puede convertirse en `Inf`. **Underflow**: cae hacia la región subnormal o cero; los subnormales permiten pérdida gradual de precisión.

Usaré `BigFloat` como **referencia de alta precisión**, no como si fuera “el número real exacto”. En el caso controlado construiré los datos a 256 bits y dejaré claro qué objeto se está aproximando.
"""

# ╔═╡ 2a56e72d-dd14-47b5-ad2b-a3a66d95a105
begin
	fmt(x::AbstractFloat; digits::Int=7) = isnan(x) ? "NaN" : isinf(x) ? string(x) : @sprintf("%.*e", digits, Float64(x))
	fmt(x::Real; digits::Int=7) = @sprintf("%.*e", digits, Float64(x))
	fmt(x) = string(x)

	function mdtable(headers, rows)
		escape_cell(x) = replace(string(x), "|" => "\\|")
		lines = String[]
		push!(lines, "| " * join(escape_cell.(headers), " | ") * " |")
		push!(lines, "|" * join(fill("---", length(headers)), "|") * "|")
		for row in rows
			push!(lines, "| " * join(escape_cell.(row), " | ") * " |")
		end
		Markdown.parse(join(lines, "\n"))
	end

	format_specs = [
		("Float16", 16, 1, 5, 10, 11, fmt(eps(Float16)), sizeof(Float16)),
		("Float32", 32, 1, 8, 23, 24, fmt(eps(Float32)), sizeof(Float32)),
		("Float64", 64, 1, 11, 52, 53, fmt(eps(Float64)), sizeof(Float64)),
	]

	mdtable(
		["Formato", "Bits", "Signo", "Exponente", "Fracción", "Precisión significando", "eps(1)", "Memoria/valor"],
		[(r[1], r[2], r[3], r[4], r[5], r[6], r[7], "$(r[8]) bytes") for r in format_specs],
	)
end

# ╔═╡ 6b34418c-2e02-4cdd-b7e4-0b1bce6b6106
begin
	function ulp_table(scales=(1.0, 10.0, 100.0, 1_000.0, 10_000.0))
		[(scale=s,
		  ulp16=Float64(nextfloat(Float16(s)) - Float16(s)),
		  ulp32=Float64(nextfloat(Float32(s)) - Float32(s)),
		  ulp64=nextfloat(Float64(s)) - Float64(s)) for s in scales]
	end

	ulps = ulp_table()
	mdtable(
		["Escala", "ULP Float16", "ULP Float32", "ULP Float64"],
		[(fmt(r.scale, digits=1), fmt(r.ulp16), fmt(r.ulp32), fmt(r.ulp64)) for r in ulps],
	)
end

# ╔═╡ 08aac5b4-cc02-4253-94be-f9940f2a6107
begin
	range_rows = [(string(T), fmt(floatmin(T)), fmt(nextfloat(zero(T))), fmt(floatmax(T))) for T in (Float16, Float32, Float64)]
	mdtable(["Formato", "Mínimo normal positivo", "Mínimo subnormal positivo", "Máximo finito"], range_rows)
end

# ╔═╡ 3753e01c-2f44-4cee-8cb1-492087922108
md"""
**Una primera pista.** `eps(T)` describe la separación en 1, mientras `eps(T(x))` o `nextfloat(T(x))-T(x)` muestra la resolución cerca de un valor concreto. La tabla deja ver que la “distancia entre números” cambia con la escala. `Float16` servirá como una lupa pedagógica; la pregunta central seguirá siendo `Float32` frente a `Float64`.
"""

# ╔═╡ 7c832c27-bdc4-40f5-86ab-ec5ab8dbf109
md"""
## 6. Diseño experimental

La idea que guía el experimento es esta: si el margen ``m=\operatorname{SMA}_{s}-\operatorname{SMA}_{l}`` es grande frente al error de cómputo, las señales deberían coincidir. Pero si ``|m|`` es comparable con la resolución y los redondeos, el signo podría cambiar.

Quise acercarme al problema por capas. Primero observé cuándo dos números distintos se vuelven indistinguibles. Después implementé una media móvil cuyo tipo se pudiera auditar, busqué por código un caso de desacuerdo y repetí el experimento con muchas series. Finalmente varié la escala y llevé la pregunta a una serie financiera real.

Los formatos, la escala del precio, las ventanas, el ruido, la tendencia y la semilla son variables explícitas. La salida principal es sencilla —si las dos precisiones toman o no la misma decisión—, pero también conservo el margen y el error numérico para entender *por qué* ocurre.

Toda aleatoriedad nace de `MersenneTwister(seed)`. Las cifras, tablas y gráficas se calculan desde las mismas estructuras; no hay resultados importantes escritos a mano.
"""

# ╔═╡ bf8c7454-1fe0-4d1d-9125-e3797142b110
begin
	@bind short_window Slider(3:2:11, default=5, show_value=true)
end

# ╔═╡ e63fbbd3-474c-4424-a9f5-d8ed7091b111
begin
	@bind long_window Slider(15:5:40, default=25, show_value=true)
end

# ╔═╡ 541e55d8-eb74-4349-a987-1a0af2dc2112
begin
	@bind base_price Select([1.0, 10.0, 100.0, 1_000.0, 10_000.0], default=100.0)
end

# ╔═╡ e9a067fc-6a4d-47cb-90be-69b76d6b6113
begin
	@bind noise_ulps Slider(0.1:0.1:2.0, default=0.6, show_value=true)
end

# ╔═╡ 66495e2f-d876-4b23-8225-495505791114
begin
	@bind random_seed Slider(1:100, default=42, show_value=true)
end

# ╔═╡ 39258468-1fce-4502-b438-78cd841a0115
begin
	@bind n_simulations Slider(20:20:100, default=60, show_value=true)
end

# ╔═╡ a94a4d7e-7bd0-4a74-aa6e-4d33f9f60116
md"""
**Controles interactivos.** Ventanas: corta **$(short_window)**, larga **$(long_window)**; escala **$(base_price)**; ruido **$(noise_ulps) ULP₃₂**; semilla **$(random_seed)**; simulaciones **$(n_simulations)**. Las amplitudes se expresan en ULP de `Float32` para que la cercanía a su resolución sea interpretable.
"""

# ╔═╡ 5c5e6a34-a219-4dd4-9881-c71e0d72a117
begin
	"""SMA directa: cada ventana se suma desde cero usando exclusivamente T."""
	function moving_average(x::AbstractVector{T}, window::Integer) where {T<:AbstractFloat}
		window > 0 || throw(ArgumentError("window debe ser positivo"))
		window <= length(x) || throw(ArgumentError("window excede la serie"))
		out = fill(T(NaN), length(x))
		denominator = T(window)
		for i in window:length(x)
			acc = zero(T)
			for j in (i-window+1):i
				acc = acc + x[j]
			end
			out[i] = acc / denominator
		end
		out
	end

	"""SMA centrada: suma desviaciones respecto al primer dato de cada ventana."""
	function moving_average_centered(x::AbstractVector{T}, window::Integer) where {T<:AbstractFloat}
		window > 0 || throw(ArgumentError("window debe ser positivo"))
		window <= length(x) || throw(ArgumentError("window excede la serie"))
		out = fill(T(NaN), length(x))
		denominator = T(window)
		for i in window:length(x)
			anchor = x[i-window+1]
			acc = zero(T)
			for j in (i-window+1):i
				acc = acc + (x[j] - anchor)
			end
			out[i] = anchor + acc / denominator
		end
		out
	end

	signal(short, long) = short > long
	label_signal(x::Bool) = x ? "COMPRAR" : "NO COMPRAR"
end

# ╔═╡ c31cc486-8e9f-48f6-a976-67866adb7118
begin
	probe32 = Float32[100, nextfloat(Float32(100)), prevfloat(Float32(100))]
	probe64 = Float64.(probe32)
	type_audit = [
		("entrada Float32", string(eltype(probe32))),
		("SMA Float32", string(eltype(moving_average(probe32, 2)))),
		("valor SMA Float32", string(typeof(moving_average(probe32, 2)[end]))),
		("entrada Float64", string(eltype(probe64))),
		("SMA Float64", string(eltype(moving_average(probe64, 2)))),
		("valor SMA Float64", string(typeof(moving_average(probe64, 2)[end]))),
		("denominador Float32", string(typeof(Float32(2)))),
	]
	mdtable(["Comprobación", "Tipo observado"], type_audit)
end

# ╔═╡ 1a9a345b-6da9-40f0-8798-39efe1228119
md"""
**Precisión efectiva.** En la SMA, `acc`, cada elemento, el denominador y la salida son `T`; no aparece un literal `2.0` que promueva el cálculo. Matiz importante: Julia almacena `Float16` en 16 bits, pero su documentación indica que sus operaciones se implementan en software usando `Float32`; el resultado se convierte nuevamente a `Float16`. Por eso lo usamos como contraste de formato, no como afirmación sobre hardware nativo de media precisión.

## 7. Experimento 1 — representabilidad cerca de un precio
"""

# ╔═╡ 691a4625-1d79-4742-b984-b0037af2c120
begin
	function find_representation_collision(base::Float64=100.0)
		u32 = Float64(nextfloat(Float32(base)) - Float32(base))
		for k in 1:128
			candidate = base + (k / 256) * u32
			if candidate != base && Float32(candidate) == Float32(base)
				return (a=base, b=candidate, fraction=k//256, ulp32=u32)
			end
		end
		error("No se encontró colisión en el intervalo buscado")
	end

	collision = find_representation_collision(100.0)
	mdtable(
		["Cantidad", "A", "B", "¿A = B?"],
		[
			("Referencia Float64", fmt(collision.a, digits=12), fmt(collision.b, digits=12), collision.a == collision.b),
			("Convertido a Float32", fmt(Float32(collision.a), digits=12), fmt(Float32(collision.b), digits=12), Float32(collision.a) == Float32(collision.b)),
		],
	)
end

# ╔═╡ fb2400cb-488a-4e67-8fc9-ab1473993121
let
	fraction_text = "$(numerator(collision.fraction))/$(denominator(collision.fraction))"
	Markdown.parse("""
	El buscador recorrió fracciones de la ULP local; no le entregué dos precios preparados para que fallara. Encontró que la separación entre los valores es **$(fraction_text) × ULP₃₂**. Es decir:

	**B = A + $(fraction_text) × ULP₃₂**

	Para `Float64`, A y B son distintos. Al convertirlos a `Float32`, ambos caen en la misma casilla representable. La primera sorpresa aparece muy pronto: la diferencia puede perderse **al convertir el dato**, antes incluso de calcular una media.

	## 8. Experimento 2 — una SMA transparente

	La función `moving_average` suma cada ventana desde cero. Preferí esta versión sencilla porque deja ver con claridad el tipo del acumulador y evita esconder el fenómeno detrás de una optimización. Más adelante usaré una variante centrada para preguntar cuánto depende el resultado de la forma de sumar.

	## 9. Experimento 3 — búsqueda de un cambio de decisión
	""")
end

# ╔═╡ 53ba5c73-2bd4-49d5-a48a-493739025122
begin
	function find_controlled_disagreement(base::Real=100, ws::Int=5, wl::Int=25)
		ws < wl || throw(ArgumentError("la ventana corta debe ser menor"))
		result = setprecision(256) do
			b = BigFloat(base)
			u32 = BigFloat(Float64(eps(Float32(base))))
			for k in 1:1024
				delta = BigFloat(k) / BigFloat(1024) * u32
				xbig = fill(b, wl)
				xbig[(wl-ws+1):wl] .+= delta
				x64, x32 = Float64.(xbig), Float32.(xbig)
				sb = moving_average(xbig, ws)[end]
				lb = moving_average(xbig, wl)[end]
				s64 = moving_average(x64, ws)[end]
				l64 = moving_average(x64, wl)[end]
				s32 = moving_average(x32, ws)[end]
				l32 = moving_average(x32, wl)[end]
				if signal(s64, l64) != signal(s32, l32)
					return (; k, delta, xbig, x64, x32, sb, lb, s64, l64, s32, l32)
				end
			end
			nothing
		end
		isnothing(result) && error("No se encontró desacuerdo; revise el dominio de búsqueda")
		result
	end

	controlled = find_controlled_disagreement(100, short_window, long_window)
	d64_controlled = controlled.s64 - controlled.l64
	d32_controlled = controlled.s32 - controlled.l32
	dbig_controlled = controlled.sb - controlled.lb
	abs_error_controlled = abs(d64_controlled - Float64(d32_controlled))
	rel_error_controlled = abs(d64_controlled) > 0 ? abs_error_controlled / abs(d64_controlled) : NaN

	mdtable(
		["Cálculo", "SMA corta", "SMA larga", "Diferencia", "Señal"],
		[
			("BigFloat (256 bits)", fmt(controlled.sb, digits=12), fmt(controlled.lb, digits=12), fmt(dbig_controlled, digits=12), label_signal(signal(controlled.sb, controlled.lb))),
			("Float64", fmt(controlled.s64, digits=12), fmt(controlled.l64, digits=12), fmt(d64_controlled, digits=12), label_signal(signal(controlled.s64, controlled.l64))),
			("Float32", fmt(controlled.s32, digits=12), fmt(controlled.l32, digits=12), fmt(d32_controlled, digits=12), label_signal(signal(controlled.s32, controlled.l32))),
		],
	)
end

# ╔═╡ c9dd0e1c-c2d4-49ed-a4a4-f410f49cc123
let
	total_observations = long_window
	initial_observations = long_window - short_window
	final_observations = short_window
	initial_value = fmt(controlled.xbig[1], digits=12)
	final_value = fmt(controlled.xbig[end], digits=12)
	delta_value = fmt(controlled.delta, digits=12)
	abs_error_value = fmt(abs_error_controlled, digits=12)
	rel_error_value = fmt(rel_error_controlled, digits=5)
	search_step = controlled.k

	Markdown.parse("""
	**El caso que encontró el programa**

	- Observaciones totales: **$(total_observations)**.
	- Primeras **$(initial_observations)** observaciones: valor **$(initial_value)**.
	- Últimas **$(final_observations)** observaciones: valor **$(final_value)**.
	- Desplazamiento aplicado a las últimas observaciones: **$(delta_value)**.
	- Primer paso aceptado por la búsqueda: **$(search_step)**.
	- Error absoluto entre los márgenes `Float64` y `Float32`: **$(abs_error_value)**.
	- Error relativo respecto al margen `Float64`: **$(rel_error_value)**.

	El error relativo es grande porque su denominador —el margen— está deliberadamente cerca de cero; no significa que el precio tenga un error relativo grande.

	Este caso no dice con qué frecuencia sucede en un mercado. Dice algo más modesto, pero importante: **puede suceder**, y podemos seguir la causa. Al redondear las últimas observaciones a `Float32`, desaparece una diferencia que `Float64` y la referencia de 256 bits todavía ven. Un ejemplo convincente puede seducir demasiado, así que el siguiente paso es comprobar que la conclusión no dependa sólo de él.
	""")
end

# ╔═╡ 2cf520f7-eed5-418a-b8b3-d160c33c3124
begin
	function synthetic_prices(seed::Integer, n::Integer, base::Real;
		amplitude_ulps::Real=6.0, noise_ulps::Real=0.6, trend_ulps::Real=0.8,
		period::Real=47.0, amplitude_abs=nothing, noise_abs=nothing)
		rng = MersenneTwister(seed)
		b = Float64(base)
		u = Float64(eps(Float32(b)))
		amplitude = isnothing(amplitude_abs) ? Float64(amplitude_ulps) * u : Float64(amplitude_abs)
		noise = isnothing(noise_abs) ? Float64(noise_ulps) * u : Float64(noise_abs)
		trend = Float64(trend_ulps) * u
		phase = 2π * rand(rng)
		[b + amplitude * sin(2π * t / period + phase) +
		 trend * (t - (n + 1) / 2) / n + noise * randn(rng) for t in 1:n]
	end

	function compare_precisions(prices64::Vector{Float64}, ws::Int, wl::Int;
		ma=moving_average)
		x32 = Float32.(prices64)
		s64, l64 = ma(prices64, ws), ma(prices64, wl)
		s32, l32 = ma(x32, ws), ma(x32, wl)
		idx = wl:length(prices64)
		d64 = s64[idx] .- l64[idx]
		d32 = s32[idx] .- l32[idx]
		sig64 = d64 .> 0
		sig32 = d32 .> 0
		errors = abs.(d64 .- Float64.(d32))
		(; idx, x32, s64, l64, s32, l32, d64, d32, sig64, sig32,
		 disagreements=sig64 .!= sig32, errors)
	end

	function monte_carlo(nsims::Int, n::Int, base::Real, ws::Int, wl::Int;
		seed::Int=2026, amplitude_ulps=6.0, noise_ulps=0.6,
		amplitude_abs=nothing, noise_abs=nothing, ma=moving_average)
		all_d64 = Float64[]
		all_d32 = Float32[]
		all_disagreements = Bool[]
		all_errors = Float64[]
		for sim in 1:nsims
			p = synthetic_prices(seed + sim, n, base;
				amplitude_ulps, noise_ulps, amplitude_abs, noise_abs)
			c = compare_precisions(p, ws, wl; ma)
			append!(all_d64, c.d64)
			append!(all_d32, c.d32)
			append!(all_disagreements, c.disagreements)
			append!(all_errors, c.errors)
		end
		total = length(all_disagreements)
		different = count(all_disagreements)
		(; total, equal=total-different, different,
		 pct=100*different/total, max_error=maximum(all_errors),
		 mean_abs_error=mean(all_errors), d64=all_d64, d32=all_d32,
		 disagreements=all_disagreements, errors=all_errors,
		 ulp32=Float64(eps(Float32(base))))
	end
end

# ╔═╡ 42c3c347-7ca4-4463-9476-1411c50cf125
begin
	n_observations = 360
	prices = synthetic_prices(random_seed, n_observations, base_price;
		amplitude_ulps=6.0, noise_ulps=noise_ulps)
	comparison = compare_precisions(prices, short_window, long_window)
	mc = monte_carlo(n_simulations, 260, base_price, short_window, long_window;
		seed=10_000 + random_seed, noise_ulps=noise_ulps)

	mdtable(
		["Métrica", "Resultado calculado"],
		[
			("Decisiones totales", mc.total),
			("Decisiones iguales", mc.equal),
			("Decisiones diferentes", mc.different),
			("Porcentaje de desacuerdo", @sprintf("%.4f %%", mc.pct)),
			("Máx. |margen₆₄ − margen₃₂|", fmt(mc.max_error)),
			("Media del error absoluto", fmt(mc.mean_abs_error)),
		],
	)
end

# ╔═╡ cb24e175-3213-49f4-b12f-1e529bf24126
md"""
## 10. Experimento sistemático Monte Carlo

Un solo contraejemplo responde “¿puede ocurrir?”, pero no muestra el paisaje alrededor del fenómeno. Por eso repetí el experimento. Cada réplica contiene una oscilación suave, una tendencia diminuta y ruido independiente alrededor de la escala elegida. Así aparecen cruces legítimos sin obligar al programa a producir desacuerdos. La tabla reúne $(n_simulations) series y $(mc.total) decisiones válidas.

Un porcentaje pequeño no borra el fenómeno; uno grande tampoco demuestra pérdidas monetarias. Lo que estoy midiendo es la sensibilidad numérica de **esta regla bajo este generador**, no la rentabilidad de una estrategia.
"""

# ╔═╡ de1af706-784e-4f08-bde4-f28e87c76127
begin
	function threshold_bins(mc_result)
		edges = [0.0, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, Inf]
		rows = NamedTuple[]
		margins = abs.(mc_result.d64) ./ mc_result.ulp32
		for i in 1:length(edges)-1
			mask = (margins .>= edges[i]) .& (margins .< edges[i+1])
			n = count(mask)
			d = n == 0 ? 0 : count(mc_result.disagreements[mask])
			label = isinf(edges[i+1]) ? "≥ $(edges[i])" : "[$(edges[i]), $(edges[i+1]))"
			push!(rows, (interval=label, n=n, different=d, pct=n == 0 ? 0.0 : 100*d/n))
		end
		rows
	end

	threshold_summary = threshold_bins(mc)
	mdtable(
		["|margen Float64| / ULP₃₂", "Decisiones", "Desacuerdos", "% desacuerdo"],
		[(r.interval, r.n, r.different, @sprintf("%.3f", r.pct)) for r in threshold_summary],
	)
end

# ╔═╡ dc922fd7-12d4-4e8a-b568-30b4f7331128
md"""
**La distancia que realmente importa.** Clasifiqué *todas* las decisiones, no sólo las discordantes, según la distancia del margen `Float64` a cero medida en ULP₃₂. El patrón empieza a aclararse: lejos del umbral, el error no alcanza a cruzarlo; cerca de cero, la misma perturbación puede invertir el signo o borrarlo.

## 11. Gráficas de la evidencia
"""

# ╔═╡ 973ef68d-c492-469e-9449-1c440c43c129
begin
	plot_indices = long_window:n_observations
	p1 = plot(1:n_observations, prices, color=:gray55, lw=1, alpha=0.7,
		label="Precio (referencia Float64)", title="Gráfica 1 — Serie y medias móviles",
		xlabel="Tiempo (observación)", ylabel="Precio (unidades monetarias)")
	plot!(p1, plot_indices, comparison.s64[plot_indices], lw=2, label="SMA corta Float64")
	plot!(p1, plot_indices, comparison.l64[plot_indices], lw=2, label="SMA larga Float64")
	p1
end

# ╔═╡ a7b8af27-98fb-4791-af70-255e363f5130
md"""
**Cómo leerla.** La SMA corta responde primero a la oscilación. Allí donde las curvas casi se tocan aparece la zona interesante: una decisión puede estar sostenida por un margen diminuto. La figura da contexto temporal; no pretende imitar retornos reales.
"""

# ╔═╡ 662f2b0d-bffb-4686-9655-29cac7869131
begin
	disagreement_positions = findall(comparison.disagreements)
	focus_local = isempty(disagreement_positions) ? argmin(abs.(comparison.d64)) : first(disagreement_positions)
	focus_t = comparison.idx[focus_local]
	zoom = max(long_window, focus_t-8):min(n_observations, focus_t+8)
	p2 = plot(zoom, comparison.s64[zoom], marker=:circle, ms=3, lw=2,
		label="SMA corta 64", title="Gráfica 2 — Zoom cerca de una decisión sensible",
		xlabel="Tiempo (observación)", ylabel="Media móvil (unidades monetarias)")
	plot!(p2, zoom, comparison.l64[zoom], marker=:circle, ms=3, lw=2, label="SMA larga 64")
	plot!(p2, zoom, Float64.(comparison.s32[zoom]), ls=:dash, lw=2, label="SMA corta 32")
	plot!(p2, zoom, Float64.(comparison.l32[zoom]), ls=:dash, lw=2, label="SMA larga 32")
	vline!(p2, [focus_t], color=:black, ls=:dot, label="punto focal")
	p2
end

# ╔═╡ bbd6158b-6901-4d8f-acd9-b6372adb1132
md"""
**Al acercarnos.** El zoom busca el primer desacuerdo de la serie interactiva; si esa realización no tiene ninguno, muestra honestamente su margen más pequeño. Dos curvas que el ojo percibe como una sola todavía pueden quedar en lados opuestos de una comparación.
"""

# ╔═╡ 3588ed2a-e4c5-42c0-8be2-9887fa63a133
begin
	dzoom_mask = findall(t -> t in zoom, comparison.idx)
	p3 = plot(comparison.idx[dzoom_mask], comparison.d64[dzoom_mask], marker=:circle,
		lw=2, label="margen Float64", title="Gráfica 3 — Margen de decisión alrededor de cero",
		xlabel="Tiempo (observación)", ylabel="SMA corta − SMA larga")
	plot!(p3, comparison.idx[dzoom_mask], Float64.(comparison.d32[dzoom_mask]),
		marker=:diamond, ls=:dash, lw=2, label="margen Float32")
	hline!(p3, [0.0], color=:black, lw=1.5, label="umbral = 0")
	p3
end

# ╔═╡ 818e7d38-7c64-441d-98c1-6f50885b4134
md"""
**Aquí está el salto.** Por encima de cero se compra; en cero o por debajo, no. La escala vertical hace visible una diferencia que desaparecía en la gráfica de precios. El número cambia poco, pero la decisión no sabe cambiar “un poco”.
"""

# ╔═╡ 1e995594-7292-440f-909e-29c382570135
begin
	p4 = plot(comparison.idx, comparison.errors, color=:darkorange, lw=1.5,
		label="|margen₆₄ − margen₃₂|", title="Gráfica 4 — Error numérico a través del tiempo",
		xlabel="Tiempo (observación)", ylabel="Error absoluto (unidades monetarias)")
	p4
end

# ╔═╡ 27659a07-df77-4421-bfe9-195bedeb4136
md"""
**Una diferencia pequeña, ¿respecto a qué?** En unidades de precio el error parece minúsculo. Sólo adquiere significado al compararlo con el margen que separa la decisión del umbral, no con el precio completo.
"""

# ╔═╡ 5bd48995-c3bb-413f-9726-0544f51f5137
begin
	p5 = bar([r.interval for r in threshold_summary], [r.pct for r in threshold_summary],
		legend=false, color=:steelblue, title="Gráfica 5 — Desacuerdo según distancia al umbral",
		xlabel="|margen Float64| / ULP₃₂", ylabel="Decisiones diferentes (%)",
		xrotation=25)
	p5
end

# ╔═╡ 85fb3d9b-7af9-48fb-a868-38f64231d138
md"""
**El patrón.** La distancia al umbral organiza el riesgo de cambio mucho mejor que el error absoluto aislado. Las barras vacías no son fallos: indican que esa simulación no produjo observaciones dentro del intervalo.
"""

# ╔═╡ 48fc7c63-7a46-4a92-9659-6b619ca73139
begin
	scale_values = [r.scale for r in ulps]
	p6 = plot(scale_values, [r.ulp16 for r in ulps], marker=:circle, lw=2,
		xscale=:log10, yscale=:log10, label="Float16",
		title="Gráfica 6 — Resolución efectiva y escala",
		xlabel="Escala del valor", ylabel="ULP (separación absoluta)")
	plot!(p6, scale_values, [r.ulp32 for r in ulps], marker=:circle, lw=2, label="Float32")
	plot!(p6, scale_values, [r.ulp64 for r in ulps], marker=:circle, lw=2, label="Float64")
	p6
end

# ╔═╡ c83d3abe-abde-45d2-88db-cef2cd8f6140
md"""
**La escala también habla.** Dentro de un intervalo binario la precisión relativa es aproximadamente constante, pero la separación **absoluta** crece por escalones con la magnitud. Decir “siete dígitos decimales” oculta esta parte de la historia: no existe una única resolución monetaria para todo valor.

## 12. Sensibilidad a la escala
"""

# ╔═╡ 65a81845-737b-4999-8870-63498fa25141
begin
	scales = [1.0, 10.0, 100.0, 1_000.0, 10_000.0]
	# Perturbación absoluta fija: al crecer la base, ocupa menos ULP Float32.
	scale_results = [monte_carlo(min(n_simulations, 60), 220, s, short_window, long_window;
		seed=20_000 + random_seed, amplitude_abs=5e-5, noise_abs=8e-6) for s in scales]
	mdtable(
		["Escala", "ULP Float32", "ULP Float64", "Desacuerdos", "% desacuerdo"],
		[(fmt(s, digits=1), fmt(eps(Float32(s))), fmt(eps(Float64(s))),
		  r.different, @sprintf("%.4f", r.pct)) for (s, r) in zip(scales, scale_results)],
	)
end

# ╔═╡ 94eb02b7-34a3-4a18-80b8-a5b28b40d142
md"""
**Qué esperaba encontrar aquí.** Mantengo la señal pequeña en unidades absolutas mientras cambia el precio base. No espero una curva perfectamente monótona —la suma también redondea y las celdas binarias cambian por escalones—, pero sí observar cuándo la ULP₃₂ empieza a competir con la señal. Si una escala no produce desacuerdos, también es un resultado: bajo esas condiciones, `Float32` fue suficiente.

## 13. Float16 como contraste y efecto del algoritmo de suma
"""

# ╔═╡ c16cb4c3-b337-4ee1-94c0-f7fc5412a143
begin
	function compare_type_to_64(::Type{T}, prices64, ws, wl; ma=moving_average) where {T<:AbstractFloat}
		xT = T.(prices64)
		s64, l64 = moving_average(prices64, ws), moving_average(prices64, wl)
		sT, lT = ma(xT, ws), ma(xT, wl)
		idx = wl:length(prices64)
		d64 = s64[idx] .- l64[idx]
		dT = sT[idx] .- lT[idx]
		finite_mask = isfinite.(d64) .& isfinite.(dT)
		nonfinite = count(.!finite_mask)
		dis = (d64[finite_mask] .> 0) .!= (dT[finite_mask] .> 0)
		total = count(finite_mask)
		(total, nonfinite, different=count(dis),
		 pct=total == 0 ? NaN : 100*count(dis)/total,
		 mean_error=total == 0 ? NaN : mean(abs.(d64[finite_mask] .- Float64.(dT[finite_mask]))))
	end

	type_comparison = [compare_type_to_64(T, prices, short_window, long_window) for T in (Float16, Float32, Float64)]
	centered32 = compare_type_to_64(Float32, prices, short_window, long_window; ma=moving_average_centered)
	mdtable(
		["Método/formato vs Float64 directa", "Decisiones finitas", "No finitas", "Desacuerdos", "%", "Error medio del margen"],
		vcat(
			[("SMA directa $(T)", r.total, r.nonfinite, r.different, isnan(r.pct) ? "N/A" : @sprintf("%.3f", r.pct), fmt(r.mean_error)) for (T, r) in zip((Float16, Float32, Float64), type_comparison)],
			[("SMA centrada Float32", centered32.total, centered32.nonfinite, centered32.different, isnan(centered32.pct) ? "N/A" : @sprintf("%.3f", centered32.pct), fmt(centered32.mean_error))],
		),
	)
end

# ╔═╡ 44895b55-940c-4347-aa3c-c9fd315ea144
md"""
No propongo `Float16` como formato habitual para precios; lo uso porque exagera el problema y permite verlo mejor. Si la escala y la ventana hacen que la suma intermedia supere `floatmax(Float16)`, aparece `Inf` aunque la media matemática sea finita: el camino del cálculo importa tanto como su destino. La SMA centrada cuenta la misma historia algebraica de otra manera, sumando desviaciones pequeñas alrededor de un ancla. Puede reducir el redondeo, pero no resucitar información perdida al convertir los datos. Así pude separar tres fuentes del problema: **representación de las entradas**, **propagación durante las operaciones** y **rango de los valores intermedios**.

## 14. Comprobación secundaria con datos financieros reales

Después de trabajar con series construidas cerca del límite, quise mirar datos que no hubieran sido elegidos para hacer fallar a `Float32`. Usé una copia **integrada en este notebook** de la serie diaria **dólares estadounidenses por euro (DEXUSEU)** de FRED, correspondiente al primer semestre de 2025. El notebook no consulta Internet ni necesita archivos externos. Estas cotizaciones tienen una resolución decimal mucho mayor que la ULP de `Float32` cerca de esos valores, pero preferí medir antes que dar por hecho el resultado.
"""

# ╔═╡ 87c63ca7-6e5e-4820-ae61-4f187246f145
begin
	DEXUSEU_2025_H1 = raw"""observation_date,DEXUSEU
2025-01-02,1.0261
2025-01-03,1.0292
2025-01-06,1.0397
2025-01-07,1.0369
2025-01-08,1.0313
2025-01-09,1.0298
2025-01-10,1.0238
2025-01-13,1.0209
2025-01-14,1.0292
2025-01-15,1.0282
2025-01-16,1.0303
2025-01-17,1.0287
2025-01-20,
2025-01-21,1.0423
2025-01-22,1.0420
2025-01-23,1.0420
2025-01-24,1.0515
2025-01-27,1.0492
2025-01-28,1.0427
2025-01-29,1.0416
2025-01-30,1.0420
2025-01-31,1.0400
2025-02-03,1.0277
2025-02-04,1.0379
2025-02-05,1.0419
2025-02-06,1.0368
2025-02-07,1.0329
2025-02-10,1.0312
2025-02-11,1.0346
2025-02-12,1.0392
2025-02-13,1.0428
2025-02-14,1.0498
2025-02-17,
2025-02-18,1.0457
2025-02-19,1.0406
2025-02-20,1.0475
2025-02-21,1.0455
2025-02-24,1.0478
2025-02-25,1.0498
2025-02-26,1.0514
2025-02-27,1.0414
2025-02-28,1.0402
2025-03-03,1.0496
2025-03-04,1.0534
2025-03-05,1.0768
2025-03-06,1.0818
2025-03-07,1.0859
2025-03-10,1.0837
2025-03-11,1.0927
2025-03-12,1.0925
2025-03-13,1.0859
2025-03-14,1.0872
2025-03-17,1.0922
2025-03-18,1.0927
2025-03-19,1.0877
2025-03-20,1.0848
2025-03-21,1.0806
2025-03-24,1.0794
2025-03-25,1.0804
2025-03-26,1.0781
2025-03-27,1.0800
2025-03-28,1.0826
2025-03-31,1.0796
2025-04-01,1.0800
2025-04-02,1.0868
2025-04-03,1.1052
2025-04-04,1.1014
2025-04-07,1.0912
2025-04-08,1.0912
2025-04-09,1.1040
2025-04-10,1.1192
2025-04-11,1.1325
2025-04-14,1.1358
2025-04-15,1.1290
2025-04-16,1.1382
2025-04-17,1.1364
2025-04-18,1.1390
2025-04-21,1.1508
2025-04-22,1.1466
2025-04-23,1.1350
2025-04-24,1.1363
2025-04-25,1.1381
2025-04-28,1.1387
2025-04-29,1.1396
2025-04-30,1.1349
2025-05-01,1.1279
2025-05-02,1.1330
2025-05-05,1.1315
2025-05-06,1.1345
2025-05-07,1.1348
2025-05-08,1.1249
2025-05-09,1.1270
2025-05-12,1.1106
2025-05-13,1.1176
2025-05-14,1.1206
2025-05-15,1.1189
2025-05-16,1.1141
2025-05-19,1.1236
2025-05-20,1.1254
2025-05-21,1.1343
2025-05-22,1.1281
2025-05-23,1.1350
2025-05-26,
2025-05-27,1.1326
2025-05-28,1.1286
2025-05-29,1.1370
2025-05-30,1.1347
2025-06-02,1.1432
2025-06-03,1.1373
2025-06-04,1.1424
2025-06-05,1.1440
2025-06-06,1.1397
2025-06-09,1.1425
2025-06-10,1.1423
2025-06-11,1.1490
2025-06-12,1.1578
2025-06-13,1.1557
2025-06-16,1.1581
2025-06-17,1.1535
2025-06-18,1.1521
2025-06-19,
2025-06-20,1.1520
2025-06-23,1.1538
2025-06-24,1.1608
2025-06-25,1.1620
2025-06-26,1.1717
2025-06-27,1.1724
2025-06-30,1.1770"""

	function parse_embedded_prices(csv::AbstractString)
		dates = String[]
		values = Float64[]
		for line in Iterators.drop(eachline(IOBuffer(csv)), 1)
			parts = split(strip(line), ',')
			length(parts) == 2 || continue
			value = tryparse(Float64, parts[2])
			isnothing(value) && continue
			push!(dates, parts[1]); push!(values, value)
		end
		(; dates, values)
	end

	real_data = parse_embedded_prices(DEXUSEU_2025_H1)
	real_comparison = compare_precisions(real_data.values, 5, 20)
	mdtable(
		["Serie local", "Observaciones", "Decisiones", "Desacuerdos 32/64", "%"],
		[("FRED DEXUSEU, 2025-01-02 a 2025-06-30", length(real_data.values),
		  length(real_comparison.idx), count(real_comparison.disagreements),
		  @sprintf("%.6f", 100*mean(real_comparison.disagreements)))],
	)
end

# ╔═╡ a2810628-b9c8-48df-acf6-8b06b3724146
md"""
**Una lectura sin forzar el resultado.** Esta serie no fue filtrada para encontrar fallos. Si aparecen cero desacuerdos, la conclusión correcta es limitada: `Float32` fue suficiente para estos datos, estas ventanas y esta regla. Eso no contradice el caso controlado, pero tampoco permite generalizar a datos intradía, otros indicadores o escalas diferentes.

## 15. Resultados

Las tablas y gráficas no están allí para decorar una respuesta; son la respuesta. El caso controlado muestra que el cambio de decisión es posible, Monte Carlo explora con qué frecuencia aparece bajo condiciones explícitas y DEXUSEU ofrece el contraste de una serie que no fue escogida para producir desacuerdos.

## 16. ¿Por qué ocurre?

La explicación terminó siendo más sencilla y, al mismo tiempo, más profunda de lo que esperaba. La regla es una función discontinua:

```math
D(x,y)=\begin{cases}1,&x>y,\\0,&x\le y.\end{cases}
```

Sean ``x,y`` las medias de referencia y ``\hat x=x+e_x``, ``\hat y=y+e_y`` sus aproximaciones. El margen perturbado es

```math
\hat m=(\hat x-\hat y)=(x-y)+(e_x-e_y)=m+\Delta e.
```

Si ``|m|>|\Delta e|`` y el error no apunta más allá del umbral, el signo se conserva. Si ``|m|\lesssim|\Delta e|``, el signo puede invertirse o un margen positivo puede redondearse a cero. Entonces

```math
D(\hat x,\hat y)\ne D(x,y),
```

aunque ``|e_x|`` y ``|e_y|`` sean minúsculos respecto al nivel del precio. La resta de medias cercanas deja al descubierto el error previo por cancelación, y la comparación amplifica su consecuencia lógica. Ésta fue la conexión decisiva: una diferencia numérica pequeña no tiene por qué producir una diferencia pequeña en el comportamiento.

### Lo que la evidencia permite afirmar

1. La búsqueda controlada demuestra que **sí puede** cambiar la señal y registra el mecanismo exacto.
2. Monte Carlo distingue casos normales de casos sensibles y estima frecuencia solo bajo parámetros explícitos.
3. La estratificación por margen comprueba que la cercanía al umbral es la variable crítica.
4. La escala importa mediante la ULP absoluta y mediante los redondeos de la suma.
5. Cambiar la forma de sumar puede modificar el error, pero no recupera bits descartados en los datos.
"""

# ╔═╡ 69703e2d-a4c0-4385-b649-71fc6d911147
md"""
## 17. Limitaciones y revisión crítica

- Las series sintéticas están construidas deliberadamente cerca de la resolución `Float32`. Son adecuadas para identificar causalidad y frontera de fallo, no para estimar prevalencia en un mercado.
- Un desacuerdo de señal no equivale por sí mismo a pérdida financiera; faltan costos, latencia, ejecución, posición y retorno posterior.
- `BigFloat(256)` aproxima la serie matemática construida y sirve como control; no es una representación del “precio real verdadero”.
- Las diferencias proceden del formato y de la secuencia de operaciones. Usamos el mismo algoritmo en ambos tipos y auditamos `eltype`; la comparación centrada expone el efecto algorítmico adicional.
- No atribuimos a la precisión patrones causados por aleatoriedad: cada réplica calcula ambas precisiones sobre la **misma** serie subyacente.
- La regla `>` define que un empate es `NO COMPRAR`. Otra política de empate, una tolerancia o histéresis cambiaría la sensibilidad y debería especificarse como parte del algoritmo.

El experimento dejó abierta otra pregunta que ahora me parece inevitable: **¿qué banda de tolerancia o histéresis reduce cambios espurios sin retrasar demasiado una señal legítima?** No la respondo aquí porque implicaría cambiar la estrategia, pero es una continuación natural de lo aprendido.

## 18. Conclusión

La respuesta corta es **sí, bajo condiciones que podemos identificar**. En el caso encontrado por el buscador, `Float64` conserva un margen positivo mientras `Float32` redondea las observaciones o las medias hasta llegar a un empate o a otro signo. Con los controles predeterminados, Monte Carlo produjo **$(mc.different) desacuerdos de $(mc.total)** decisiones ($(round(mc.pct, digits=3)) %); la serie DEXUSEU, en cambio, produjo **$(count(real_comparison.disagreements)) desacuerdos**.

La respuesta importante tiene un matiz: esto no significa que `Float32` “falle siempre”. Lejos del umbral, las decisiones coinciden; en la serie real estudiada también coincidieron. El riesgo aparece cuando el error numérico y el margen de decisión viven en escalas parecidas.

Por eso ya no preguntaría simplemente cuántos decimales conserva un formato. Preguntaría si su error es pequeño frente al **margen de decisión** y qué operaciones tendrá que atravesar antes de llegar a él.

## 19. ¿Qué cambió en mi comprensión?

Al comenzar pensaba en los últimos decimales como un detalle del número almacenado. Ahora distingo dos escalas que antes mezclaba: el error frente al precio y el error frente al margen de decisión. Un error insignificante en la primera puede ser decisivo en la segunda, porque el umbral introduce un salto.

También cambió una idea más sutil. Elegir `Float32` o `Float64` no es la única decisión numérica: la forma de sumar y la manera de tratar un empate también forman parte del algoritmo. Después de este experimento, no llamaría a una precisión “alta” o “baja” en abstracto; preguntaría **alta o baja respecto a qué margen, bajo qué operaciones y para qué decisión**.
"""

# ╔═╡ a7af8eae-a480-445d-9884-41fd6132b148
md"""
## 20. Uso de inteligencia artificial

**Asistente utilizado:** ChatGPT/Codex de OpenAI.

Usé ChatGPT/Codex como compañero de exploración: me ayudó a convertir una intuición vaga en una pregunta comprobable, a diseñar los experimentos, depurar Julia, proponer visualizaciones y discutir interpretaciones alternativas. Dos preguntas que orientaron el trabajo fueron:

> ¿Puede un error pequeño de representación en `Float32` cambiar el resultado de una comparación utilizada para tomar una decisión algorítmica?

> ¿Cómo diseñar un experimento reproducible que determine cuándo `Float32` y `Float64` producen señales diferentes en un cruce de medias móviles?

**Lo que tuve que verificar y corregir.** No acepté como prueba que una variable se llamara “Float32”. Revisé `eltype` y `typeof`, y construí tanto el acumulador como el denominador en el tipo `T` para evitar promociones silenciosas. La documentación oficial confirmó que `1.0` es `Float64`, mientras `1.0f0` es `Float32`; una expresión aparentemente inocente podía cambiar la precisión real del experimento. También contrasté bits, epsilon, `nextfloat` y el comportamiento de los formatos con Julia e IEEE, y comprobé el caso crítico mediante `BigFloat(256)` y aserciones independientes. La IA ayudó a preguntar y a construir, pero no fue la autoridad final: los resultados los calcula el notebook y las afirmaciones técnicas se apoyan en fuentes verificables.

## Referencias

1. IEEE Computer Society. (2019). *IEEE Standard for Floating-Point Arithmetic*, IEEE 754-2019. [Página oficial del estándar](https://standards.ieee.org/ieee/754/6210/).
2. Goldberg, D. (1991). “What Every Computer Scientist Should Know About Floating-Point Arithmetic”. *ACM Computing Surveys*, 23(1), 5–48. DOI: [10.1145/103162.103163](https://doi.org/10.1145/103162.103163). [Reimpresión autorizada y navegable de Oracle](https://docs.oracle.com/cd/E19957-01/806-3568/ncg_goldberg.html).
3. Higham, N. J. (2002). *Accuracy and Stability of Numerical Algorithms*, 2.ª ed. SIAM. DOI: [10.1137/1.9780898718027](https://doi.org/10.1137/1.9780898718027).
4. The Julia Project. *Integers and Floating-Point Numbers*. [Manual oficial de Julia](https://docs.julialang.org/en/v1/manual/integers-and-floating-point-numbers/).
5. The Julia Project. *Numbers: Float16, Float32, Float64, eps, nextfloat*. [Documentación oficial](https://docs.julialang.org/en/v1/base/numbers/).
6. Board of Governors of the Federal Reserve System (US). *U.S. Dollars to Euro Spot Exchange Rate (DEXUSEU)*. [FRED, Federal Reserve Bank of St. Louis](https://fred.stlouisfed.org/series/DEXUSEU). Copia integrada del intervalo 2025-01-02–2025-06-30, descargada el 2026-09-14. Serie marcada por FRED como dominio público; se solicita atribución.

---

```math
\boxed{\text{Pregunta}\rightarrow\text{Experimento reproducible}\rightarrow\text{Evidencia}\rightarrow\text{Explicación}\rightarrow\text{Transformación intelectual}}
```
"""

# ╔═╡ 9522224b-87bf-4878-a315-809d2f9b1149
begin
	# Comprobaciones visibles y ejecutables: si una falla, Pluto muestra el error.
	@assert short_window < long_window
	@assert eltype(moving_average(Float32[1, 2, 3], 2)) === Float32
	@assert eltype(moving_average(Float64[1, 2, 3], 2)) === Float64
	@assert eltype(comparison.x32) === Float32
	@assert eltype(comparison.d32) === Float32
	@assert eltype(comparison.d64) === Float64
	@assert all(isfinite, comparison.d64) && all(isfinite, comparison.d32)
	@assert signal(controlled.s64, controlled.l64) != signal(controlled.s32, controlled.l32)
	@assert length(real_data.values) >= 20
	@assert length(threshold_summary) == 7
	@assert all(p -> p isa Plots.Plot, (p1, p2, p3, p4, p5, p6))
	md"✅ **Validaciones internas superadas:** tipos Float32/Float64, finitud, caso crítico, datos integrados, tabla de sensibilidad y seis gráficas."
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
DelimitedFiles = "8bb1440f-4735-579b-a4ab-409b98df4dab"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
Plots = "~1.41.7"
PlutoUI = "~0.7.83"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.5"
manifest_format = "2.0"
project_hash = "44f7dd23278abd461ee6c1d6bc63eb959e4422a8"

[[deps.AbstractPlutoDingetjes]]
git-tree-sha1 = "e71ee7b4aa06b045259a7d6101e1cb45ad140bce"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.4.1"

[[deps.AliasTables]]
deps = ["PtrArrays", "Random"]
git-tree-sha1 = "9876e1e164b144ca45e9e3198d0b689cadfed9ff"
uuid = "66dad0bd-aa9a-41b7-9441-69ab47430ed8"
version = "1.1.3"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1b96ea4a01afe0ea4090c5c8039690672dd13f2e"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.9+0"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "1fa950ebc3e37eccd51c6a8fe1f92f7d86263522"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.7+0"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "b0fd3f56fa442f81e0a47815c92245acfaaa4e34"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.31.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "67e11ee83a43eb71ddc950302c53bf33f0690dfe"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.1"

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

    [deps.ColorTypes.weakdeps]
    StyledStrings = "f489334b-da3d-4c2e-b8f0-e476e12c162b"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "8b3b6f87ce8f65a2b4f857528fd8d70086cd72b1"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.11.0"

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

    [deps.ColorVectorSpace.weakdeps]
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "37ea44092930b1811e666c3bc38065d7d87fcc74"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.13.1"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.Contour]]
git-tree-sha1 = "439e35b0b36e2e5881738abc8857bd92ad6ff9a8"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.3"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataStructures]]
deps = ["OrderedCollections"]
git-tree-sha1 = "b0bc6d2cad1fed8b7fd59a1551a991cb3d2809e6"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.19.6"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Dbus_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "473e9afc9cf30814eb67ffa5f2db7df82c3ad9fd"
uuid = "ee1fde0b-3d02-5ea6-8484-8dfef6360eab"
version = "1.16.2+0"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DocStringExtensions]]
git-tree-sha1 = "7442a5dfe1ebb773c29cc2962a8980f47221d76c"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.5"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.EpollShim_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8a4be429317c42cfae6a7fc03c31bad1970c310d"
uuid = "2702e6a9-849d-5ed8-8c21-79e8b8f9ee43"
version = "0.0.20230411+1"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "2bfb1e047e2ad0a5ca94365340bde8005d637568"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.8.4+0"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "95ecf07c2eea562b5adbd0696af6db62c0f52560"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.5"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libva_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "7a58e45171b63ed4782f2d36fdee8713a469e6e0"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "8.1.2+0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Random", "Statistics"]
git-tree-sha1 = "59af96b98217c6ef4ae0dfe065ac7c20831d1a84"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.6"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "f85dac9a96a01087df6e3a749840015a0ca3817d"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.17.1+0"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "70329abc09b886fd2c5d94ad2d9527639c421e3e"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.14.3+1"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7a214fdac5ed5f59a22c2d9a885a16da1c74bbc7"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.17+0"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll", "libdecor_jll", "xkbcommon_jll"]
git-tree-sha1 = "64bbbb7d1499297751b536dd39c58b20750ab1db"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.5.1+0"

[[deps.GR]]
deps = ["Artifacts", "Base64", "DelimitedFiles", "Downloads", "GR_jll", "JSON", "Libdl", "LinearAlgebra", "Preferences", "Printf", "Qt6Wayland_jll", "Random", "Serialization", "Sockets", "TOML", "Tar", "Test", "p7zip_jll"]
git-tree-sha1 = "4d777f73c46b46b8b5276206059cf8a195499314"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.73.27"

    [deps.GR.extensions]
    IJuliaExt = "IJulia"

    [deps.GR.weakdeps]
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "FreeType2_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Qt6Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "f8eb8f7ba13ea75083531647fc8faeda8d541f07"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.73.27+0"

[[deps.GettextRuntime_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll"]
git-tree-sha1 = "45288942190db7c5f760f59c04495064eedf9340"
uuid = "b0724c58-0f36-5564-988d-3bb0596ebc4a"
version = "0.22.4+0"

[[deps.Ghostscript_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Zlib_jll"]
git-tree-sha1 = "38044a04637976140074d0b0621c1edf0eb531fd"
uuid = "61579ee1-b43e-5ca0-a5da-69d92c66a64b"
version = "9.55.1+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "GettextRuntime_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "090526e65de8f69648ac156daae153de8b56df62"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.88.3+0"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "69ffb934a5c5b7e086a0b4fee3427db2556fba6e"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.16+0"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "9d9531a9cb63a9edc33836414e82a07e81710de2"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "100.14004.0+0"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "d1a86724f81bcd184a38fd284ce183ec067d71a0"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "1.0.0"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "0ee181ec08df7d7c911901ea38baf16f755114dc"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "1.0.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.IrrationalConstants]]
git-tree-sha1 = "b2d91fe939cae05960e760110b328288867b5758"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.6"

[[deps.JLFzf]]
deps = ["REPL", "Random", "fzf_jll"]
git-tree-sha1 = "82f7acdc599b65e0f8ccd270ffa1467c21cb647b"
uuid = "1019f520-868f-41f5-a6de-eb00f4b6a39c"
version = "0.1.11"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7204148362dafe5fe6a273f855b8ccbe4df8173e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.8.0"

[[deps.JSON]]
deps = ["Dates", "Logging", "Parsers", "PrecompileTools", "StructUtils", "UUIDs", "Unicode"]
git-tree-sha1 = "88352712893ec50bee3680605891eaf0e9ed6368"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "1.8.0"

    [deps.JSON.extensions]
    JSONArrowExt = ["ArrowTypes"]

    [deps.JSON.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "037babc10853eeb8e585418922246cb97b8e5b74"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.2.0+1"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "059aabebaa7c82ccb853dd4a0ee9d17796f7e1bc"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.3+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "39bca05343661c347aae0bca57a5994a0bf4f08d"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "4.2.0+0"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e5b100780d4d30d63b4618d7930d48af409c1772"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "23.1.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f88f3ccef05a6a72a0cf0ed417c8fd68530f4ab2"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.1"

[[deps.Latexify]]
deps = ["Format", "Ghostscript_jll", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Requires"]
git-tree-sha1 = "df7566479bd64f20bd16b09960145e70160ffb3b"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.12"

    [deps.Latexify.extensions]
    DataFramesExt = "DataFrames"
    SparseArraysExt = "SparseArrays"
    SymEngineExt = "SymEngine"
    TectonicExt = "tectonic_jll"

    [deps.Latexify.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    SymEngine = "123dc426-2d89-5057-bbad-38513e3affd8"
    tectonic_jll = "d7dd28d6-a5e6-559c-9131-7eb760cdacc5"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.4.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.6.4+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c8da7e6a91781c41a863611c7e966098d783c57a"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.4.7+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "d36c21b9e7c172a44a10484125024495e2625ac0"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.7.1+1"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "be484f5c92fad0bd8acfef35fe017900b0b73809"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.18.0+0"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "cc3ad4faf30015a3e8094c9b5b7f19e85bdf2386"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.42.0+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "aebd334d06cee9f24cea70bd19a39749daf73881"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.3+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d620582b1f0cbe2c72dd1d5bd195a9ce73370ab1"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.42.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "bba2d9aa057d8f126415de240573e86a8f39d2a1"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "1.0.1"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

[[deps.Measures]]
git-tree-sha1 = "b513cedd20d9c914783d8ad83d08120702bf2c77"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.3"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.1.10"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "dbd2e8cd2c1c27f0b584f6661b4309609c5a685e"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.1.4"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b6aa4566bb7ae78498a5e68943863fa8b5231b59"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.6+0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.23+4"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+2"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7787087cbc5ec110986e94d9aa1f17639a79c5de"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.8+0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e2bb57a313a74b8104064b7efd01406c0a50d2ff"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.6.1+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "94ba93778373a53bfd5a0caaf7d809c445292ff4"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.2"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+1"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1912a9f1b9ca55005b03ba075f8e19993583e237"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.58.2+0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools"]
git-tree-sha1 = "663e8b48b789916221e0765393b289ca6c88f24e"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "3.0.0"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "e4a6721aa89e62e5d4217c0b21bd714263779dda"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.46.4+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Statistics"]
git-tree-sha1 = "41031ef3a1be6f5bbbf3e8073f210556daeae5ca"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "3.3.0"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "StableRNGs", "Statistics"]
git-tree-sha1 = "26ca162858917496748aad52bb5d3be4d26a228a"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.4"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "JLFzf", "JSON", "LaTeXStrings", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "PrecompileTools", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "RelocatableFolders", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "TOML", "UUIDs", "UnicodeFun", "Unzip"]
git-tree-sha1 = "83bd514e8ff16b5858ac54c53fa0bcf6002a3b00"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.41.7"

    [deps.Plots.extensions]
    FileIOExt = "FileIO"
    GeometryBasicsExt = "GeometryBasics"
    IJuliaExt = "IJulia"
    ImageInTerminalExt = "ImageInTerminal"
    UnitfulExt = "Unitful"

    [deps.Plots.weakdeps]
    FileIO = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
    GeometryBasics = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"
    ImageInTerminal = "d8c32880-2388-543b-8c61-d9f865259254"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "e189d0623e7ce9c37389bac17e80aac3b0302e75"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.83"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "5005266de4bfe50e53ff44a5cb5c540b6e47a254"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.6.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.PtrArrays]]
git-tree-sha1 = "4fbbafbc6251b883f4d2705356f3641f3652a7fe"
uuid = "43287f4e-b6f4-7ad1-bb20-aadabca52c3d"
version = "1.4.0"

[[deps.Qt6Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Vulkan_Loader_jll", "Xorg_libSM_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_cursor_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "libinput_jll", "xkbcommon_jll"]
git-tree-sha1 = "144895f6166994730ee7ff8113b981fc360638f1"
uuid = "c0090381-4147-56d7-9ebc-da0b1113ec56"
version = "6.10.2+2"

[[deps.Qt6Declarative_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll", "Qt6ShaderTools_jll", "Qt6Svg_jll"]
git-tree-sha1 = "159d253ab126d5b29230cf53521899bea4ef4648"
uuid = "629bc702-f1f5-5709-abd5-49b8460ea067"
version = "6.10.2+2"

[[deps.Qt6ShaderTools_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll"]
git-tree-sha1 = "4d85eedf69d875982c46643f6b4f66919d7e157b"
uuid = "ce943373-25bb-56aa-8eca-768745ed7b5a"
version = "6.10.2+1"

[[deps.Qt6Svg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll"]
git-tree-sha1 = "81587ff5ff25a4e1115ce191e36285ede0334c9d"
uuid = "6de9746b-f93d-5813-b365-ba18ad4a9cf3"
version = "6.10.2+0"

[[deps.Qt6Wayland_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll", "Qt6Declarative_jll"]
git-tree-sha1 = "672c938b4b4e3e0169a07a5f227029d4905456f2"
uuid = "e99dba38-086e-5de3-a5b1-6e4c66e897c3"
version = "6.10.2+1"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "PrecompileTools", "RecipesBase"]
git-tree-sha1 = "45cf9fd0ca5839d06ef333c8201714e888486342"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.6.12"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "ffdaf70d81cf6ff22c2b6e733c900c3321cab864"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.1"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "9b81b8393e50b7d4e6d0a9f14e192294d3b7c109"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.3.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Showoff]]
deps = ["Dates"]
git-tree-sha1 = "8238217340ad0aaabe11afe39c1098b5bc9f4c8e"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.1.1"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "13cd91cc9be159e3f4d95b857fa2aa383b53772a"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.3"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

[[deps.StableRNGs]]
deps = ["Random"]
git-tree-sha1 = "4f96c596b8c8258cc7d3b19797854d368f243ddc"
uuid = "860ef19b-820b-49d6-a774-d7a799459cd3"
version = "1.0.4"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.10.0"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "178ed29fd5b2a2cfc3bd31c13375ae925623ff36"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.8.0"

[[deps.StatsBase]]
deps = ["AliasTables", "DataAPI", "DataStructures", "IrrationalConstants", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "adb9da019510162e67a4493fc235c23203d8b09e"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.13"

[[deps.StructUtils]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "2d0fc55c61321ba245c47be599570d11bac50303"
uuid = "ec057cc2-7a8d-4b58-b3b3-92acb9f63b42"
version = "2.8.5"

    [deps.StructUtils.extensions]
    StructUtilsMeasurementsExt = ["Measurements"]
    StructUtilsStaticArraysCoreExt = ["StaticArraysCore"]
    StructUtilsTablesExt = ["Tables"]

    [deps.StructUtils.weakdeps]
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.2.1+1"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.Tricks]]
git-tree-sha1 = "311349fd1c93a31f783f977a71e8b062a57d4101"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.13"

[[deps.URIs]]
git-tree-sha1 = "908fec9df6c5de98548ead82a468c95ccf6cd263"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.7.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unzip]]
git-tree-sha1 = "ca0969166a028236229f63514992fc073799bb78"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.2.0"

[[deps.Vulkan_Loader_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Wayland_jll", "Xorg_libX11_jll", "Xorg_libXrandr_jll", "xkbcommon_jll"]
git-tree-sha1 = "2f0486047a07670caad3a81a075d2e518acc5c59"
uuid = "a44049a8-05dd-5a78-86c9-5fde0876e88c"
version = "1.3.243+0"

[[deps.Wayland_jll]]
deps = ["Artifacts", "EpollShim_jll", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "96478df35bbc2f3e1e791bc7a3d0eeee559e60e9"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.24.0+0"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e52eca002a11c30a858185efdfb15311e1c7a6bf"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.8.4+0"

[[deps.Xorg_libICE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a3ea76ee3f4facd7a64684f9af25310825ee3668"
uuid = "f67eecfb-183a-506d-b269-f58e52b52d7c"
version = "1.1.2+0"

[[deps.Xorg_libSM_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libICE_jll"]
git-tree-sha1 = "9c7ad99c629a44f81e7799eb05ec2746abb5d588"
uuid = "c834827a-8449-5923-a945-d239c165b7dd"
version = "1.2.6+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "808090ede1d41644447dd5cbafced4731c56bd2f"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.13+0"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aa1261ebbac3ccc8d16558ae6799524c450ed16b"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.13+0"

[[deps.Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "6c74ca84bbabc18c4547014765d194ff0b4dc9da"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.4+0"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "52858d64353db33a56e13c341d7bf44cd0d7b309"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.6+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "1a4a26870bf1e5d26cd585e38038d399d7e65706"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.8+0"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "75e00946e43621e09d431d9b95818ee751e6b2ef"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "6.0.2+0"

[[deps.Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "dcb316b3ce0941f195537dda56bea4517fcd3ff5"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.8.4+0"

[[deps.Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXext_jll"]
git-tree-sha1 = "0ba01bc7396896a4ace8aab67db31403c71628f4"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.7+0"

[[deps.Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "6c174ef70c96c76f4c3f4d3cfbe09d018bcd1b53"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.6+0"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "7ed9347888fac59a618302ee38216dd0379c480d"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.12+0"

[[deps.Xorg_libpciaccess_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "58972370b81423fc546c56a60ed1a009450177c3"
uuid = "a65dc6b1-eb27-53a1-bb3e-dea574b5389e"
version = "0.19.0+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXau_jll", "Xorg_libXdmcp_jll"]
git-tree-sha1 = "bfcaf7ec088eaba362093393fe11aa141fa15422"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.17.1+0"

[[deps.Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "ed756a03e95fff88d8f738ebc2849431bdd4fd1a"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.2.0+0"

[[deps.Xorg_xcb_util_cursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_jll", "Xorg_xcb_util_renderutil_jll"]
git-tree-sha1 = "9750dc53819eba4e9a20be42349a6d3b86c7cdf8"
uuid = "e920d4aa-a673-5f3a-b3d7-f755a4d47c43"
version = "0.1.6+0"

[[deps.Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "f4fc02e384b74418679983a97385644b67e1263b"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.1+0"

[[deps.Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll"]
git-tree-sha1 = "68da27247e7d8d8dafd1fcf0c3654ad6506f5f97"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.1+0"

[[deps.Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "44ec54b0e2acd408b0fb361e1e9244c60c9c3dd4"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.1+0"

[[deps.Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "5b0263b6d080716a02544c55fdff2c8d7f9a16a0"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.10+0"

[[deps.Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "f233c83cad1fa0e70b7771e0e21b061a116f2763"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.2+0"

[[deps.Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "801a858fc9fb90c11ffddee1801bb06a738bda9b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.7+0"

[[deps.Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "2e59214e017a55cb87474a00fa76035c82ac0e17"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.47.0+2"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a63799ff68005991f9d9491b6e95bd3478d783cb"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.6.0+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "446b23e73536f84e8037f5dce465e92275f6a308"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.7+1"

[[deps.eudev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c3b0e6196d50eab0c5ed34021aaa0bb463489510"
uuid = "35ca27e7-8b34-5b7f-bca9-bdc33f59eb06"
version = "3.2.14+0"

[[deps.fzf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b6a34e0e0960190ac2a4363a1bd003504772d631"
uuid = "214eeab7-80f7-51ab-84ad-2988db7cef09"
version = "0.61.1+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "ef17c47d22224aaecc76e597ab21a072e025cf7b"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.14.1+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "cb007192783c56d8249db4cf0e3495001edfe414"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.17.5+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.libdecor_jll]]
deps = ["Artifacts", "Dbus_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pango_jll", "Wayland_jll", "xkbcommon_jll"]
git-tree-sha1 = "9bf7903af251d2050b467f76bdbe57ce541f7f4f"
uuid = "1183f4f0-6f2a-5f1a-908b-139f9cdfea6f"
version = "0.2.2+0"

[[deps.libdrm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libpciaccess_jll"]
git-tree-sha1 = "28e57478e8a160d346a19c28b3fffb9273bcc9c2"
uuid = "8e53e030-5e6c-5a89-a30b-be5b7263a166"
version = "2.4.134+0"

[[deps.libevdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "56d643b57b188d30cccc25e331d416d3d358e557"
uuid = "2db6ffa8-e38f-5e21-84af-90c45d0032cc"
version = "1.13.4+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "646634dd19587a56ee2f1199563ec056c5f228df"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.4+0"

[[deps.libinput_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "eudev_jll", "libevdev_jll", "mtdev_jll"]
git-tree-sha1 = "91d05d7f4a9f67205bd6cf395e488009fe85b499"
uuid = "36db933b-70db-51c0-b978-0f229ee0e533"
version = "1.28.1+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "e51150d5ab85cee6fc36726850f0e627ad2e4aba"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.58+0"

[[deps.libva_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll", "Xorg_libXfixes_jll", "libdrm_jll"]
git-tree-sha1 = "7dbf96baae3310fe2fa0df0ccbb3c6288d5816c9"
uuid = "9a156e7d-b971-5f62-b2c9-67348b8fb97c"
version = "2.23.0+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll"]
git-tree-sha1 = "11e1772e7f3cc987e9d3de991dd4f6b2602663a5"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.8+0"

[[deps.mtdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b4d631fd51f2e9cdd93724ae25b2efc198b059b1"
uuid = "009596ad-96f7-51b1-9f1b-5ce2d5e8a71e"
version = "1.1.7+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "14cc7083fc6dff3cc44f2bc435ee96d06ed79aa7"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "10164.0.1+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e7b67590c14d487e734dcb925924c5dc43ec85f3"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "4.1.0+0"

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "a1fc6507a40bf504527d0d4067d718f8e179b2b8"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "1.13.0+0"
"""

# ╔═╡ Cell order:
# ╠═1f1dd7f7-55cb-4cb0-80b4-58b0ed069101
# ╟─6fdb3e8d-82b6-40dc-b857-a73a0d1d9102
# ╟─ccbab3d6-3453-4ae1-861e-3e96dbbcb103
# ╟─f371d73f-1996-42de-a30a-f5a4dbdb7104
# ╠═2a56e72d-dd14-47b5-ad2b-a3a66d95a105
# ╠═6b34418c-2e02-4cdd-b7e4-0b1bce6b6106
# ╠═08aac5b4-cc02-4253-94be-f9940f2a6107
# ╟─3753e01c-2f44-4cee-8cb1-492087922108
# ╟─7c832c27-bdc4-40f5-86ab-ec5ab8dbf109
# ╠═bf8c7454-1fe0-4d1d-9125-e3797142b110
# ╠═e63fbbd3-474c-4424-a9f5-d8ed7091b111
# ╠═541e55d8-eb74-4349-a987-1a0af2dc2112
# ╠═e9a067fc-6a4d-47cb-90be-69b76d6b6113
# ╠═66495e2f-d876-4b23-8225-495505791114
# ╠═39258468-1fce-4502-b438-78cd841a0115
# ╟─a94a4d7e-7bd0-4a74-aa6e-4d33f9f60116
# ╠═5c5e6a34-a219-4dd4-9881-c71e0d72a117
# ╠═c31cc486-8e9f-48f6-a976-67866adb7118
# ╟─1a9a345b-6da9-40f0-8798-39efe1228119
# ╠═691a4625-1d79-4742-b984-b0037af2c120
# ╟─fb2400cb-488a-4e67-8fc9-ab1473993121
# ╠═53ba5c73-2bd4-49d5-a48a-493739025122
# ╟─c9dd0e1c-c2d4-49ed-a4a4-f410f49cc123
# ╠═2cf520f7-eed5-418a-b8b3-d160c33c3124
# ╠═42c3c347-7ca4-4463-9476-1411c50cf125
# ╟─cb24e175-3213-49f4-b12f-1e529bf24126
# ╠═de1af706-784e-4f08-bde4-f28e87c76127
# ╟─dc922fd7-12d4-4e8a-b568-30b4f7331128
# ╠═973ef68d-c492-469e-9449-1c440c43c129
# ╟─a7b8af27-98fb-4791-af70-255e363f5130
# ╠═662f2b0d-bffb-4686-9655-29cac7869131
# ╟─bbd6158b-6901-4d8f-acd9-b6372adb1132
# ╠═3588ed2a-e4c5-42c0-8be2-9887fa63a133
# ╟─818e7d38-7c64-441d-98c1-6f50885b4134
# ╠═1e995594-7292-440f-909e-29c382570135
# ╟─27659a07-df77-4421-bfe9-195bedeb4136
# ╠═5bd48995-c3bb-413f-9726-0544f51f5137
# ╟─85fb3d9b-7af9-48fb-a868-38f64231d138
# ╠═48fc7c63-7a46-4a92-9659-6b619ca73139
# ╟─c83d3abe-abde-45d2-88db-cef2cd8f6140
# ╠═65a81845-737b-4999-8870-63498fa25141
# ╟─94eb02b7-34a3-4a18-80b8-a5b28b40d142
# ╠═c16cb4c3-b337-4ee1-94c0-f7fc5412a143
# ╟─44895b55-940c-4347-aa3c-c9fd315ea144
# ╠═87c63ca7-6e5e-4820-ae61-4f187246f145
# ╟─a2810628-b9c8-48df-acf6-8b06b3724146
# ╟─69703e2d-a4c0-4385-b649-71fc6d911147
# ╟─a7af8eae-a480-445d-9884-41fd6132b148
# ╠═9522224b-87bf-4878-a315-809d2f9b1149
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
