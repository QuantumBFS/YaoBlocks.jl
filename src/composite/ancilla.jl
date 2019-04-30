using YaoBlocks,  YaoArrayRegister, YaoBase

export Ancilla

"""
    Ancilla{M, N, T, BT}

Block that provides some ancilla qubits and measure them away after the block scope finishs.
`N` is the total number of qubits, and `M` is the number of ancillas.
"""
mutable struct Ancilla{M, N, T, BT <: AbstractBlock{N, T}} <: AbstractContainer{BT, N, T}
    content::BT
    results::Vector{Int}
end

Ancilla{M}(x::AbstractBlock) where M = Ancilla{M, nqubits(x), datatype(x), typeof(x)}(x, Int[])
nancilla(x::Ancilla{N, M}) where {N, M} = M

function apply!(r::AbstractRegister{B, T}, x::Ancilla{M, N}) where {B, T, M, N}
    addbits!(r, nancilla(x))
    apply!(r, content(x))
    x.results = measure_remove!(r, (N-nancilla(x)+1):N)
    return r
end

cache_key(x::Ancilla) = cache_key(content(x))

# errr, maybe not?
mat(x::Ancilla) = mat(x.block)
