export projector, print_blocktree
using InteractiveUtils

"""
    projector(x)

Return projector on `0` or projector on `1`.
"""
projector(x) = code==0 ? mat(P0) : mat(P1)

function print_subtypetree(t, level=1, indent=4)
    level == 1 && println(t)
    for s in subtypes(t)
        println(join(fill(" ", level * indent)) * string(s))
        print_subtypetree(s, level+1, indent)
    end
end

print_blocktree() = print_subtypetree(AbstractBlock)
