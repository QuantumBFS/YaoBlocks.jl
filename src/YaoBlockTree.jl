module YaoBlockTree

include("utils.jl")
include("traits.jl")

include("abstract_block.jl")
include("block_map.jl")

include("routines.jl") # contains routines to generate matrices for quantum gates.
include("primitive/primitive.jl")
include("composite/composite.jl")

# concrete blocks
# include("symbolic/symbolic.jl")

# include("sequencial.jl")
include("measure.jl")
include("function.jl")
include("parse_block.jl")

# printings and tools to manipulate
# the tree.
include("layout.jl")
include("blocktree.jl")

include("deprecations.jl")

end # YaoBlockTree
