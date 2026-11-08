using Printf
using Test

function shamanskii_control(f, df, x0; m=1, atol=1e-14, max_outer=50)
    m >= 1 || throw(ArgumentError("m debe ser al menos 1"))
    x = float(x0)
    fx = f(x)
    df_evals = 0
    chord_steps = 0

    for outer in 0:max_outer
        abs(fx) <= atol && return (
            root=x, converged=true, outer_iterations=outer,
            chord_steps=chord_steps, df_evals=df_evals,
        )
        outer == max_outer && break
        dfx = df(x)
        iszero(dfx) && throw(DomainError(dfx))
        df_evals += 1
        z = x
        for j in 1:m
            z -= (j == 1 ? fx : f(z)) / dfx
            chord_steps += 1
        end
        x = z
        fx = f(x)
    end
    (root=x, converged=false, outer_iterations=max_outer,
     chord_steps=chord_steps, df_evals=df_evals)
end

function posicion_control(t, omega)
    T = promote_type(typeof(float(t)), typeof(float(omega)))
    tt, w = T(t), T(omega)
    g = T(49) / T(5)
    iszero(w) && return zero(T)
    g / (T(2) * w^2) * (sinh(w * tt) - sin(w * tt))
end

function biseccion_control(f, a, b; atol, maxiter=1000)
    fa, fb = f(a), f(b)
    signbit(fa) != signbit(fb) || throw(ArgumentError("sin cambio de signo"))
    for _ in 1:maxiter
        c = a + (b - a) / 2
        fc = f(c)
        if signbit(fa) != signbit(fc)
            b, fb = c, fc
        else
            a, fa = c, fc
        end
        b - a <= 2atol && return (a + b) / 2, a, b
    end
    error("no convergió")
end

@testset "Shamanskii y ecuación del plano" begin
    @testset "Método de Shamanskii" begin
        f(x) = cos(x) - x
        df(x) = -sin(x) - 1
        referencia = 0.7390851332151607

        resultados = [shamanskii_control(f, df, 0.5; m=m) for m in 1:12]
        @test all(r.converged for r in resultados)
        @test all(isapprox(r.root, referencia; atol=2e-14, rtol=0) for r in resultados)
        @test resultados[1].outer_iterations == 4
        @test resultados[1].chord_steps == resultados[1].outer_iterations
        @test resultados[1].df_evals == resultados[1].outer_iterations
        @test resultados[3].df_evals < resultados[1].df_evals
        @test_throws ArgumentError shamanskii_control(f, df, 0.5; m=0)
    end

    @testset "Tasa omega" begin
        setprecision(BigFloat, 256) do
            F(w) = posicion_control(one(w), w) - one(w)
            omega, inferior, superior = biseccion_control(
                F, BigFloat("0.1"), BigFloat("2"); atol=BigFloat("1e-60"))

            @test inferior <= omega <= superior
            @test superior - inferior < big"2e-60"
            @test abs(F(omega)) < big"1e-59"
            @test @sprintf("%.12f", Float64(omega)) == "0.612142570703"
            @test inferior > BigFloat("0.6121425707025")
            @test superior < BigFloat("0.6121425707035")

            puntos = BigFloat.(range(0.1, 1.2; length=100))
            valores = posicion_control.(one(BigFloat), puntos)
            @test all(diff(valores) .> 0)
        end
    end
end
