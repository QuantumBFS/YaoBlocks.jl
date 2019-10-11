include("address_manipulate.jl")
# include("optimise.jl")
include("match.jl")
include("simplify.jl")

print_blocktree() = print_subtypetree(AbstractBlock)
