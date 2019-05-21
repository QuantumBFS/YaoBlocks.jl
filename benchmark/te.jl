using Revise, Yao, BenchmarkTools, ExponentialUtilities, YaoBlocks.Optimise

function heisenberg(n::Int; periodic::Bool=true)
    Sx(i) = put(n, i=>X)
    Sy(i) = put(n, i=>Y)
    Sz(i) = put(n, i=>Z)

    return sum(1:(periodic ? n : n-1)) do i
        j = mod1(i+1, n)
        Sx(i) * Sx(j) + Sy(i) * Sy(j) + Sz(i) * Sz(j)
    end
end

te = TimeEvolution(cache(heisenberg(10)), 0.2; check_hermicity=true)
r = rand_state(10)
@benchmark apply!($r, $te)

Ham = mat(heisenberg(10));
r = rand_state(10)

@benchmark expv(0.2, $te.H, $(statevec(r)))

@benchmark apply!($r, $(simplify(heisenberg(10))))
@benchmark $Ham * $(statevec(r))

mat(heisenberg(10))


hh = cache(simplify(heisenberg(10)));
typeof(hh)
@allocated mat(hh)

@benchmark apply!(rand_state(10), $hh)
@benchmark apply!(rand_state(10), $(simplify(heisenberg(10))))
