using YaoBase, BitBasis
using YaoArrayRegister: swaprows!

export Swap, swap

struct Swap{N} <: PrimitiveBlock{N}
    locs::Tuple{Int, Int}

    function Swap{N}(locs::Tuple{Int, Int}) where N
        @assert_locs_safe N locs
        return new{N}(locs)
    end
end

Swap{N}(loc1::Int, loc2::Int) where N = Swap{N}((loc1, loc2))

"""
    swap(n, loc1, loc2)

Return a `n`-qubit [`Swap`](@ref) gate which swap `loc1` and `loc2`.
"""
swap(n::Int, loc1::Int, loc2::Int) = Swap{n}((loc1, loc2))

"""
    swap(loc1, loc2) -> f(n)

Return a lambda that takes the total number of active qubits as input. See also
[`swap`](@ref), [`Swap`](@ref).
"""
swap(loc1::Int, loc2::Int) = @λ(n -> swap(n, loc1, loc2))

function mat(::Type{T}, g::Swap{N}) where {T, N}
    mask = bmask(g.locs[1], g.locs[2])
    orders = map(b->swapbits(b, mask) + 1, basis(N))
    return PermMatrix(orders, ones(T, 1<<N))
end

apply!(r::ArrayReg, g::Swap) = instruct!(state(r), Val(:SWAP), g.locs)
occupied_locs(g::Swap) = g.locs

Base.:(==)(lhs::Swap, rhs::Swap) = lhs.locs == rhs.locs

YaoBase.isunitary(rb::Swap) = true
YaoBase.ishermitian(rb::Swap) = true
YaoBase.isreflexive(rb::Swap) = true
