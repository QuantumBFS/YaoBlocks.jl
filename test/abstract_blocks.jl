using Test, YaoBlocks

@testset "Yao/#186" begin
    @test getiparams(phase(0.1)) == 0.1
    @test getiparams(2 * phase(0.1)) == ()
end

@testset "block to matrix conversion" begin
    for each in [X, Y, Z, H]
        Matrix{ComplexF64}(each) == Matrix{ComplexF64}(mat(each))
    end
end
