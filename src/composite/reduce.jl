export Sum, Prod

struct Sum{N, List <: Tuple} <: CompositeBlock{N}
    list::List

    Sum{N}(list::Tuple) where {N} = new{N, typeof(list)}(list)
    Sum(list::AbstractBlock{N}...) where N = new{N, typeof(list)}(list)
end

struct Prod{N, List <: Tuple} <: CompositeBlock{N}
    list::List

    Prod{N}(list::Tuple) where N = new{N, typeof(list)}(list)
    Prod(list::AbstractBlock{N}...) where N = new{N, typeof(list)}(list)
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

Prod(a::Prod{N}, blks::Union{Prod{N}, AbstractBlock{N}}...) where N =
    Prod{N}((a.list..., ), blks...)
Prod(a::AbstractBlock{N}, blks::Union{Prod{N}, AbstractBlock{N}}...) where N =
    Prod{N}((a, ), blks...)
Prod{N}(a::Tuple, b::Prod, blks::Union{Prod{N}, AbstractBlock{N}}...) where N =
    Prod{N}((a..., b.list...), blks...)
Prod{N}(a::Tuple, b::AbstractBlock{N}, blks::Union{Prod{N}, AbstractBlock{N}}...) where N =
    Prod{N}((a..., b), blks...)

mat(::Type{T}, x::Sum) where T = mapreduce(x->mat(T, x), +, x.list)
mat(::Type{T}, x::Prod) where T = mapreduce(x->mat(T, x), *, x.list)

chsubblocks(x::Sum{N}, it) where N = Sum{N}(Tuple(it))
chsubblocks(x::Prod{N}, it) where N = Prod{N}(Tuple(it))

function apply!(r::AbstractRegister, x::Sum)
    out = copy(r)
    apply!(out, first(x))
    for k in 2:length(x)
        out += apply!(copy(r), x[k])
    end
    copyto!(r, out)
    return r
end

function apply!(r::AbstractRegister, x::Prod)
    for each in Iterators.reverse(x.list)
        apply!(r, each)
    end
    return r
end

export ReduceOperator

const ReduceOperator{N, List} = Union{Sum{N, List}, Prod{N, List}}

apply!(r::AbstractRegister, x::ReduceOperator{N, Tuple{}}) where N = r
apply!(r::AbstractRegister, x::ReduceOperator{N, Tuple{<:AbstractBlock}}) where N =
    apply!(r, first(x))

subblocks(x::ReduceOperator) = x.list
cache_key(x::ReduceOperator) = map(cache_key, x.list)

Base.length(x::ReduceOperator) = length(x.list)
Base.iterate(x::ReduceOperator) = iterate(x.list)
Base.iterate(x::ReduceOperator, st) = iterate(x.list, st)
Base.getindex(x::ReduceOperator, k) = getindex(x.list, k)

function Base.:(==)(lhs::Prod{N}, rhs::Prod{N}) where N
    for (a, b) in zip(lhs, rhs)
        a == b || return false
    end
    return true
end

function Base.:(==)(lhs::Sum{N}, rhs::Sum{N}) where N
    for (a, b) in zip(lhs, rhs)
        a == b || return false
    end
    return true
end
