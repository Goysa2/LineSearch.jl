include("Armijo.jl")
include("Wolfe.jl")

include("ARC/ARC-Cub-LS.jl")
include("ARC/ARC-Nwt-LS.jl")
include("ARC/ARC-Sec-LS.jl")
include("ARC/ARC-SecA-LS.jl")

include("Bissection/trouve-intervalle-ls.jl")
include("Bissection/Biss-LS.jl")
include("Bissection/Biss-Cub-LS.jl")
include("Bissection/Biss-Nwt-LS.jl")
include("Bissection/Biss-Sec-LS.jl")
include("Bissection/Biss-SecA-LS.jl")

include("TR/TR-Cub-LS.jl")
include("TR/TR-Nwt-LS.jl")
include("TR/TR-Sec-LS.jl")
include("TR/TR-SecA-LS.jl")
include("TR/init-TR.jl")

include("zoom/trouve-intervalleA-ls.jl")
include("zoom/zoom-ls.jl")
include("zoom/zoom-Nwt-ls.jl")
include("zoom/zoom-Cub-ls.jl")
include("zoom/zoom-Sec-ls.jl")
include("zoom/zoom-SecA-ls.jl")
