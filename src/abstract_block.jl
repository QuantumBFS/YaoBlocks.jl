export AbstractBlock

using YaoBase
import YaoBase: @interface

export nqubits,
    datatype,
    isunitary,
    isreflexive,
    ishermitian


"""
    AbstractBlock

Abstract type for quantum circuit blocks.
"""
abstract type AbstractBlock{N, T} end

"""
    |>(register, blk)

Pipe operator for quantum circuits.

# Example

```julia
julia> ArrayReg(bit"0") |> X |> Y
```

!!! warning

    `|>` is equivalent to [`apply!`](@ref), which means it has side effects. You
    need to copy original register, if you do not want to change it in-place.
"""
Base.:(|>)(r::AbstractRegister, blk::AbstractBlock) = apply!(r, blk)

"""
    OccupiedLocations(x)

Return an iterator of occupied locations of `x`.
"""
@interface OccupiedLocations(x::AbstractBlock) = 1:nqubits(x)

"""
    applymatrix(g::AbstractBlock) -> Matrix

Transform the apply! function of specific block to dense matrix.
"""
@interface applymatrix(g::AbstractBlock) = linop2dense(r->statevec(apply!(ArrayReg(r), g)), nqubits(g))

@interface print_block(io::IO, blk::AbstractBlock) = print_block(io, MIME("text/plain"), blk)
print_block(blk::AbstractBlock) = print_block(stdout, blk)
print_block(io::IO, ::MIME"text/plain", blk::AbstractBlock) = summary(io, blk)

# return itself by default
Base.copy(x::AbstractBlock) = x


# YaoBase interface
YaoBase.nqubits(::Type{MT}) where {N, MT <: AbstractBlock{N}} = N
YaoBase.nqubits(x::AbstractBlock{N}) where N = nqubits(typeof(x))
YaoBase.datatype(x::AbstractBlock{N, T}) where {N, T} = T
YaoBase.datatype(::Type{<:AbstractBlock{N, T}}) where {N, T} = T

# properties
for each_property in [:isunitary, :isreflexive, :ishermitian]
    @eval YaoBase.$each_property(x::AbstractBlock) = $each_property(mat(x))
    @eval YaoBase.$each_property(::Type{T}) where T <: AbstractBlock = $each_property(mat(T))
end

function iscommute_fallback(op1::AbstractBlock{N}, op2::AbstractBlock{N}) where N
    if length(intersect(occupied_locations(op1), occupied_locations(op2))) == 0
        return true
    else
        return iscommute(mat(op1), mat(op2))
    end
end

YaoBase.iscommute(op1::AbstractBlock{N}, op2::AbstractBlock{N}) where N =
    iscommute_fallback(op1, op2)

export MatrixTrait

abstract type MatrixTrait end
struct HasMatrix{N, T} <: MatrixTrait end
struct MatrixUnkown <: MatrixTrait end

# NOTE: most blocks have matrix, use `HasMatrix` by default.
#       this will error when `mat` is not defined anyway, no worries.
MatrixTrait(x::AbstractBlock) = HasMatrix{nqubits(x), datatype(x)}()

MatrixTrait(xs::AbstractBlock...) = MatrixTrait(MatrixTrait.(xs)...)
MatrixTrait(::HasMatrix{N, T}...) where {N, T} = HasMatrix{N, T}()
MatrixTrait(::Union{HasMatrix, MatrixUnkown}...) = MatrixUnkown()

"""
    mat(blk)

Returns the matrix form of given block.
"""
@interface mat(x::AbstractBlock) = mat(MatrixTrait(x), x)
mat(::HasMatrix, x::AbstractBlock) =
    error("You need to define the matrix of $(typeof(x)), or declare it does not have a matrix")
mat(::MatrixUnkown, x::AbstractBlock) = error("$(typeof(x)) does not have a matrix")

"""
    apply!(register, block)

Apply a block (of quantum circuit) to a quantum register.
"""
@interface apply!(r::AbstractRegister, b::AbstractBlock) = apply!(MatrixTrait(b), r, b)

function apply!(::HasMatrix, r::ArrayReg, b::AbstractBlock)
    copyto!(r.state, mat(b) * r.state)
    return r
end

function apply!(::MatrixUnkown, r::AbstractRegister, b::AbstractBlock)
    error("method apply! is not defined for $(typeof(b)), and circuit block $(typeof(b)) does not have a matrix representation.")
end

export BlockSize

abstract type BlockSize end
struct NormalSize{N} <: BlockSize end
struct FullSize <: BlockSize end
struct UnkownSize <: BlockSize end

BlockSize(x::AbstractBlock{N}) where N = NormalSize{N}()
BlockSize(x::AbstractBlock{UnkownSize}) = UnkownSize()
BlockSize(x::AbstractBlock{FullSize}) = FullSize()
BlockSize(blocks::AbstractBlock...) = BlockSize(BlockSize.(blocks)...)
BlockSize(::NormalSize{N}...) where N = NormalSize{N}()
BlockSize(::BlockSize...) = UnkownSize()

function YaoBase.nqubits(x::AbstractBlock{UnkownSize})
    error("cannot inference the total number of qubits of given block of $(typeof(x))")
end

function YaoBase.nqubits(x::AbstractBlock{FullSize})
    throw(MethodError(nqubits, (x, )))
end
