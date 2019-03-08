export FunctionBlock

"""
    FunctionBlock <: AbstractBlock

This block contains a general function that perform an in-place operation over a register
"""
struct FunctionBlock{Call <: Base.Callable} <: AbstractBlock{UnkownSize, Any}
    call!::Call
end

apply!(r::AbstractRegister, f::FunctionBlock) = f.call!(r)

MatrixTrait(::FunctionBlock) = MatrixUnkown()
const InvOrders = FunctionBlock(invorder!)
const CollapseTo = FunctionBlock(setto!)
