macro yao_str(str::String)
    yaofromstring(str)
end

function yaofromstring(x::String)
    ex = Meta.parse(x)
    @match ex begin
        :(begin $line; nqubits=$n; $(body...) end) => parse_ex(:(begin $(body...) end), n)
        _ => error("wrong format, expect expression like `begin nqubits=5 ... end`, got $ex")
    end
end

yaofromfile(x::String) = yaofromstring(read(x, String))
parse_ex(ex, nbit::Int) = parse_ex(ex, ParseInfo(nbit, ""))

mutable struct ParseInfo
    nbit::Int
    version::String
end

function gate_expr end

function parse_ex(ex, info::ParseInfo)
    @match ex begin
        :(version = $vnumber) => (info.version = String(vnumber); nothing)
        :(nqubits = $x) => (info.nbit = Int(x); nothing)
        ::Nothing => nothing
        :($g') => :($(parse_ex(g, info))')
        :($a*$b) => :($(Number(a))*$(parse_ex(b, info)))
        :(rot($g, $theta)) => :(rot($(parse_ex(g, info)), $(Number(theta))))
        :(shift($theta)) => :(shift($(Number(theta))))
        :(phase($theta)) => :(phase($(Number(theta))))
        :(kron($(args...))) => :(kron($(parse_ex.(args, Ref(ParseInfo(1, info.version)))...)))
        :(repeat($(exloc...))=>$g) => begin
            loc = render_loc((exloc...,), info.nbit)
            :(repeat($(info.nbit), $(parse_ex(g, ParseInfo(1, info.version))),$loc))
        end
        :($exloc => Measure) => parse_ex(:($exloc=>Measure(nothing) => nothing), info)
        :($exloc => Measure($op)) => parse_ex(:($exloc => Measure($op) => nothing), info)
        :($exloc => Measure => $collapseto) => parse_ex(:($exloc => Measure($op) => $collapseto), info)
        :($exloc => Measure($op) => $collapseto) => begin
            locs = exloc == :ALL ? :(AllLocs()) : render_loc(exloc, info.nbit)
            cb = collapseto === nothing || collapseto == :nothing ? nothing : bit_literal(render_bitstring(collapseto))
            op = op isa Nothing || op == :nothing ? :(ComputationalBasis()) : parse_ex(op, info)
            :(Measure($(info.nbit); locs=$locs, operator=$(op), collapseto=$cb))
        end
        :(time($dt) => $h) => :(time_evolve($(parse_ex(h, info)), $(Number(dt))))
        :(+($(args...))) => :(+($(args...)))
        :(focus($(exloc...)) => $g) => begin
            loc = render_loc((exloc...,), info.nbit)
            :(concentrate($(info.nbit), $(parse_ex(g, ParseInfo(length(loc), info.version))),$loc))
        end
        :(begin $(cargs...) end) => begin
            args = filter(x->x!==nothing, [parse_ex(arg, info) for arg in cargs])
            :(chain($(info.nbit), [$(args...)]))
        end
        :($exloc => $gate) => begin
            loc = render_loc(exloc, info.nbit)
            :(put($(info.nbit), $loc=>$(parse_ex(gate, ParseInfo(length(loc), info.version)))))
        end
        :($(cargs...), $exloc => $gate) => begin
            loc = render_loc(exloc, info.nbit)
            cbits = render_cloc.(cargs)
            :(control($(info.nbit), $cbits, $loc=>$(parse_ex(gate, ParseInfo(length(loc), info.version)))))
        end
        :($f($(args...))) => gate_expr(Val(f), args, info)

        ::LineNumberNode => nothing
        ::Symbol => ex  # const gate
        _ => error("scipt format error! got $ex of type $(typeof(ex))")
    end
end

function check_dumpload(gate::AbstractBlock{N}) where N
    gate2 = eval(parse_ex(dump_gate(gate), N))
    gate2 == gate || mat(gate2) ≈ mat(gate)
end

render_bitstring(ex) = @match ex begin
    ::Number => begin
        if ex == 1 || ex == 0
            ex
        else
            error("expect a bitstring like `1` or `(1,0)`, got $ex")
        end
    end
    ::Tuple => render_bitstring.(ex)
    _ => error("expect a bitstring like `1` or `(1,0)`, got $ex")
end

render_loc(ex, nbit::Int) = @match ex begin
    :($(args...),) => (render_loc.(args, nbit)...,)
    ::Number => Int(ex)
    :($a:$b) => Int(a):Int(b)
    :ALL => (1:nbit...,)
    :($a:$step:$b) => Int(a):Int(step):Int(b)
    ::Tuple => Int.(ex)
    _ => error("expect a location specification like `2`, `2:5` or `(2,3)`, got $ex")
end

render_cloc(ex) = @match ex begin
    ::Number => ex
    ::Pair{Int,Int} => begin
        config = ex.second
        @assert config == 1 || config == 0
        ex.first * (2*config-1)
    end
    :($a=>$b) => begin
        if a isa Number && b isa Number
            render_cloc(a=>b)
        else
            error("expect a control location specification like `2=>0` or `3[=>1]`, got $ex")
        end
    end
    _ => error("expect a control location specification like `2=>0` or `3=>1`, got $ex")
end
