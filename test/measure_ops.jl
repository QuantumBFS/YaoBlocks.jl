using YaoBlocks, YaoArrayRegister, BitBasis
using YaoBlocks: eigenbasis
using Random, Test

@testset "eigen basis" begin
    for op in [X, Y, H, Z]
        E, V = eigenbasis(op)
        for i in basis(BitStr64{nqubits(op)})
            @test expect(op, ArrayReg(i) |> V') ≈ E[Int(i)+1]
        end
    end
    @test eigenbasis(kron(X,X)) == ([1:1=>[1,-1.0], 2:2=>[1,-1.0]], kron(H, H))
    @test eigenbasis(repeat(10, X, (4,2))) == ([1, -1.0], repeat(10, H, (4,2)))
end

@testset "better operator measure" begin
    Random.seed!(17)
    nbit=3
    for op in [put(nbit, 2=>X), kron(X,X,Y),
        repeat(nbit, X, 2:3), +(put(nbit, 2=>X), put(nbit, 1=>Rx(π))),
        2.8 * put(nbit, 1=>X), chain(nbit, put(nbit, 3=>X), put(nbit, 1=>Z)),
        cache(put(nbit, 2=>X)), Daggered(put(nbit, 2=>Rx(0.8)))
        ]
        reg = rand_state(nbit)
        reg2 = copy(reg)
        @show op
        if op is KronBlock
            @test_broken isapprox(sum(measure(op, reg2; nshots=10000))/10000, expect(op, reg), rtol=0.1)
        else
            @test isapprox(sum(measure(op, reg2; nshots=10000))/10000, expect(op, reg), rtol=0.1)
        end
        @test reg ≈ reg2
    end
end
