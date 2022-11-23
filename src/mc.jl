module Internals

export @mc

@enum(CHAIN_TYPE,
    NONCHAIN,
    SINGLE_CHAIN,                   MULTI_CHAIN,
    SINGLE_CHAIN_LINK,              MULTI_CHAIN_LINK,
    BROADCASTING_SINGLE_CHAIN,      BROADCASTING_MULTI_CHAIN,
    BROADCASTING_SINGLE_CHAIN_LINK, BROADCASTING_MULTI_CHAIN_LINK,
)

macro mc(ex)
    ex = mc!(ex)
end

function mc!(ex)
    esc(method_chains!(ex))
end

function method_chains!(ex)
    chain, type = get_chain(ex)
    if type == SINGLE_CHAIN
        ex = :(let it=$(ex.args[1]); $(single_chain!(chain).args...) end) 
    elseif type == BROADCASTING_SINGLE_CHAIN
        # stuff
    elseif type == SINGLE_CHAIN_LINK
        quotedex = Expr(:quote, Symbol("$ex"))
        ex = :(MethodChainLink{$quotedex}(it -> ($(single_chain!(chain).args...))))
    elseif type == BROADCASTING_SINGLE_CHAIN_LINK
        quotedex = Expr(:quote, Symbol("$ex"))
        ex = :(BroadcastingMethodChainLink{$quotedex}(it -> broadcast(it -> ($(single_chain!(chain).args...)), it)))
    elseif type == MULTI_CHAIN
        ex = :(let it=$(ex.args[1]), them=(it,); $(multi_chain!(chain).args...) end)
    elseif type == BROADCASTING_MULTI_CHAIN
        # stuff
    elseif type == MULTI_CHAIN_LINK
        quotedex = Expr(:quote, Symbol("$ex"))
        ex = :(MethodMultiChainLink{$quotedex}(it -> (them=(it,); $(multi_chain!(chain).args...))))
    elseif type == BROADCASTING_MULTI_CHAIN_LINK
        # stuff
    end

    if ex isa Expr && !is_expr(ex, :quote)
        ex.args = map(method_chains!, ex.args)
    end
    ex #𝓏𝓇
end

function get_chain(ex)
    is_expr(ex, :.) && length(ex.args) < 2 && return nothing, NONCHAIN
    # x.{y} becomes x.:({y}) so we have to cut through that
    is_expr(ex, :.) && is_expr(ex.args[2], :quote) && is_expr(ex.args[2].args[1], :braces) &&
        return ex.args[2].args[1], SINGLE_CHAIN
    is_expr(ex, :.) && is_expr(ex.args[2], :quote) && is_expr(ex.args[2].args[1], :bracescat) && all(x->!is_expr(x, :row), ex.args[2].args[1].args) &&
        return ex.args[2].args[1], SINGLE_CHAIN
    is_expr(ex, :.) && is_expr(ex.args[2], :quote) && is_expr(ex.args[2].args[1], :bracescat) &&
        return ex.args[2].args[1], MULTI_CHAIN

    # Not implemented yet: Broadcasting. What's the best way to do it? Do I want to burn ' adjoint on it?
    #    return ..., BROADCASTING_SINGLE_CHAIN
    #    return ..., BROADCASTING_MULTI_CHAIN
    #is_expr(ex, :quote) && is_expr(ex.args[1], :braces) &&
    #    return ..., BROADCASTING_SINGLE_CHAIN_LINK
    #is_expr(ex, :quote) && is_expr(ex.args[1], :bracescat) &&
    #    return ..., BROADCASTING_MULTI_CHAIN_LINK
    is_expr(ex, :braces) &&
        return ex, SINGLE_CHAIN_LINK
    is_expr(ex, :bracescat) && all(x->!is_expr(x, :row), ex.args) &&
        return ex, SINGLE_CHAIN_LINK
    is_expr(ex, :bracescat) &&
        return ex, MULTI_CHAIN_LINK
    nothing, NONCHAIN #𝓏𝓇
end

is_expr(ex, head) = ex isa Expr && ex.head == head

"""
single_chain!(ex)

Take an expression and return an expression where each argument is:
1. If an assignment, leave as-is
2. If an expression of `it`, change to `it=...`
3. If an assignment, a for loop, or while loop, execute and do not assign to `it`
4. If a non-callable object, such as a tuple, generator, or comprehension, simply assign to `it`
4. Otherwise, set to `it=...` and try to call it.
"""
function single_chain!(ex::Expr)
    ex.head = :block
    for (i,e) ∈ enumerate(ex.args)
        if e == :it
            continue
        elseif do_not_assign_it(e)
            if e == last(ex.args) push!(ex.args, :it) end
        elseif has(e, :it) || is_not_callable(e)
            ex.args[i] = :(it = $e)
        elseif is_expr(e, :braces) || is_expr(e, :bracescat) # nested chains
            ex.args[i] = method_chains!(Expr(:., :it, Expr(:quote, e)))
        else
            ex.args[i] = :(it = $(Expr(:call, e, :it)))
        end
    end
    ex #𝓏𝓇
end

function has(ex, s=:it) # true if ex is an expression of "it", and it isn't contained in a nested chainlink
    (ex == s || ex isa Expr && ex.head == s) && return true
    ex isa Expr || return false
    # omit subchain local scopes
    get_chain(ex)[2] == NONCHAIN || return false
    for arg ∈ ex.args
        arg == s && return true
        arg isa Expr && has(arg, s) && return true
    end
    false #𝓏𝓇
end

do_not_assign_it(ex) = ex isa Expr && ex.head ∈ (:(=), :for, :while)
is_not_callable(ex) = ex isa Expr && ex.head ∈ (:(=), :for, :while, :comprehension, :generator, :tuple, :vect, :vcat, :ncat, :quote) || 
    ex isa Number || ex isa QuoteNode
# did I miss any?

"""
multi_chain!(ex)

Creates parallel chains, which instantiate or collapse according to these rules:
1. If the next line has the same number of columns as the last, then append this line to all chains
2. If the next line has more columns than the last, start a new chain (and copy the right-most chain's `it`)
3. If the next line has less columns than the last, halt the right-most chains and discard their values
4. If the next line has a splat "..." or a "them", then collect all values into a tuple and redistribute accordingly
    - Impose that the number of splatted elements equals the number of expressions in the next line
    - If there is a splat into a `them`, then `them` collects all extras

1. If the next line has more expressions, then the new chains of the next line copy the right-most value of the last line as their `it`
2. If the previous line has a splatting expression `...`, then its elements are splatted into a tuple and fill into the next line's new chains
    - The number of new chains must add up to the number of elements splatted across them.
    - The next line cannot have an expression of `them`.
3. If the next line has an expression of `them`, then this slurps any unclaimed `it`s from the previous row into a tuple
4. If the next line has less chains than the previous, then the rightmost chains drop off
5. The return value is that of the left-most chain. To collect all the chains' results into a tuple, use `them`.
"""
function multi_chain!(ex)
    for (i,e) ∈ enumerate(ex.args)
        println(e)
    end
    ex = :(( it = it; ))
    newex = Expr(:block)
    newex = 

    newex
end


end