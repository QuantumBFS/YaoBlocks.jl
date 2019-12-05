using Test, YaoBlocks, BitBasis
using YaoBlocks: check_dumpload

@testset "check_dumpload" begin
    @test check_dumpload(X)
    @test check_dumpload(X + Y)
    @test check_dumpload(kron(X, Y))
    @test check_dumpload(kron(5, 2=>X, 4=>Y))
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
    @test check_dumpload(Measure(5, operator=put(5,2=>X)))
    @test check_dumpload(Measure(5, locs=(3,1), collapseto=bit"01"))
    @test check_dumpload(Measure(5, locs=(3,2), operator=put(2,2=>X), collapseto=bit"11"))
    @test check_dumpload(Daggered(X))
    @test check_dumpload(2*X)
    @test check_dumpload(cache(2*X))
    @test_throws ErrorException check_dumpload(kron(5, 2=>SWAP))
end

@testset "yao macro" begin
    c = yao"""
    let nqubits = 5
        begin
            3 => rot(X, 0.3)
            2 => X
        end
    end
    """
    y = chain(5, put(3=>rot(X, 0.3)), put(2=>X))
    @test c == y
    @test check_dumpload(y)
    yaotofile("_test.yao", y)
    yy = @eval $(yaofromfile("_test.yao"))
    @test y == yy

    g = eval(yaofromfile(joinpath(dirname(@__FILE__), "yaoscript.yao")))
    s = string(yaotoscript(g))
    g1 = eval(yaofromstring(s))
    @test g == g1
end
