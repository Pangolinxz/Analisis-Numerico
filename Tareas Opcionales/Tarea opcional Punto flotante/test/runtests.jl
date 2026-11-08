using Test

@testset "Tarea opcional: punto flotante" begin
    @testset "Problema 1: memoria" begin
        n = big(100_000)
        @test n * sizeof(Float64) == 800_000
        @test n^2 * sizeof(Float64) == 80_000_000_000
    end

    function orbita_control(x0, pasos)
        xs = [x0]
        for _ in 1:pasos
            x = xs[end]
            push!(xs, 2x <= one(x) ? 2x : 2x - one(x))
        end
        xs
    end

    @testset "Problema 2: sucesión por tramos" begin
        exacta = orbita_control(big(1) // big(10), 50)
        flotante = orbita_control(0.1, 50)
        rama_inclusiva = orbita_control(big(1) // big(8), 50)

        @test exacta[51] == big(2) // big(5)
        @test flotante[51] == 0.40625
        @test rama_inclusiva[3] == big(1) // big(2)
        @test all(==(1), rama_inclusiva[4:end])
    end

    function softmax_control(x)
        a = maximum(x)
        y = exp.(x .- a)
        y ./ sum(y)
    end

    @testset "Problema 3: softmax estable" begin
        p = softmax_control([1000.0, 1001.0, 1002.0])
        q = softmax_control([0.0, 1.0, 2.0])
        @test all(isfinite, p)
        @test isapprox(sum(p), 1.0; atol=10eps(Float64), rtol=0)
        @test isapprox(p, q; atol=10eps(Float64), rtol=0)
    end

    directa_cancelacion(x) = sqrt(1 + x^2) - 1
    racionalizada(x) = x^2 / (sqrt(1 + x^2) + 1)

    @testset "Problema 4: cancelación" begin
        xs = [ldexp(1.0, -3k) for k in 1:30]
        directos = directa_cancelacion.(xs)
        estables = racionalizada.(xs)
        @test directos[8] > 0
        @test findfirst(iszero, directos) == 9
        @test all(iszero, directos[9:end])
        @test all(>(0), estables)
    end

    function viete_control(n; estable=false)
        w = Vector{Float64}(undef, n)
        w[1] = 2.0
        for k in 1:n-1
            a = ldexp(w[k], -k)^2
            interior = sqrt(1 - a)
            w[k + 1] = estable ?
                w[k] * sqrt(2 / (1 + interior)) :
                ldexp(sqrt(2 * (1 - interior)), k)
        end
        w
    end

    @testset "Problema 5: recurrencia de Viète" begin
        directa = viete_control(40)
        estable = viete_control(40; estable=true)
        @test findfirst(iszero, directa) == 30
        @test isapprox(estable[end], pi; atol=20eps(Float64), rtol=0)

        setprecision(BigFloat, 256) do
            for k in 1:30
                cerrada = big(2)^k * sin(big(pi) / big(2)^k)
                @test cerrada > 0
                @test cerrada < big(pi)
            end
        end
    end

    function stewart_control(n)
        x = Vector{Float64}(undef, n)
        x[1], x[2] = 1 / 3, 1 / 12
        for k in 2:n-1
            x[k + 1] = 2.25x[k] - 0.5x[k - 1]
        end
        x
    end

    @testset "Problema 6: recurrencia de Stewart" begin
        exacta = Rational{BigInt}[big(1) // big(3), big(1) // big(12)]
        for k in 2:19
            push!(exacta, (big(9) // big(4)) * exacta[k] - (big(1) // big(2)) * exacta[k - 1])
        end
        @test all(exacta[k] == big(1) // (big(3) * big(4)^(k - 1)) for k in eachindex(exacta))

        calculada = stewart_control(80)
        q1, q2 = Rational{BigInt}(calculada[1]), Rational{BigInt}(calculada[2])
        e1 = q1 - big(1) // big(3)
        e2 = q2 - big(1) // big(12)
        @test 4 * e2 - e1 == 0

        operacion_exacta_x3 = (big(9) // 4) * q2 - (big(1) // 2) * q1
        @test Rational{BigInt}(calculada[3]) - operacion_exacta_x3 != 0
        @test abs(calculada[80]) > 10^6
    end

    @testset "Problema 7: operación medida" begin
        v = collect(range(0.0, 1.0; length=100_000))
        resultado = sum(abs2, v)
        @test isfinite(resultado)
        @test resultado > 0
    end
end
