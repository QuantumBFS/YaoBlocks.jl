using Zygote
using Zygote: @adjoint
using Yao, YaoBlocks.AD

include("zygote_patch.jl")

import YaoExtensions, Random

c = YaoExtensions.variational_circuit(5)
reg = zero_state(5)
params = rand(Float64, nparameters(c))*2π

function loss(params)
    out = run_circuit!(reg, c, params)
    st = state(out)
    sum(real(st.*st))
end
loss'(params)

function loss2(reg)
    out = run_circuit!(reg, c, params)
    st = state(out)
    sum(real(st.*st))
end
loss2'(reg)
