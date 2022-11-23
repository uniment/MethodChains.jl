module MethodChains

export @mc, MethodChainLink
include("mc.jl")
include("methodchaintypes.jl")
include("repl_init.jl")

using .Internals

end
