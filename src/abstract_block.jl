export AbstractBlock

using YaoBase, YaoArrayRegister
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
struct AtLeast{N} <: BlockSize end

BlockSize(x::AbstractBlock{N}) where N = NormalSize{N}()
BlockSize(x::AbstractBlock{FullSize}) = FullSize()
BlockSize(blocks::AbstractBlock...) = BlockSize(BlockSize.(blocks)...)
BlockSize(::NormalSize{N}...) where N = NormalSize{N}()

_loose_bound(::Type{<:NormalSize}) = AtLeast
_loose_bound(::Type{<:AtLeast}) = FullSize
_loose_bound(::Type{<:FullSize}) = error("FullSize can not be loosed")

@inline find_blocksize(blocksizes) = find_blocksize(NormalSize, blocksizes)
@inline function find_blocksize(::Type{T}, blocksizes) where {T <: BlockSize}
    k = findfirst(x->x <: T, blocksizes)
    if k !== Nothing
        return blocksizes[k]
    else
        return find_blocksize(_loose_bound(T), blocksizes)
    end
end

@inline function find_blocksize(::Type{FullSize}, blocksizes)
    k = findfirst(x->x <: FullSize, blocksizes)
    if k === Nothing
        error("no valid type of block size")
    else
        return blocksizes[k]
    end
end

@generated function BlockSize(blocksizes::BlockSize...)
    return BlockSize(blocksizes)
end

@generated function BlockSize(blocksizes::Tuple)
    return BlockSize(blocksizes.parameters)
end

function BlockSize(blocksizes)
    # NOTE: we follow the following rules
    #       1. if there is NormalSize{N}, N = N
    #       2. elseif there is AtLeast{N}, N = AtLeast{N}
    #       3. elseif there is FullSize, N = FullSize
    #       4. else, error

    # try to find the first valid size
    expect = find_blocksize(blocksizes)

    # check if this list of size is match
    for each in blocksizes
        if !isequal(expect, each)
            error("size mismatch, expect block with $(expect) qubits, got $each")
        end
    end
    return expect
end


YaoBase.nqubits(::Type{MT}) where {N, MT <: AbstractBlock{N}} = N
YaoBase.nqubits(::AbstractBlock{N}) where N = N
YaoBase.nqubits(::AbstractBlock{FullSize}) = FullSize()
YaoBase.nqubits(::AbstractBlock{AtLeast{N}}) where N = AtLeast{N}()
YaoBase.nqubits(::NormalSize{N}) where N = N
YaoBase.nqubits(x::BlockSize) = x
YaoBase.nqubits(::Type{<:NormalSize{N}}) where N = N
YaoBase.nqubits(::Type{T}) where T <: BlockSize = T

Base.isequal(::NormalSize{N}, ::NormalSize{N}) where N = true
Base.isequal(::NormalSize, ::NormalSize) = false
Base.isequal(::NormalSize, ::FullSize) = true
Base.isequal(::FullSize, ::NormalSize) = true
Base.isequal(::NormalSize{N}, ::AtLeast{K}) where {N, K} = N > K
Base.isequal(::AtLeast{K}, ::NormalSize{N}) where {N, K} = N > K
Base.isequal(::AtLeast, ::FullSize) = true
Base.isequal(::FullSize, ::AtLeast) = true


@generated function assert_blocks(list::Tuple)
    return assert_blocks(list.parameters)
end

function assert_blocks(list)
    for (k, each) in enumerate(list)
        if !(each <: AbstractBlock)
            error("Expect a block of circuit, got $each at index [$k]")
        end
    end
    return nothing
end

@generated function find_datatype(list::Tuple)
    return find_datatype(list.parameters)
end

function find_datatype(list_of_block_types)
    Ts = map(datatype, list_of_block_types)
    iT = findfirst(x->x !== Any, Ts)
    iT === Nothing && error("cannot find valid data type")

    T = Ts[iT] # assign the first concrete data type
    for (k, each) in enumerate(Ts)
        if T === each || each === Any
            continue
        else
            error("expect $T got $each at $k")
        end
    end
    return T
end
