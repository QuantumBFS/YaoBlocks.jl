using Test, YaoBlocks, BitBasis
using YaoBlocks: check_dumpload

@testset "check_dumpload" begin
    @test check_dumpload(X)
    @test check_dumpload(X + Y)
    @test check_dumpload(kron(X, Y))
    @test check_dumpload(shift(0.5))
    @test check_dumpload(phase(0.5))
    @test check_dumpload(time_evolve(X, 0.5))
    @test check_dumpload(put(5, 2=>X))
    @test check_dumpload(chain(put(5, 2=>X)))
    @test check_dumpload(put(5, 2=>rot(X, 0.5)))
    @test check_dumpload(control(5, 1, 2=>rot(X, 0.5)))
    @test check_dumpload(control(5, (1, -4), 2=>rot(X, 0.5)))
    @test check_dumpload(concentrate(5,rot(SWAP, 0.5), (2,5)))
    @test check_dumpload(repeat(5, X, (2,5)))
    @test check_dumpload(Measure(5))
    @test check_dumpload(Daggered(X))
    @test check_dumpload(2*X)
end

@testset "yao macro" begin
    c = yao"""
    begin nqubits = 5
        3 => rot(X, 0.3)
        2 => X
    end
    """
    y = chain(5, put(3=>rot(X, 0.3)), put(2=>X))
    @test c == y
    @test check_dumpload(y)
    yaotofile("_test.yao", y)
    yy = @eval $(yaofromfile("_test.yao"))
    @test y == yy
end
