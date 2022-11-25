using REPL
"""
`init_repl()`

Initiates the REPL so that every line will have `@mc` applied.
"""
function init_repl()
    function method_chains_first(ex)
        Internals.method_chains(ex)
    end

    #if isdefined(Main, :IJulia)
    #    Main.IJulia.push_preexecute_hook(_method_chains_first)
    #else

        pushfirst!(REPL.repl_ast_transforms, method_chains_first)
        # #664: once a REPL is started, it no longer interacts with REPL.repl_ast_transforms
        iter = 0
        # wait for active_repl_backend to exist
        ts=0:0.05:2
        for t ∈ ts
            sleep(step(ts))
            if isdefined(Base, :active_repl_backend)
                pushfirst!(Base.active_repl_backend.ast_transforms, method_chains_first)
                break
            end
        end
        isdefined(Base, :active_repl_backend) || 
            @warn("active_repl_backend not defined; interactive-mode MethodChains might not work.")
    #end
#        end
#        if isdefined(Main, :Atom)
#            Atom = getfield(Main, :Atom)
#            if Atom isa Module && isdefined(Atom, :handlers)
#                setup_atom(Atom)
#            end
#        end
#    end
    nothing
end
