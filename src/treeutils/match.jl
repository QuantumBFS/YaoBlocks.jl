export BlockVar, BlockMatch, var
# we will overload a lot match
# so I just import it here
import Base: match

# part of the design is shamelessly taken from simplify
# but we extend it for quantum circuit here, we can and should make
# use of Harrison's incoming Rewrite engine in the future to reduce
# duplications.
#
# I (Roger-luo) thank Harrison Grodin, Mason Potter and thautwarm 's
# helpful disscussion on symbolic manipulation and pattern matching

struct BlockVar{N} <: PrimitiveBlock{N}
    name::Symbol
end

BlockVar(n::Int) = BlockVar{n}(gensym())
occupied_locs(::BlockVar{N}) where N = Tuple(1:N)
subblocks(::BlockVar) = ()

"""
    isvar(x)

Check if `x` is a variable.
"""
isvar(x::BlockVar) = true
isvar(x) = false

"""
    var(n::Int[, name=gensym()])

Create a [`BlockVar`](@ref) by given number of qubits. A `BlockVar`
can be used to create quantum circuit patterns.

# Example

```jldoctest
julia> x = var(1, :x)
var(1, :x)

julia> match(chain(x, x), chain(X, X))
BlockMatch
Match 1
var(1, :x) matches
X gate
```

See also [`match`](@ref).
"""
var(n::Int, name::Symbol=gensym()) = BlockVar{n}(name)

"""
    var(name::Symbol)

Curried version of `var(n, name)` on the number of qubits.

```jldoctest
julia> var(:x)
(n -> var(n, x))
```
"""
var(name::Symbol) = @λ(n -> var(n, name))

print_block(io::IO, g::BlockVar{N}) where N = print(io, "var(", N, ", ", QuoteNode(g.name), ")")

mutable struct BlockMatch <: AbstractSet{AbstractDict{BlockVar, Any}}
    matches::Set{Dict{BlockVar, Any}}
end

BlockMatch(xs::Union{Pair, Dict}...) = BlockMatch(Set(Dict.(xs)))
Base.zero(::Type{BlockMatch}) = BlockMatch()
Base.one(::Type{BlockMatch}) = BlockMatch(Dict())
Base.length(Θ::BlockMatch) = length(Θ.matches)
Base.iterate(Θ::BlockMatch) = iterate(Θ.matches)
Base.iterate(Θ::BlockMatch, state) = iterate(Θ.matches, state)
Base.push!(Θ::BlockMatch, items...) = (push!(Θ.matches, items...); Θ)
Base.copy(Θ::BlockMatch) = BlockMatch(copy(Θ.matches))
Base.union(Θ₁::BlockMatch, Θ₂::BlockMatch) = BlockMatch(union(Θ₁.matches, Θ₂.matches))

function Base.merge!(Θ::BlockMatch, Θs::BlockMatch...)
    for Θ′ ∈ Θs
        result = BlockMatch()
        for σ′ ∈ Θ′
            foreach(Θ) do σ
                res = copy(σ)
                for (k, v) in σ′
                    if haskey(σ, k)
                        σ[k] == v || return
                    end
                    res[k] = v
                end
                push!(result, res)
            end
        end
        Θ.matches = result
    end
    Θ
end

Base.merge(σ::BlockMatch, σs::BlockMatch...) = merge!(one(BlockMatch), σ, σs...)

function Base.show(io::IO, m::BlockMatch)
    if isempty(m)
        print(io, "BlockMatch()")
    else
        summary(io, m)
        println(io)
        for (match_k, each_d) in enumerate(m)
            printstyled(io, "Match ", match_k, bold=true)
            println(io)
            count = 0
            for (k, v) in each_d
                count += 1
                print(io, k)
                printstyled(io, " matches", bold=true, color=:green)
                println(io)
                print(io, v)

                if count != length(each_d)
                    println(io)
                end
            end
        end
    end
end

# since QBIR is defined as an ADT
# we only need to deal with runtime pattern ourselves
# instead handle all the patterns here like what we do in Simplify
# multiple dispatch will handle all the static inferable pattern

"""
    match(pattern::AbstractBlock, t::AbstractBlock[, m::BlockMatch])

match a quantum circuit `t` to `pattern`, returns a `BlockMatch`, if the
user feed in a `BlockMatch`, it will merge the match with the new match.

# Example

You can match a pattern of quantum circuit by using [`BlockVar`](@ref).

```jldoctest
julia> p = chain(1, var(:x), chain(var(:x), var(:y)))
nqubits: 1
chain
├─ var(1, :x)
└─ chain
   ├─ var(1, :x)
   └─ var(1, :y)


julia> match(p, chain(X, chain(X, Y)))
BlockMatch
Match 1
var(1, :x) matches
X gate
var(1, :y) matches
Y gate
```

Associativity will be handle automatically.

```jldoctest
julia> p = chain(1, var(:x), chain(var(:y), var(:z)))
nqubits: 1
chain
├─ var(1, :x)
└─ chain
   ├─ var(1, :y)
   └─ var(1, :z)


julia> match(p, chain(X, Y, chain(Y, Z)))
BlockMatch
Match 1
var(1, :x) matches
nqubits: 1
chain
├─ X gate
└─ Y gate
var(1, :y) matches
Y gate
var(1, :z) matches
Z gate
```
"""
match(pattern::AbstractBlock, term::AbstractBlock) = match(pattern, term, one(BlockMatch))
# not match by default, so at least it won't be wrong
match(pattern::AbstractBlock, term::AbstractBlock, θ) = zero(BlockMatch)

# all the patterns and term has the same N below
# no need to check
function match(pattern::BlockVar{N}, term::AbstractBlock{N}, θ) where N
    return _var_match(pattern, term, θ)
end

function match(pattern::BlockVar{N}, term::PrimitiveBlock{N}, θ) where N
    return _var_match(pattern, term, θ)
end

function match(pattern::BlockVar{N}, term::CompositeBlock{N}, θ) where N
    return _var_match(pattern, term, θ)
end


_var_match(p::BlockVar, t::AbstractBlock, θ) = merge(θ, BlockMatch(p => t))

# chain is only associative
# it is equivalent to inline the subroutine
function match(pattern::ChainBlock{N}, term::ChainBlock{N}, θ) where N
    ac_match(pattern, term, θ)
end

# primitive block won't match composite block
function match(pattern::PrimitiveBlock{N}, term::CompositeBlock{N}, θ) where N
    return zero(BlockMatch)
end

# constant term will just return previous match
function match(pattern::B, term::B, θ) where {N, B <: PrimitiveBlock{N}}
    return θ
end

# in general, composite block won't match primitive
# but if it is associative with only one subnode, then
# it can match, e.g chain/kron
function match(pattern::CompositeBlock{N}, term::PrimitiveBlock{N}, θ) where N
    return zero(BlockMatch)
end

# fallback to pure match
function match(pattern::CompositeBlock{N}, term::CompositeBlock{N}, θ) where N
    pure_match(pattern, term, θ)
end

# we need to compare the positions for some vertical nodes
function match(pattern::AbstractContainer{<:Any, N}, term::AbstractContainer{<:Any, N}, θ) where N
    occupied_locs(pattern) == occupied_locs(term) || return zero(BlockMatch)
    return match(content(pattern), content(term), θ)
end

"""
    pure_match(pattern::CompositeBlock{N}, term::CompositeBlock{N}, θ::BlockMatch) where N

match `pattern` to `term` without making assumption on `pattern`'s properties such as associative,
communitive and anti-communitive. note this will still match its subblocks' properties.
"""
function pure_match(pattern::CompositeBlock{N}, term::CompositeBlock{N}, θ::BlockMatch) where N
    occupied_locs(pattern) == occupied_locs(term) || return zero(BlockMatch)
    for (x, y) in zip(subblocks(pattern), subblocks(term))
        θ = match(x, y, θ)
    end
    return θ
end

"""
    associative_match(pattern::AbstractBlock{N}, term::AbstractBlock{N}, θ::BlockMatch) where N

BlockMatch an associative node to another associative node, such as [`chain`](@ref), [`kron`](@ref),
Modified based on the implementation in [Simplify.jl](https://github.com/HarrisonGrodin/Simplify.jl/blob/master/src/match.jl),
based on the algorithm by [Krebber](https://arxiv.org/abs/1705.00907).
"""
function associative_match(p::AbstractBlock{N}, s::AbstractBlock{N}, θ::BlockMatch) where N
    pargs, sargs = subblocks(p), subblocks(s)
    m, n = length(pargs), length(sargs)
    m > n && return zero(BlockMatch)
    n_free = n - m
    n_vars = count(isvar, pargs)
    m_r = zero(BlockMatch)

    for k in Iterators.product((0:n_free for i in 1:n_vars)...)
        (isempty(k) ? 0 : sum(k)) == n_free || continue
        i, j = 1, 1
        m = θ
        for px in pargs
            l_sub = 0
            if isvar(px)
                l_sub += k[j]
                j += 1
            end
            new_s = l_sub > 0 ? chsubblocks(s, sargs[i:i+l_sub]) : sargs[i]
            m = match(px, new_s, m)
            isempty(m) && break
            i += l_sub + 1
        end
        m_r = union(m_r, m)
    end
    return m_r
end

# TODO: optimize performance
# I use some existing tools, but the performance might not be optimal
using Combinatorics: permutations

function ac_match(p::ChainBlock{N}, s::ChainBlock{N}, θ::BlockMatch) where N
    intervals = find_communitive_interval(s)
    isempty(intervals) && return pure_match(p, s, θ)

    it = Iterators.product(map(perms, find_communitive_interval(s))...)
    matches = map(it) do pms
        s′ = chain(N)
        for each in pms
            for k in each
                push!(s′, s[k])
            end
        end
        return associative_match(p, s′, θ)
    end

    return reduce(union, matches)
end

perms(x::UnitRange) = permutations(x)
perms(x::Int) = x

function find_communitive_interval(s::ChainBlock)
    L = length(s)
    head = 1
    tail = head
    intervals = Union{UnitRange{Int}, Int}[]
    while head <= L
        if tail < L && iscommute(s[tail], s[tail+1])
            tail += 1
        else
            if tail > head
                push!(intervals, head:tail)
            else
                push!(intervals, head)
            end
            head = tail + 1
            tail = head
        end
    end
    return intervals
end
