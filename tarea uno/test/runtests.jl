using Test

# El notebook es un programa Julia válido; incluirlo ejecuta todas sus celdas.
include(joinpath(@__DIR__, "..", "floating_point_finance.jl"))

@testset "Aritmética y tipos" begin
    @test eltype(moving_average(Float16[1, 2, 3], 2)) === Float16
    @test eltype(moving_average(Float32[1, 2, 3], 2)) === Float32
    @test eltype(moving_average(Float64[1, 2, 3], 2)) === Float64
    @test moving_average(Float32[1, 2, 3], 2)[2:3] == Float32[1.5, 2.5]
    @test_throws ArgumentError moving_average(Float32[1, 2], 0)
    @test_throws ArgumentError moving_average(Float32[1, 2], 3)
end

@testset "Caso causal y representabilidad" begin
    c = find_representation_collision(100.0)
    @test c.a != c.b
    @test Float32(c.a) == Float32(c.b)
    d = find_controlled_disagreement(100, 5, 25)
    @test signal(d.s64, d.l64) != signal(d.s32, d.l32)
    @test sign(d.s64 - d.l64) == sign(d.sb - d.lb)
end

@testset "Reproducibilidad y ausencia de no-finitos" begin
    p1_test = synthetic_prices(77, 100, 100.0)
    p2_test = synthetic_prices(77, 100, 100.0)
    @test p1_test == p2_test
    c = compare_precisions(p1_test, 5, 25)
    @test all(isfinite, c.d64)
    @test all(isfinite, c.d32)
    m1 = monte_carlo(5, 100, 100.0, 5, 25; seed=88)
    m2 = monte_carlo(5, 100, 100.0, 5, 25; seed=88)
    @test m1.d64 == m2.d64
    @test m1.disagreements == m2.disagreements
    @test m1.total == 5 * (100 - 25 + 1)
end

@testset "Artefactos calculados" begin
    @test length(threshold_summary) == 7
    @test sum(r.n for r in threshold_summary) == mc.total
    @test length(scale_results) == 5
    @test length(real_data.values) >= 20
    @test all(p -> p isa Plots.Plot, (p1, p2, p3, p4, p5, p6))
end

@testset "Extremos de los controles" begin
    for b in (1.0, 10.0, 100.0, 1_000.0, 10_000.0)
        p = synthetic_prices(9, 80, b)
        c = compare_precisions(p, 11, 40)
        @test all(isfinite, c.d64)
        @test all(isfinite, c.d32)
    end
    for (ws, wl) in ((3, 15), (5, 25), (11, 40))
        d = find_controlled_disagreement(100, ws, wl)
        @test signal(d.s64, d.l64) != signal(d.s32, d.l32)
    end
    high16 = compare_type_to_64(Float16, synthetic_prices(9, 80, 10_000.0), 11, 40)
    @test high16.nonfinite > 0
    @test high16.total + high16.nonfinite == 80 - 40 + 1
end
