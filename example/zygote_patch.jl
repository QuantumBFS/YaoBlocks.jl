# mutate `block`
function run_circuit!(reg::AbstractRegister, block::AbstractBlock, params)
    apply!(copy(reg), dispatch!(block, params))
end

@adjoint function run_circuit!(reg::ArrayReg, block::AbstractBlock, params)
    out = run_circuit!(reg, block, params)
    out, function (outδ)
        (in, inδ), paramsδ = apply_back((out, outδ), block)
        return inδ, nothing, paramsδ
    end
end

@adjoint function ArrayReg{B}(raw::AbstractArray) where B
    ArrayReg{B}(raw), adjy->(reshape(adjy.state, size(raw)),)
end

@adjoint function ArrayReg{B}(raw::ArrayReg) where B
    ArrayReg{B}(raw), adjy->(adjy,)
end

@adjoint function ArrayReg(raw::AbstractArray)
    ArrayReg(raw), adjy->(reshape(adjy.state, size(raw)),)
end

@adjoint function copy(reg::ArrayReg) where B
    copy(reg), adjy->(adjy,)
end

@adjoint state(reg::ArrayReg) = state(reg), adjy->(ArrayReg(adjy),)
@adjoint statevec(reg::ArrayReg) = statevec(reg), adjy->(ArrayReg(adjy),)
@adjoint state(reg::AdjointArrayReg) = state(reg), adjy->(ArrayReg(adjy')',)
@adjoint statevec(reg::AdjointArrayReg) = statevec(reg), adjy->(ArrayReg(adjy')',)
@adjoint parent(reg::AdjointArrayReg) = parent(reg), adjy->(adjy',)
@adjoint Base.adjoint(reg::ArrayReg) = Base.adjoint(reg), adjy->(parent(adjy),)


