module MethodChains

export @mc, MethodChainLink, MethodMultiChainLink
include("mc.jl")
include("methodchaintypes.jl")
include("repl_init.jl")

using .Internals

end
