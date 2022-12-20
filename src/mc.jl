module Internals

export @mc

@enum(CHAIN_TYPE,
    NONCHAIN,
    SINGLE_CHAIN,                   MULTI_CHAIN,
    SINGLE_CHAIN_LINK,              MULTI_CHAIN_LINK,
    BROADCASTING_SINGLE_CHAIN,      BROADCASTING_MULTI_CHAIN,
    BROADCASTING_SINGLE_CHAIN_LINK, BROADCASTING_MULTI_CHAIN_LINK,
)

# these are the local keywords
const it=:it                # pronoun for single chains
const them=:them            # pronoun for collecting chains
const it_synonym=:⬚         # unicode synonym
const them_synonym=:⬚s      # unicode synonym
const loop_name=:loop       # self-referential chain name for recursion

macro mc(ex)
    ex = mc(ex)
end

function mc(ex)
    esc(method_chains(just_do_it!(ex)))
end

function just_do_it!(ex) # revise do-blocks to use `{}` in an ok way
    if is_expr(ex, :do) && is_expr(ex.args[2].args[1].args[1], (:braces, :bracescat))
        f = popfirst!(ex.args[1].args)
        pushfirst!(ex.args[1].args, ex.args[2].args[1].args[1])
        pushfirst!(ex.args[1].args, f)
        ex.head = :call
        ex.args = ex.args[1].args
    end
    ex isa Expr && map(just_do_it!, ex.args)
    ex
end

function method_chains(ex)
    chain, type = get_chain(ex)        

    help_recursion = :(local $loop_name = var"#self#") # as long as Julia's named function syntax doesn't behave reasonably in local scopes

    type ≠ NONCHAIN && replace_synonyms!(ex) && help_captures!(ex, it) && help_captures!(ex, them)
    type ∈ (SINGLE_CHAIN, SINGLE_CHAIN_LINK) && any(Base.Fix2(has, them), chain) && throw("Syntax error: use of `them` in single chains unsupported.")

    if type == SINGLE_CHAIN
        ex = :(let $it=$(ex.args[1]); $(single_chain(chain)...); end)  |> clean_blocks
    elseif type == SINGLE_CHAIN_LINK
        chain_name = gensym(:chainlink)
        ch = single_chain(chain)
        ex = :($chain_name($(ch[1])) = ($help_recursion; $(ch[2:end]...);)) |> clean_blocks
    elseif type == MULTI_CHAIN
        ex = :(let $it=$(ex.args[1]), $them=($it,); $(multi_chain(chain)...); end) |> clean_blocks
    elseif type == MULTI_CHAIN_LINK
        chain_name = gensym(:chainlink)
        ch = multi_chain(chain)
        ex = :($chain_name($(ch[1])) = ($help_recursion; local $them = ($it,); $(ch[2:end]...);)) |> clean_blocks
    elseif type == BROADCASTING_SINGLE_CHAIN
        # stuff
    elseif type == BROADCASTING_SINGLE_CHAIN_LINK # vestigial; leaving as an artifact for when this is uncovered two thousand years from now
        quotedex = Expr(:quote, Symbol("$ex"))
        ex = :(it -> broadcast(it -> ($(single_chain(chain)...)), it)) |> clean_blocks
        ex = :(BroadcastingMethodChainLink{$quotedex}($ex))
    elseif type == BROADCASTING_MULTI_CHAIN
        # stuff
    elseif type == BROADCASTING_MULTI_CHAIN_LINK
        # stuff
    end

    if ex isa Expr && !is_expr(ex, :quote)
        ex.args = map(method_chains, ex.args)
    end

    ex #𝓏𝓇
end

help_captures!(ex, pronoun=it) = begin # give functions that capture `it` an instantaneous snapshot of `it` by wrapping in a let it=it...end block
    ex isa Expr && map(Base.Fix2(help_captures!, pronoun), ex.args)
    if (is_expr(ex, (:->, :function)) || is_expr(ex, :(=)) && is_expr(ex.args[1], :call)) && has(ex.args[2], pronoun) && !has(ex.args[1], pronoun)
        newex = Expr(ex.head, ex.args...)
        ex.head = :let
        ex.args = Any[Expr(:(=), pronoun, pronoun), newex]
    end
    true
end

replace_synonyms!(ex) = begin # 
    if ex isa Expr
        map(replace_synonyms!, ex.args)
        for (i,v) ∈ enumerate(ex.args)
            if v == it_synonym  ex.args[i] = it
            elseif v == them_synonym  ex.args[i] = them
            end
        end
    end
    true
end

function clean_blocks(ex)
    if is_expr(ex, :(=)) || is_expr(ex, :let)
        ex.args[2].args = filter(x->!(x isa LineNumberNode), ex.args[2].args)
    end
    ex
end

"""
`get_chain(ex)`

Returns what type of a chain `ex` is, and an expression whose arguments are the expressions the chain will be constructed from. 

The return value is a tuple `(chainex::Expr, type::CHAIN_TYPE)`.
"""
function get_chain(ex)
    is_expr(ex, :.) && length(ex.args) < 2 && return nothing, NONCHAIN
    # x.{y} becomes x.:({y}) so we have to cut through that
    is_expr(ex, :.) && is_expr(ex.args[2], :quote) && is_expr(ex.args[2].args[1], :braces) &&
        return ex.args[2].args[1].args, SINGLE_CHAIN
    is_expr(ex, :.) && is_expr(ex.args[2], :quote) && is_expr(ex.args[2].args[1], :bracescat) &&
        return ex.args[2].args[1].args, MULTI_CHAIN
    is_expr(ex, :braces) &&
        return ex.args, SINGLE_CHAIN_LINK
    is_expr(ex, :bracescat) && 
        return ex.args, MULTI_CHAIN_LINK
    # Not implemented yet: Broadcasting. What's the best way to do it? Do I want to burn ' adjoint on it?
    #    return ..., BROADCASTING_SINGLE_CHAIN
    #    return ..., BROADCASTING_MULTI_CHAIN
    #    return ..., BROADCASTING_SINGLE_CHAIN_LINK
    #    return ..., BROADCASTING_MULTI_CHAIN_LINK

    nothing, NONCHAIN #𝓏𝓇
end

is_expr(ex) = ex isa Expr
is_expr(ex, head) = ex isa Expr && ex.head == head
is_expr(ex, heads::Tuple) = ex isa Expr && ex.head ∈ heads

"""
`single_chain(ex)``

Take an expression whose arguments a chain will be constructed from, and return an expression where each argument is:
1. If `:it` or `:_`, leave out
2. If an assignment, leave as-is
3. If an expression of `it` (and not in a nested chain), change to `it=...`
4. If an assignment, a for loop, or while loop, execute and do not assign to `it`
5. If a non-callable object, such as a tuple, generator, or comprehension, simply assign to `it`
6. Otherwise, try to call it and assign to `it=`.
"""
function single_chain(exarr::Vector, (is_nested_in_multichain, pronoun) = (false, it))
    out = []
    !is_nested_in_multichain && setuparg!(exarr, out)

    for e ∈ exarr
        if is_expr(e, :local) && is_expr(e.args[1], :(=))
            throw("Cannot add `local` keyword to `$(e.args[1])`; all variable declarations are local to chain anyway.")
        end
        if e == pronoun || e == :_
            continue
        elseif is_expr(e, :(::)) && length(e.args) == 1 # type assertions
            push!(out, :(it = it::$(first(e.args))))
        elseif do_not_assign_it(e)
            if is_expr(e, :(=)) && e.args[1] ≠ pronoun  e = Expr(:local, e)  end # BEGONE, SIDE EFFECTS!
            push!(out, e)
            if e == last(exarr) push!(out, pronoun) end
        elseif has(e, it) || do_not_call(e) || is_nested_in_multichain && has(e, them)
            push!(out, :($pronoun = $e))
#       This code (inlines nested chainlinks instead of generating anon functions) is broken for recursive chainlinks, so let's leave it out for now
#        elseif (is_expr(e, :braces) || is_expr(e, :bracescat)) && !any(has(sube, chain_link_name) for sube ∈ e.args) # nested, non-recursive chains
#            push!(out, :($it = $(method_chains(Expr(:., pronoun, Expr(:quote, e))))))
        else
            push!(out, :($it = $(Expr(:call, e, pronoun))))
        end
    end
    push!(out, pronoun)
    out #𝓏𝓇
end

function setuparg!(exarr, out) # setup argument (esp. for chainlinks) w/ optional type assertion
    if length(exarr)==0 || !is_expr(exarr[1], :(::))
        pushfirst!(out, it)
    else
        pushfirst!(out, :($it::$(popfirst!(exarr).args[1])))
    end
end

function has(ex, pronoun=it) # true if ex is an expression of "it", and it isn't contained in a nested chainlink
    (ex == pronoun || ex isa Expr && ex.head == pronoun) && return true
    ex isa Expr || return false
    # omit sub-chainlink local scopes
    get_chain(ex)[2] ∈ (NONCHAIN, SINGLE_CHAIN, MULTI_CHAIN, BROADCASTING_MULTI_CHAIN, BROADCASTING_SINGLE_CHAIN) || return false
    for arg ∈ ex.args
        arg == pronoun && return true
        arg isa Expr && has(arg, pronoun) && return true
    end
    false #𝓏𝓇
end

do_not_assign_it(ex) = ex isa Expr && (ex.head ∈ (:(=), :for, :while)  )#|| ex.head == :tuple && is_expr(last(ex.args), :(=))) # this is for a,b=it; doesn't work, must parenthesize (a,b) anyway 
is_not_callable(ex) = ex isa Expr && ex.head ∈ (:for, :while, :comprehension, :generator, :tuple, :vect, :vcat, :ncat, :quote, :macrocall) || 
    !(ex isa Expr) && !(ex isa Symbol) 
do_not_call(ex) = is_not_callable(ex) || is_expr(ex, :(=)) || (ex isa Expr && ex.head == :(::) && is_not_callable(ex.args[1]))

"""
`multi_chain(ex)`

Creates parallel chains, which instantiate, collapse, and interact according to these rules:
1. The first chain is a background chain. 

1. If the next line has the same number of columns as the last, with no `them` slurps and no `...` splats, then append this line to all existing chains
2. Collect all values from all chains into a tuple to take inventory, and then redistribute accordingly if:
    a. the next line has more or less chains than the last, or
    b. the previous line has at least one splat `...`, or
    c. the next line has a `them`.
    - Impose that the number of splatted elements equals or is greater to the number of expressions in the next line
    - There can be multiple splats per line, but only one `them`.
    - If the previous line had a splat and the next line has a `them`, then `them` takes up all the slack and collects all extras
    - An expression `them...` both slurps and splats.
4. If the next line has more columns than the last, start a new chain
    - if there was no splat, copy the right-most chain's `it`
5. If the next line has less columns than the last, terminate chains
    - if the next line has no `them`, then discard the values of the right-most chains
    - if the next line has `them`, then any unclaimed chains are slurped into it

"""
function multi_chain(exarr) # let's give this another try
    out = []
    setuparg!(exarr, out)

    exarr = [is_expr(r, :row) ? r : Expr(:row, r) for r ∈ exarr if !(r isa LineNumberNode)]
    pushfirst!(exarr, Expr(:row, it)) # initialize background chain with dummy
    push!(exarr, Expr(:row, it)) # initialize background chain with dummy

    # helper fcns
    row_width(row) = length(row.args)
    does_splat(row) = any(Base.Fix2(is_expr, :...), row.args)
    does_slurp(row) = has(row, them)
    do_synchronize(oldrow, newrow) = row_width(oldrow) ≠ row_width(newrow) || does_splat(oldrow) || has(newrow, them)

    wrap_chains(chains::Vector{<:Vector}) = begin
        local out
        # save splat locations and strip out, to add back later
        splatting_chains = [is_expr(c[end], :...) for c ∈ chains]
        for c ∈ chains  c[end] = is_expr(c[end], :...) ? c[end].args[1] : c[end]  end
        # wrap old chain(s)  (`:block` for background chain, `:let` for multi-chains), and assign to `them` collection
        if length(chains) == 1
            out = [Expr(:block, single_chain(chains[1], (true, it))...)]
            if splatting_chains[1]  out = [Expr(:..., out[1])]  end
        else
            out = [Expr(:let, Expr(:(=), it, c[begin]), Expr(:block, single_chain(c[2:end], (true, it))...)) for c ∈ chains]
            out = [sp ? Expr(:..., c) : c for (c, sp) ∈ zip(out, splatting_chains)]
        end
        out
    end

    # here's the meat
    chains = [Any[it]] # stores parallel chains; initialize with background chain
    for (oldrow, newrow) ∈ zip(exarr, exarr[2:end])
        if !do_synchronize(oldrow, newrow) # base case: continue previous chain(s)
            for (chain, col_ex) ∈ zip(chains, newrow.args)
                push!(chain, col_ex)
            end
            continue
        end
        push!(out, :($them = ($(wrap_chains(chains)...),)))
        # start new chain(s), but first, compute the indices of `them` each chain should take
        indices = [clamp(i, 1:(does_splat(oldrow) ? typemax(Int) : length(oldrow.args))) for i = 1:length(newrow.args)]
        chains = [Any[:($them[$i]); e] for (i,e) ∈ zip(indices, newrow.args)]
    end
    push!(out, :($them = ($(wrap_chains(chains)...),)))
    push!(out, it)
    out #𝓏𝓇
end
# need to add back: if there is no `them` present to collect, the background chain needs to take on a default value.



end