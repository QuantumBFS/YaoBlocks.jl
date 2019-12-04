export dump_gate

function dump_gate(blk::ConstantGate)
    Symbol("$(typeof(blk).name)"[1:end-4])
end

function dump_gate(blk::ControlBlock)
    pairs = [b=>c for (b,c) in zip(blk.ctrl_locs, blk.ctrl_config)]
    :($(pairs...), $(blk.locs) => $(dump_gate(blk.content)))
end

function dump_gate(blk::ChainBlock)
    Expr(:block, [dump_gate(b) for b in blk]...)
end

function dump_gate(blk::RotationGate)
    :(rot($(dump_gate(blk.block)), $(blk.theta)))
end

function dump_gate(blk::PhaseGate)
    :(phase($(blk.theta)))
end

function dump_gate(blk::ShiftGate)
    :(shift($(blk.theta)))
end

function dump_gate(blk::TimeEvolution)
    :(time($(blk.dt)) => $(dump_gate(blk.H)))
end

function dump_gate(blk::AbstractBlock)
    vars = [getproperty(blk, x) for x in fieldnames(typeof(blk))]
    :($(typeof(blk))($(vars...)))
end

function dump_gate(blk::PutBlock)
    :($(blk.locs) => $(dump_gate(blk.content)))
end

function dump_gate(blk::KronBlock{N}) where N
    if any(x->nqubits(x)!=1, subblocks(blk))
        error("unsupported multi-qubit in kron while dumping to Yao script.")
    end
    :(kron($([dump_gate(blk[i]) for i=1:N]...)))
end

function dump_gate(blk::RepeatedBlock)
    :(repeat($(blk.locs...)) => $(dump_gate(blk.content)))
end

function dump_gate(blk::Add)
    :(+($(dump_gate.(subblocks(blk))...)))
end

function dump_gate(blk::Daggered)
    :($(dump_gate(blk.content))')
end

function dump_gate(blk::CachedBlock)
    :(cache($(dump_gate(blk.content))))
end

function dump_gate(blk::Scale)
    :($(factor(blk))*$(dump_gate(blk.content)))
end

"""not yet complete!"""
function dump_gate(blk::Measure{N,M}) where {M,N}
    if blk.operator == ComputationalBasis()
        MOP = :(Measure)
    else
        MOP = :(Measure($(dump_gate(blk.operator))))
    end
    locs = blk.locations isa AllLocs ? :ALL : blk.locations
    if blk.collapseto == nothing
        :($locs => $MOP)
    else
        :($locs => $MOP => ($(blk.collapseto...),))
    end
end

function dump_gate(blk::Concentrator)
    :(focus($(blk.locs...)) => $(dump_gate(blk.content)))
end

yaotostring(block::AbstractBlock{N}) where N = Expr(:block, :(nqubits=$N), dump_gate(block))
function yaotostring(block::ChainBlock{N}) where N
    ex = dump_gate(block)
    insert!(ex.args, 1, :(nqubits=$N))
    ex
end
yaotofile(filename::String, block) = write(filename, string(yaotostring(block)))
