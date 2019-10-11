abstract type AbstractRule end

struct PatternRule{P, T} <: AbstractRule
    pattern::P
    term::T
end

struct Rules
    rules::Vector{AbstractRule}
end

Rules(rules...) = Rules(collect(AbstractRule, rules))

function rule(::Val{N}, ::Val{:BASIC}) where N
    x, y, z = var(N), var(N), var(N)
    Rules(
        chain(x, chain(y, z)) => chain(x, y, z),
        kron(x, kron(y, z)) => kron(x, y, z),
    )
end

function simplify(circuit::AbstractBlock)
end

function simplify(circuit::AbstractBlock, r::PatternRule)
    m = match(r.pattern, circuit)
    isempty(m) && return circuit

    d = first(m) # we only use the first match for now
    replace(r.term, d)
end
