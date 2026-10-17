using Test

include(joinpath(@__DIR__, "..", "newton_multiple_roots.jl"))

@testset "Newton ante raíces múltiples" begin
    @test precision(ROOT_REFERENCE) >= 256
    @test ROOT_REFERENCE^2 ≈ BigFloat(2)

    @testset "Fórmulas y tipos" begin
        for T in FLOAT_TYPES, m in 1:3
            x = T(1.8)
            @test f_m(x, m) isa T
            @test df_m(x, m) isa T
            @test newton_candidate(x, m) isa T
            @test newton_candidate(x, m; variant=:modified) isa T
        end
        @test all(all(t == T for t in audit_types(T)) for T in FLOAT_TYPES)
    end

    @testset "Convergencia y Newton modificado" begin
        @test abs(representative_ratio(experiment_1[2]) - 0.5) < 0.01
        @test abs(representative_ratio(experiment_1[3]) - 2 / 3) < 0.01
        for m in (2, 3)
            @test experiment_2[(m, :modified)].iterations < experiment_2[(m, :standard)].iterations
            @test experiment_2[(m, :modified)].error_final <= BigFloat("1e-14")
        end
    end

    @testset "Parada y precisión finita" begin
        @test all(stop_reason_checks[key] == key for key in keys(stop_reason_checks))
        @test all(precision_runs[T].reason == :stagnation for T in FLOAT_TYPES)
        @test all(isfinite(precision_runs[T].x_final) for T in FLOAT_TYPES)
        @test all(row -> isfinite(row.x) && isfinite(row.fx), vcat([precision_runs[T].rows for T in FLOAT_TYPES]...))
        @test zero_search[Float16].found
        @test zero_search[Float16].square == Float16(2)
        @test zero_search[Float16].residual == Float16(0)
        @test zero_search[Float16].error > 0
        @test !zero_search[Float32].found
        @test !zero_search[Float64].found
    end

    @testset "Residuo, bisección y salidas" begin
        @test stop_experiments[(3, :residual)].error_final > stop_experiments[(3, :true_error)].error_final
        @test bisection_m1.reason == :converged
        @test bisection_m2.reason == :no_sign_change
        @test true_error(bisection_m1.x) < BigFloat("1e-11")
        @test plot_a isa Plots.Plot
        @test plot_b isa Plots.Plot
        @test plot_c isa Plots.Plot
        @test plot_d isa Plots.Plot
    end
end
