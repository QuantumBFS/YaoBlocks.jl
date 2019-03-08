parse_block(n::Int, x::Function) = x(n)

parse_block(n::Int, x::AbstractBlock) = parse_block(n, BlockSize(x), x)

function parse_block(n::Int, ::NormalSize{N}, x::AbstractBlock) where N
    n == N || throw(ArgumentError("number of qubits does not match: $x"))
    return x
end

parse_block(n::Int, ::BlockSize, x::AbstractBlock) = x
