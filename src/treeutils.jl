"""
    flatten(tree::AbstractBlock, gateset)

Flatten the tree to `fundamental` blocks. It will do the following parsing

    * `RepeatedBlock` -> unpack,
    * `PauliString` -> `KronBlock`,
    * `Concentrator` -> unpack,
    * `ChainBlock` -> unpack,
    * `CachedBlock` -> uncache.

`gateset` is the gate types to be unpacked, e.g. Union{Chain, Concentrator}, it unpacks any unpackable block by default.
"""
function flatten(tree::AbstractBlock, gateset::Type{GT}) where GT<:AbstractBlock
end

function simplify()
