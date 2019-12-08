import YaoBase: measure!, measure
using LinearAlgebra: eigen!

"""
    eigenbasis(op::AbstractBlock{N})

Return the `eigenvalue` and `eigenvectors` of target operator.
By applying `eigenvector`' to target state,
one can swith the basis to the eigenbasis of this operator.
However, `eigenvalues` does not have a specific form.
"""
function eigenbasis(op::AbstractBlock{N}) where N
    m = mat(op)
    if m isa Diagonal || m isa IMatrix
        diag(m), IdentityGate{N}()
    else
        E, V = eigen!(Matrix(m))
        E, matblock(V)
    end
end

function eigenbasis(op::PutBlock{N}) where N
    E, V = eigenbasis(content(op))
    E, put(N, op.locs=>V)
end

function eigenbasis(op::KronBlock{N}) where N
    E = []
    blks = []
    for (k,b) in op
        Ei, Vi = eigenbasis(b)
        push!(E, Ei)
        push!(blks, k=>Vi)
    end
    (E...,), kron(N, blks...)
end

function eigenbasis(op::RepeatedBlock{N}) where N
    Ei, Vi = eigenbasis(content(op))
    Ei, repeat(N, Vi, op.locs)
end

function eigenbasis(op::XGate)
    [1.0, -1.0], H
end

function eigenbasis(op::YGate)
    [1.0, -1.0], H*ConstGate.Sdag
end

function measure!(
    postprocess::PostProcess,
    op::AbstractBlock,
    reg::AbstractRegister,
    locs::AllLocs;
    kwargs...,
) where {B}
    measure!(postprocess, eigen!(mat(op) |> Matrix), reg, locs; kwargs...)
end

function measure!(
    postprocess::PostProcess,
    op::Eigen,
    reg::AbstractRegister,
    locs::AllLocs;
    kwargs...,
)
    E, V = op
    reg.state = V' * reg.state
    res = measure!(postprocess, ComputationalBasis(), reg, locs; kwargs...)
    if postprocess isa NoPostProcess
        reg.state = V * reg.state
    end
    E[Int64.(res).+1]
end

function measure(op::AbstractBlock, reg::AbstractRegister, locs::AllLocs; kwargs...) where {B}
    E, V = eigenbasis(op)
    res = measure(ComputationalBasis(), copy(reg) |> V', locs; kwargs...)
    E[Int64.(res) .+ 1]
end

render_mlocs(alllocs::AllLocs, locs) = locs
render_mlocs(alllocs, locs) = alllocs[locs]

function _rot2eigenbasis(op, reg, mlocs)
    E, V = eigenbasis(op)
    top = map_address(V', AddressInfo(nactive(reg), mlocs))
    _reg = copy(reg) |> top
    E, top, _reg
end

function measure(op::PutBlock{N}, reg::AbstractRegister, locs; kwargs...) where N
    if nactive(reg) !== N
        throw(QubitMismatchError("operator of size $N does not match register size $(nactive(reg))"))
    end
    E, _op, _reg = _rot2eigenbasis(op, reg, locs)
    res = measure(ComputationalBasis(), _reg, _op.locs; kwargs...)
    map(ri->E[Int64(ri) + 1], res)
end

function measure(op::Scale, reg::AbstractRegister, locs; kwargs...)
    factor(op) .* measure(content(op), reg, locs; kwargs...)
end

function measure(op::CachedBlock, reg::AbstractRegister, locs; kwargs...)
    measure(content(op), reg, locs; kwargs...)
end

function measure(op::Daggered, reg::AbstractRegister, locs; kwargs...)
    conj(measure(content(op), reg, locs; kwargs...))
end

function measure(kb::KronBlock{N}, reg::AbstractRegister, locs; kwargs...) where N
    E, _op, _reg = _rot2eigenbasis(kb, reg, locs)
    res = measure(ComputationalBasis(), _reg, AllLocs(); kwargs...)
    map(res) do ri
        prod(i->E[i][Int(readbit(ri,_op.locs[i]...)) + 1], 1:length(_op.locs))
    end
end

function measure(rb::RepeatedBlock{N,C}, reg::AbstractRegister, locs; kwargs...) where {N,C}
    E, _op, _reg = _rot2eigenbasis(rb, reg, locs)
    res = measure(ComputationalBasis(), _reg, _op.locs; kwargs...)
    map(res) do ri
        prod(i->E[Int(readbit(ri,i)) + 1], 1:C)
    end
end

function measure(ab::Add, reg::AbstractRegister, locs; kwargs...)
    sum(subblocks(ab)) do op
        measure(op, reg, locs; kwargs...)
    end
end

for GT in [:RepeatedBlock, :PutBlock, :KronBlock,
    :Add, :Daggered, :CachedBlock, :Scale]
    @eval function measure(b::$GT, reg::AbstractRegister, locs::AllLocs; kwargs...)
        invoke(measure, Tuple{$GT, AbstractRegister, Any}, b, reg, locs; kwargs...)
    end
end
