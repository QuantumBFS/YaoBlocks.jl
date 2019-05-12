# A Simple Computational Algebra System

# scale
Base.:(-)(x::AbstractBlock{N}) where {N} = Scale(Val(-1), x)
Base.:(-)(x::Scale{Val{-1}}) = content(x)
Base.:(-)(x::Scale{Val{S}}) where S = Scale(Val(-S), content(x))
Base.:(-)(x::Scale) = Scale(-x.alpha, content(x))
Base.:(+)(x::AbstractBlock) = x

Base.:(*)(x::AbstractBlock, α::Number) = α * x

# NOTE: ±,±im should be identical
Base.:(*)(α::Val{S}, x::AbstractBlock) where S = Scale(α, x)

function Base.:(*)(α::T, x::AbstractBlock) where T <: Number
    return α ==  one(T) ? x                 :
    α == -one(T) ? Scale(Val(-1), x)   :
    α ==      im ? Scale(Val(im), x)        :
    α ==     -im ? Scale(Val(-im), x)       :
    Scale(α, x)
end

Base.:(*)(α::T, x::Scale) where {T <: Number} = α == one(T) ? x : Scale(x.alpha * α, content(x))
Base.:(*)(α::T, x::Scale{Val{S}}) where {T <: Number, S} = α * S * content(x)

Base.:(*)(α::Val{S}, x::Scale) where S = (S * x.alpha) * content(x)
Base.:(*)(α::Val{S1}, x::Scale{Val{S2}}) where {S1, S2} = (S1 * S2) * content(x)

Base.:(*)(x::Scale, y::Scale) = (x.alpha * y.alpha) * (content(x) * content(y))
Base.:(*)(x::Scale{Val{S1}}, y::Scale{Val{S2}}) where {S1, S2} = (S1 * S2) * (content(x) * content(y))
Base.:(*)(x::Scale, y::Scale{Val{S}}) where S = (x.alpha * S) * (content(x) * content(y))
Base.:(*)(x::Scale{Val{S}}, y::Scale) where S = (S * y.alpha) * (content(x) * content(y))
Base.:(*)(x::Scale, y::AbstractBlock) = x.alpha * Prod(content(x), y)
Base.:(*)(y::AbstractBlock, x::Scale) = x.alpha * Prod(y, content(x))

Base.:(+)(xs::AbstractBlock...) = Sum(xs...)
Base.:(*)(xs::AbstractBlock...) = Prod(xs...)
Base.:(/)(A::AbstractBlock, x::Number) = (1/x)*A
# reduce
Base.sum(a::AbstractBlock{N}, blocks::AbstractBlock{N}...) where N = Sum(a, blocks...)
Base.prod(a::AbstractBlock{N}, blocks::AbstractBlock{N}...) where N = Prod(a, blocks...)

Base.:(-)(lhs::AbstractBlock, rhs::AbstractBlock) = Sum(lhs, -rhs)
Base.:(^)(x::AbstractBlock, n::Int) = Prod((copy(x) for k in 1:n)...)

for G in [:I2, :X, :Y, :Z]
    ImG = Symbol(:Im, G)
    nImG = Symbol(:nIm, G)
    nG = Symbol(:n, G)
    GGate = Symbol(G, :Gate)
    @eval const $ImG = Scale{Val{im}, 1, $GGate}
    @eval const $nImG = Scale{Val{-im}, 1, $GGate}
    @eval const $nG = Scale{Val{-1}, 1, $GGate}
end


const PauliGroup = Union{
    PauliGate, nX, nY, nZ, nI2,
    ImX, ImY, ImZ, nImX, nImY, nImZ, ImI2, nImI2}

merge_pauli(x) = x
merge_pauli(ex::Prod{1}) = merge_pauli(ex, ex.list...)

# Well, there should be some way to do this, but just
# too lazy to implement this pass
merge_pauli(ex::ChainBlock) = Prod(Iterators.reverse(subblocks(ex))...)

merge_pauli(ex::Prod{1}, blks::AbstractBlock...) = merge_pauli(ex, (), blks...)

merge_pauli(ex::Prod{1}, out::Tuple, a::AbstractBlock{1}, blks::AbstractBlock{1}...) =
    merge_pauli(ex, (out..., a), blks...)
merge_pauli(ex::Prod{1}, out::Tuple, a::PauliGroup, blks::AbstractBlock{1}...) =
    merge_pauli(ex, (out..., a), blks...)
merge_pauli(ex::Prod{1}, out::Tuple, a::PauliGroup, b::PauliGroup, blks::AbstractBlock{1}...) =
    merge_pauli(ex, (out..., merge_pauli(a, b)), blks...)

merge_pauli(ex::Prod{N}, out::Tuple) where N = Prod(out...)
merge_pauli(ex::Prod{N}, out::Tuple{}) where N = IGate{N, T}()
merge_pauli(ex::Prod{1}, out::Tuple{})= I2

merge_pauli(::XGate, ::YGate) = ImZ
merge_pauli(::XGate, ::ZGate) = -ImY
merge_pauli(::YGate, ::XGate) = -ImZ
merge_pauli(::YGate, ::ZGate) = ImX
merge_pauli(::ZGate, ::XGate) = ImY
merge_pauli(::ZGate, ::YGate) = ImX

for G in [:X, :Y, :Z]
    GT = Symbol(G, :Gate)

    @eval merge_pauli(::I2Gate, x::$GT) = x
    @eval merge_pauli(x::$GT, ::I2Gate) = x
    @eval merge_pauli(::$GT, ::$GT) = I2
end

merge_pauli(::I2Gate, ::I2Gate) = I2
merge_pauli(x::PauliGroup, y::PauliGroup) = x * y

eliminate_nested(ex::AbstractBlock) = ex

# TODO: eliminate nested expr e.g chain(X, chain(X, Y))
function eliminate_nested(ex::Union{Prod, ChainBlock, Sum})
    _flatten(x) = (x, )
    _flatten(x::Union{Prod, ChainBlock}) = subblocks(x)

    isone(length(ex)) && return first(subblocks(ex))
    return chsubblocks(ex, Iterators.flatten(map(_flatten, subblocks(ex))))
end

# temporary utils
_unscale(x::AbstractBlock) = x
_unscale(x::Scale) = content(x)
merge_alpha(alpha, x::AbstractBlock) = alpha
merge_alpha(alpha, x::Scale) = alpha * x.alpha
merge_alpha(alpha, x::Scale{Val{S}}) where S = alpha * S

merge_scale(ex::AbstractBlock) = ex

# a simple function to find one for Val and Number
_one(x) = one(x)
_one(::Val{S}) where S = one(S)

function merge_scale(ex::Union{Scale{S, N}, Prod{N}, ChainBlock{N}}) where {S, N}
    alpha = _one(S)
    for each in subblocks(ex)
        alpha = merge_alpha(alpha, each)
    end
    ex = chsubblocks(ex, map(_unscale, subblocks(ex)))
    return alpha * ex
end

combine_similar(ex::AbstractBlock) = ex

function combine_similar(ex::Sum{N}) where N
    table = zeros(Bool, length(ex))
    list = []; p = 1
    while p <= length(ex)
        if table[p] == true
            # checked term, skip
            p += 1
        else
            # check similar term
            term = ex[p]
            table[p] = true # mark it in the table
            alpha = 1.0
            for (k, each) in enumerate(ex)
                if table[k] == true # checked term, skip
                    continue
                else
                    # check if unscaled term is the same
                    # merge them if they are
                    if _unscale(term) == _unscale(each)
                        alpha += merge_alpha(alpha, seach)
                        # mark checked term in the table
                        table[k] = true
                    end
                end
            end

            # eliminate zeros
            if alpha != 0
                alpha = imag(alpha) == 0 ? real(alpha) : alpha
                alpha = isinteger(alpha) ? Integer(alpha) : alpha
                push!(list, alpha * term)
            end
        end
    end

    if isempty(list)
        return Sum{N}(())
    else
        return Sum(list...)
    end
end

export simplify

const __default_simplification_rules__ = Function[
    merge_pauli,
    eliminate_nested,
    merge_scale,
    combine_similar]

# Inspired by MasonPotter/Symbolics.jl
"""
    simplify(block[; rules=__default_simplification_rules__])

Simplify a block tree accroding to given rules, default to use
[`__default_simplification_rules__`](@ref).
"""
function simplify(ex::AbstractBlock; rules=__default_simplification_rules__)
    out1 = simplify_pass(rules, ex)
    out2 = simplify_pass(rules, out1)
    counter = 1
    while (out1 isa AbstractBlock) && (out2 isa AbstractBlock) && (out2 != out1)
        out1 = simplify_pass(rules, out2)
        out2 = simplify_pass(rules, out1)
        counter += 1
        if counter > 1000
            @warn "possible infinite loop in simplification rules. Breaking"
            return out2
        end
    end
    return out2
end

function simplify_pass(rules, ex)
    ex = chsubblocks(ex, map(x->simplify_pass(rules, x), subblocks(ex)))

    for rule in rules
        ex = rule(ex)
    end
    return ex
end
