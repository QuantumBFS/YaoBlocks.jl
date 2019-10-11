abstract type AbstractRule end

struct PatternRule{P, T} <: AbstractRule
    pattern::P
    term::T
end

function simplify(circuit::AbstractBlock)
end
