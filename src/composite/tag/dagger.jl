export Daggered

"""
    Daggered{N, T, BT} <: TagBlock{N, T}

Wrapper block allowing to execute the inverse of a block of quantum circuit.
"""
struct Daggered{N, T, BT <: AbstractBlock} <: TagBlock{N, T}
    block::BT
end

Daggered(x::AbstractBlock) = Daggered(MatrixTrait(x), x)
Daggered(::HasMatrix{N, T}, x::AbstractBlock) where {N, T} =
    Daggered{N, T, typeof(x)}(x)
Daggered(::MatrixUnkown, x) = error("expect a block with matrix representation, got $x")

PreserveStyle(::Daggered) = PreserveAll()
mat(blk::Daggered) = adjoint(mat(blk.block))

Base.parent(x::Daggered) = x.block
Base.adjoint(x::AbstractBlock) = ishermitian(x) ? x : Daggered(x)
Base.adjoint(x::Daggered) = x.block
Base.similar(c::Daggered, level::Int) = Daggered(similar(c.block))
Base.copy(c::Daggered, level::Int) = Daggered(copy(c.block))
