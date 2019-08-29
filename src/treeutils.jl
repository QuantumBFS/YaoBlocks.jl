export flatten, replace_subblock

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
function flatten(tree::AbstractBlock{N}) where N
    _unchain(_unpack(tree))
end

function _unpack(block::AbstractBlock{N})
    replace_block(tree) do
        if target isa RepeatedBlock
            return chain(N, map(put(N, i=>flatten(content(target))), rb.locs))
        end
    end
end

_unpack(block::CachedBlock) = content(block)
_unpack(block::Concentrator) = content(block)
_unpack(block::PauliString{N}) = kron(block)

_unchain(tree::AbstractBlock{N}) where N = _unchain!(tree, chain(N))
_unchain!(tree::AbstractBlock{N}, res::ChainBlock) = push!(res, tree)
function _unchain!(tree::ChainBlock{N}, res::ChainBlock)
    for blk in subblocks(tree)
        _unchain!(tree, res)
    end
    return res
end


"""
    replace_block(actor, tree::AbstractBlock) -> AbstractBlock
    replace_block(pair::Pair{Type{ST}, TT}, tree::AbstractBlock) -> AbstractBlock

replace blocks in a circuit, where `actor` is a function that given input block,
returns the block to replace, or `nothing` for skip replacing and visit sibling.
If `pair` is provided, then replace original block with type `ST` with new block (`pair.second`).
"""
function replace_block(actor, tree::AbstractBlock)
    res = actor(block)
    if res isa Nothing # not replaced
        return chsubblocks(block, replace_block.(Ref(tree), Ref(condition), subblocks(tree)))
    else
        return res
    end
end

replace_block(pair::Pair{Type{ST}, TT}, tree::AbstractBlock) where {BT<:AbstractBlock, TT<:AbstactBlock} = replace_block(x->x isa ST ? pair.second : nothing, tree)

