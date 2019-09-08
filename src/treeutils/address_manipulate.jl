export map_address, AddressInfo

struct AddressInfo
    nbits::Int
    addresses::Vector{Int}
end
Base.copy(info::AddressInfo) = AddressInfo(copy(info.addresses))
Base.:/(locs, info::AddressInfo) = map(loc->info.addresses[loc], locs)
Base.:/(locs::AllLocs, info::AddressInfo) = info.addresses

"""
    map_address(block::AbstractBlock, info::AddressInfo) -> AbstractBlock
"""
function map_address end

function map_address(block::AbstractBlock, info::AddressInfo)
    throw(NotImplementedError(:map_address, typeof(block)))
end

function map_address(blk::Measure, info::AddressInfo)
    m = Measure(info.nbits; rng=blk.rng, operator=blk.operator, locs=blk.locations/info,
        collapseto=blk.collapseto, remove=blk.remove)
    if isdefined(blk, :results)
        m.results = blk.results
    end
    return m
end

map_address(blk::PrimitiveBlock, info::AddressInfo) = blk
map_address(blk::PutBlock, info::AddressInfo) = put(info.nbits, blk.locs/info=>content(blk))

function map_address(blk::ControlBlock, info::AddressInfo)
    ControlBlock{info.nbits}(blk.ctrl_locs/info, blk.ctrl_config, content(blk), blk.locs/info)
end

function map_address(blk::KronBlock, info::AddressInfo)
    kron(info.nbits, [l=>G for (l,G) in zip(blk.locs/info, blk.blocks)]...)
end

function map_address(blk::RepeatedBlock, info::AddressInfo)
    repeat(info.nbits, content(blk), blk.locs/info)
end

function map_address(blk::Concentrator, info::AddressInfo)
    concentrate(info.nbits, content(blk), blk.locs/info)
end

function map_address(blk::ChainBlock, info::AddressInfo)
    chain(info.nbits, map(b->map_address(b, info), subblocks(blk)))
end

function map_address(blk::Daggered, info::AddressInfo)
    Daggered(map_address(content(blk), info))
end

function map_address(blk::CachedBlock, info::AddressInfo)
    CachedBlock(blk.server, map_address(content(blk), info), blk.level)
end

function map_address(blk::Scale, info::AddressInfo)
    Scale(blk.alpha, map_address(content(blk), info))
end

function map_address(blk::Add, info::AddressInfo)
    Add{info.nbits}(map(b->map_address(b, info), subblocks(blk)))
end
