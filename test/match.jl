using Test
using YaoBlocks

@testset "generic match" begin
    @testset "primitive patterns" begin
        @test isempty(match(X, Y))
        @test isempty(match(X, chain(X, Y)))

        @testset "block var" begin
            x = var(1)
            @test match(x, chain(X, Y)) == BlockMatch(x => chain(X, Y))
            @test match(x, X) == BlockMatch(x => X)
            @test match(x, kron(X, Y)) == BlockMatch()

            y = var(2)
            @test match(y, kron(X, Y)) == BlockMatch(y => kron(X, Y))
        end
    end

    p = kron(var(1, :x), var(1, :x), var(1, :x))
    @test match(p, kron(X, X, X)) == BlockMatch(var(1, :x) => X)
end

@testset "associative" begin
    p = chain(1, var, chain(var, var))
    c = chain(X, Y, chain(Z, X))

    m = match(p, c)
    @test length(m) == 1
    m = first(m)
    @test m[p[1]] == chain(X, Y)
    @test m[p[2][1]] == Z
    @test m[p[2][2]] == X

    p = chain(2, var, chain(var, var))
    c = chain(2, put(1=>X), kron(X, Y))
    @test isempty(match(p, c))
end

@testset "communitive" begin
    p = chain(3, put(2=>var(1, :x)), put(1=>var(1, :y)))
    c = chain(3, put(1=>X), put(2=>Y))
    @test match(p, c) == BlockMatch(Dict(var(1, :y) => X, var(1, :x) => Y))
end
