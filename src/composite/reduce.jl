export Sum

struct Sum{N, List <: Tuple} <: CompositeBlock{N}
    list::List

    Sum{N}(list::Tuple) where {N} = new{N, typeof(list)}(list)
    Sum(list::AbstractBlock{N}...) where N = new{N, typeof(list)}(list)
end

# merge prod & sum
Sum(a::Sum{N}, blks::Union{Sum{N}, AbstractBlock{N}}...) where N =
    Sum{N}((a.list..., ), blks...)
Sum(a::AbstractBlock{N}, blks::Union{Sum{N}, AbstractBlock{N}}...) where N =
    Sum{N}((a, ), blks...)
Sum{N}(a::Tuple, b::Sum, blks::Union{Sum{N}, AbstractBlock{N}}...) where N =
    Sum{N}((a..., b.list...), blks...)
Sum{N}(a::Tuple, b::AbstractBlock{N}, blks::Union{Sum{N}, AbstractBlock{N}}...) where N =
    Sum{N}((a..., b), blks...)

mat(::Type{T}, x::Sum) where T = mapreduce(x->mat(T, x), +, x.list)

chsubblocks(x::Sum{N}, it) where N = Sum{N}(Tuple(it))

function apply!(r::AbstractRegister, x::Sum)
    out = copy(r)
    apply!(out, first(x))
    for k in 2:length(x)
        out += apply!(copy(r), x[k])
    end
    copyto!(r, out)
    return r
end

export Sum

apply!(r::AbstractRegister, x::Sum{N, Tuple{}}) where N = r
apply!(r::AbstractRegister, x::Sum{N, Tuple{<:AbstractBlock}}) where N =
    apply!(r, first(x))

subblocks(x::Sum) = x.list
cache_key(x::Sum) = map(cache_key, x.list)

Base.length(x::Sum) = length(x.list)
Base.iterate(x::Sum) = iterate(x.list)
Base.iterate(x::Sum, st) = iterate(x.list, st)
Base.getindex(x::Sum, k) = getindex(x.list, k)

function Base.:(==)(lhs::Sum{N}, rhs::Sum{N}) where N
    for (a, b) in zip(lhs, rhs)
        a == b || return false
    end
    return true
end
