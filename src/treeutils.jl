using YaoBlocks, BitBasis
export flatten, replace_subblock

function dump_tree(io::IO, tree::AbstractBlock{N}, level::Int=0) where N
    dump_node(io, tree, level)
    dump_tree.(io, subblocks(tree), level+1)
end

function dump_node(io::IO, node::AbstractBlock, level::Int)
    ArgumentError("please define `dump(io::IO, node::$(typeof(node)), level::Int)` for $node.")
end

function dump_node(io::IO, node::ChainBlock, level::Int)
    for node in node
    println(io, )
end

function generate_tnet(tree::PutBlock{N}) where N
    for tree in
end

function generate_tnet(tree::ControlBlock{N}) where N
    for cbit
end

mutable struct GraphBuilder{T,AT}
    lines::Vector{Int}
    tensors::Vector{AT}
    labels::Vector{Tuple}
    label_counter::Int

    function GraphBuilder(lines::Vector{Int}, tensors::Vector{AT}, tp::Vector{Tuple}, label_counter::Int) where AT<:AbstractArray
        T = promote_type(eltype.(tensors)...)
        new{T,AbstractArray{T}}(lines, AbstractArray{T}[tensors...], tp, label_counter)
    end
    GraphBuilder(n::Int) = GraphBuilder(collect(1:n), fill([1, 0.0im], n), Vector{Tuple}([(i,) for i=1:n]), n)
end

nlines(gb::GraphBuilder) = length(gb.lines)
ntensors(gb::GraphBuilder) = length(gb.tensors)
assign_label(gb::GraphBuilder) = (gb.label_counter+=1; gb.label_counter)
get_label(gb::GraphBuilder, lineno::Int) = gb.lines[lineno]

function Base.show(io::IO, gb::GraphBuilder)
    print(io, summary(gb))
    for i=1:ntensors(gb)
        print(io, "T[$(gb.labels[i]...)] -> $(size(gb.tensors[i]))")
    end
end

function attach!(gb::GraphBuilder{T}, gate::Pair{Int,<:AbstractArray{T,2}}) where T
    gb.lines[gate.first] = assign_label(gb)
    push!(gb.tensors, gate.second)
    gb
end

function attach!(gb::GraphBuilder{T}, gate::Pair{NTuple{M,Int},<:AbstractArray{T,2}}) where {T,M}
    @assert M == log2dim1(gate.second)
    for loc in gate.first
        gb.lines[loc] = assign_label(gb)
    end
    push!(gb.tensors, gate.second)
    gb
end

function attach!(gb::GraphBuilder{T}, cbits::NTuple{C,Int}, gate::Pair{NTuple{M,Int},<:AbstractArray{T,2}}) where {C,T,M}
    @assert M == log2dim1(gate.second)
    for loc in cbits
        gb.lines[loc] = assign_label(gb)
        push!(gb.tensors, δ(3))
    end
    for loc in gate.first
        gb.lines[loc] = assign_label(gb)
    end
    push!(gb.tensors, gate.second)
    gb
end

using Test
@testset "GraphBuilder" begin
    gb = GraphBuilder(4)
    @test nlines(gb) == 4
    label = assign_label(gb)
    @test label == 5
    attach!(gb, 2=>mat(X))
    @test length(gb.tensors) == 5
    @test gb.label_counter == 6
    @test gb.lines == [1,6,3,4]
    attach!(gb, (1,2)=>mat(SWAP))
    @test gb.label_counter == 8
    @test gb.lines == [7,8,3,4]
end

"""
    flatten(tree::AbstractBlock, gateset)

Flatten the tree to `fundamental` blocks. It will do the following parsing

    * `RepeatedBlock` -> unpack,
    * `PauliString` -> `ChainBlock`,
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
_unpack(block::PauliString{N}) where N = _unpack(kron(block))
_unpack(block::KronBlock{N}) where N = chain(N, [put(N, i=>block[i]) for i=block.locs])

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
