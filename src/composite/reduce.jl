using SimpleTraits.BaseTraits, SimpleTraits

export Sum

struct Sum{N} <: CompositeBlock{N}
    list::Vector{AbstractBlock{N}}

    Sum{N}(list::Vector{AbstractBlock{N}}) where N = new{N}(list)
    Sum{N}(it::T) where {N, T} = Sum{N}(SimpleTraits.trait(IsIterator{T}), it)
    Sum{N}(::Type{<:IsIterator}, it) where N = new{N}(collect(AbstractBlock{N}, it))
end

Sum{N}(::Not, it) where N = error("expect an iterator/collection")

Sum{N}() where N = Sum(AbstractBlock{N}[])
Sum(blocks::Vector{<:AbstractBlock{N}}) where N = Sum{N}(blocks)
Sum(blocks::AbstractBlock{N}...) where N = Sum(collect(AbstractBlock{N}, blocks))

mat(::Type{T}, x::Sum) where T = mapreduce(x->mat(T, x), +, x.list)

chsubblocks(x::Sum{N}, it) where N = Sum{N}(it)

function apply!(r::AbstractRegister, x::Sum)
    isempty(x.list) && return r
    length(x.list) == 1 && return apply!(r, x.list[])

    res = mapreduce(blk->apply!(copy(r), blk), +, x.list[1:end-1])
    apply!(r, x.list[end])
    r.state .+= res.state
    r
end

export Sum

subblocks(x::Sum) = x.list
cache_key(x::Sum) = map(cache_key, x.list)
Base.copy(x::Sum) = Sum(copy(x.list))
Base.similar(c::Sum{N}) where N = Sum{N}(empty!(similar(c.list)))

function Base.:(==)(lhs::Sum{N}, rhs::Sum{N}) where {N}
    (length(lhs.list) == length(rhs.list)) && all(lhs.list .== rhs.list)
end

for FUNC in [:length, :iterate, :getindex, :eltype, :eachindex, :popfirst!, :lastindex]
    @eval Base.$FUNC(x::Sum, args...) = $FUNC(subblocks(x), args...)
end

Base.getindex(c::Sum, index::Union{UnitRange, Vector}) = Sum(getindex(c.list, index))
Base.setindex!(c::Sum{N}, val::AbstractBlock{N}, index::Integer) where N = (setindex!(c.list, val, index); c)
Base.insert!(c::Sum{N}, index::Integer, val::AbstractBlock{N}) where N = (insert!(c.list, index, val); c)
Base.adjoint(blk::Sum{N}) where N = Sum{N}(map(adjoint, subblocks(blk)))

## Iterate contained blocks
occupied_locs(c::Sum) = Tuple(unique(Iterators.flatten(occupied_locs(b) for b in subblocks(c))))

# Additional Methods for Sum
Base.push!(c::Sum{N}, val::AbstractBlock{N}) where N = (push!(c.list, val); c)

function Base.push!(c::Sum{N}, val::Function) where {N}
    push!(c, val(N))
end

function Base.append!(c::Sum, list)
    for blk in list
        push!(c, blk)
    end
    c
end

function Base.prepend!(c::Sum, list)
    for blk in list[end:-1:1]
        insert!(c, 1, blk)
    end
    c
end

YaoBase.ishermitian(ad::Sum) = all(ishermitian, ad.list) || ishermitian(mat(ad))
