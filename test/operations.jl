using YaoArrayReg
using YaoBlocks
using Test
using StatsBase: mean

@testset "insert_qubit!" begin
    reg = rand_state(5; nbatch=10)
    insert_qubit!(reg, 3, nbit=2)
    @test reg |> nqubits == 7
    @test expect(put(7, 3=>Z), reg) .|> tr |> mean ≈ 1
    @test expect(put(7, 4=>Z), reg) .|> tr |> mean ≈ 1
end

@testset "expect" begin
    reg = rand_state(3,10)
    e1 = expect(put(2, 2=>X), reg |> copy |> focus!(1,2) |> ρ)
    e2 = expect(put(2, 2=>X), reg |> copy |> focus!(1,2))
    e3 = expect(put(3, 2=>X), reg |> ρ)
    e4 = expect(put(3, 2=>X), reg)
    @test e1 ≈ e2
    @test e1 ≈ e3
    @test e1 ≈ e4
end
