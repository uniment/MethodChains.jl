# *MethodChains.jl*

## Welcome!

This is an ambitious (and somewhat experimental, and fun!) approach to generalize method chaining and function composition.

To install:
```julia
] add https://github.com/uniment/MethodChains.jl
```
and
```
using MethodChains
```

You will now have the `@mc` method chaining macro installed. You can invoke this macro on a single expression:

```julia
y = @mc x.{f, g}
```

or you can invoke it on an entire block of expressions:

```julia
@mc begin
    y = x.{f, g}
    z = y.{h}
end
```

To make it execute on every line in the REPL, execute this:
```julia
MethodChains.init_repl()
```

Then, you won't have to worry about typing `@mc` every time. 🤩

Definitely do not add this to your Julia startup.jl file if you don't like having fun:

```julia
using MethodChains
MethodChains.init_repl()
```

# *Basic Use*

The basic idea of a method chain is simple:

For an object `x`, you can call a sequence of functions `f, g, h` on it like so:
```julia
y = x.{f, g, h}
```

This is equivalent to:
```julia
y = h(g(f(x)))
```

or this:
```julia
y = x.{f}.{g}.{h}
```

(why you'd do that I don't know, but that's none of my beeswax!)

Example:
```julia
julia> randn(100).{maximum, sqrt}
1.4735877523876308
```

You can also make a method chain and call it later, instead of immediately executing it:
```julia
m = {f, g, h}
y = x.{m}
# or
y = m(x)
```

You can also construct one and immediately call it, but that's not really necessary:
```julia
y = {f, g, h}(x)
```

Now, unless every function is a Clojure-style transducer, chances are that your functions won't compose perfectly like this. This situation happens in real life too—and to handle this, in the English language we reserve the pronoun "it," to give the object a local and temporary name to allow short (but flexible) manipulations spliced between larger functions. So, `MethodChains` also uses `it`.

```julia
julia> x = 2;

julia> f(x) = x^2;

julia> g(x) = x+1;

julia> x.{f, √(it - 1), g}
2.732050807568877
```

To better understand what's going on, you can run `@macroexpand`:
```julia
julia> @macroexpand @mc x.{f, √(it - 1), g}
:(let it = x
      it = f(it)
      it = √(it - 1)
      it = g(it)
  end)
```

Or, when constructing a chain that's not immediately called, a lambda is created:
```julia
julia> @macroexpand @mc {f, √(it - 1), g}
:(MethodChainLink{Symbol("{f, √(it - 1), g}")}((it->begin
              it = f(it)
              it = √(it - 1)
              it = g(it)
          end)))
```

Pretty simple, neh? `it` is a keyword *defined only locally inside the chain*, and on every step it takes on a new value. If an expression has `it` in it, then it's simply executed and the result overwrites `it`; otherwise it's assumed that it's a function, which is called on `it`.

Couple more examples:
```julia
julia> (1,2,5).{(first(it):last(it)...,)}
(1, 2, 3, 4, 5)

julia> (1,2,3).{it.^2, sum, sqrt}
3.7416573867739413

julia> "1,2,3".{split(it,","), parse.(Int, it), it.^2, join(it, ",")}
"1,4,9"
```

Now, the rule for whether to *call* the expression, or leave it intact, or assign `it` to it, is actually a bit more complicated (but reasonably natural). Check this out:

```julia
julia> avg = {len=length(it), sum(it)/len}
{len = length(it), sum(it) / len}

julia> (1,2,3).{avg}
2.0

julia> stdev = {μ = it.{avg}, it .- μ, it.^2, avg, sqrt};

julia> (1,2,3).{stdev}
0.816496580927726

julia> Dict(:a=>1, :b=>2, :c=>3).{for k ∈ keys(it) it[k]=it[k]^2 end}
Dict{Symbol, Int64} with 3 entries:
  :a => 1
  :b => 4
  :c => 9
```

Namely:

* If an expression is an assignment, leave it intact and do not assign `it` to it. This allows local variables to be assigned.
* If an expression type returns nothing, such as a `for` loop, then it is executed but its result is not assigned to `it`.
* If an expression is known not to be a callable type, such as a comprehension, generator, tuple, or vector, then it is not called and is simply assigned to `it`.
* If an expression is an expression of `it`, then it is simply executed and assigned to `it`.
* Otherwise, it's assumed that the expression is callable, and so it should be called. This is the default behavior.

If it's desired to override the default behavior of method calling, you can make an explicit assignment to `it`.

## Examples

*Example from Chain.jl Readme*

```julia
df.{
    dropmissing
    filter(:id => >(6), it)
    groupby(it, :group)
    _ = println(it) # show intermediate value, discard return value
    combine(it, :age => sum)
}
```

*Example from DataPipes.jl Readme*

```julia
julia> "a=1 b=2 c=3".{
           split,
           map({
               split(it, "=")
               (Symbol(it[1]) => parse(Int, it[2]))
           }, it)
           NamedTuple
       }
(a = 1, b = 2, c = 3)
```

*Examples from Pipe.jl Readme*

```julia
a.{b(it...)}
a.{b(it(1,2))}
a.{b(it[3])}
(2,4).{get_angle(it...)}
```

*My Examples*
```julia
[1,2,3].{map({it^2}, it)}
[1,2,3].{join(it, ", ")}
"1".{parse(Int, it)} == 1
(:a,:b).{reverse}
```


*Operator Precedence*
```julia
julia> (1, 2).{(a=it[1], b=it[2])}.b
2
```

*Chaining*

```julia
julia> [1,2,3].{
           filter(isodd, it),
           map({it^2}, it),
           sum,
           sqrt
       }
3.1622776601683795
```

*More*

```julia
julia> "1 2, 3; hehe4".{
           eachmatch(r"(\d+)", it)
           map({first, parse(Int, it)}, it)
           join(it, ", ")
       }
"1, 2, 3, 4"
```

(Do I want to use the adjoint operator to denote chains that will be broadcasted?)

*Saving a Chain*

```julia
julia> chain = {split(it, r",\s*"), {parse(Int, it)^2}.(it), join(it, ", ")};

julia> "1, 2, 3, 4".{chain}
"1, 4, 9, 16"
```

*Transducer Chain*

```julia
process_bags = {
    mapcatting(unbundle_pallet)
    filtering(is_nonfood)
    mapping(label_heavy)
}
process_bags.{into(airplane, it, pallets)}
```

# *Advanced Use*

That was fun! This chaining syntax allows for really basic composition, like `x.{f, g, h}`, but also some more advanced stuff too like `x.{i for i ∈ 1:it}`. Why would you use this instead of a function? Because on every line you're presumed *most likely* to call a function on or otherwise manipulate the object `it`, this default behavior frequently enables very short expressions. It also hints to the IDE autocomplete what type of object you're likely about to call a function on, as well as providing a natural "flow" of thought as the object passes through a sequence of transformations. Finally, calling the chain immediately (e.g. `x.{exprs}`) doesn't allocate a function, keeping compile time minimized, while still being a shorthand for creating locally-scoped variables.

But there's even more to it. (This is the most experimental feature of this syntax, so please experiment with it and offer feedback!)

## 2-dimensional chains


So far we've discussed one-dimensional chains, wherein a single object undergoes a sequence of transformations in time. However, we can also express two-dimensional chains, wherein multiple objects spread across space undergo their own transformation chains, and occasionally interact, through time. 

Take this for example:

```julia
(1, 2, 3).{
    it...
    f       g       h
    g       h       f
    h       f       g
    it+3    it*2    it+1    
    them
}
```
The result of this chain is equivalent to `(h(g(f(1)))+3, f(h(g(2)))*2, g(f(h(3)))+1)`. Notice that the expression represents three chains; the three input elements have been splatted across the top row, and the values waterfall down to the bottom where they are collected into a tuple. The pronoun `it` is, again, local to each chain, and the pronoun `them` slurps up all unclaimed adjacent `it`s into a tuple.

```julia
(1+1im).{
    real        imag
    it^2        it^2
    Complex(them...)
}
```

Here, the input was not splatted across the top row. When the next row has more elements than the last, and the last did not splat, then the last element of the row above is copied in. Notice that after the chains, the two chains came together and interacted.

It is presumed that each line will have the same number of expressions as the one above it. But if it doesn't, or if there is any splat on the previous line, or if there's any expression of `them` on the next line, then all the individual chains terminate, their values are collected into `them`, and new chains commence.

Values can also be discarded, which causes their respective chains to end with them:

```julia
(a, b, c).{
    it...
    it      it      it
    it
    them
}
```

In this case, the return value is a simple tuple `(a,)`. Values drop off the right side.

Values can also be duplicated, starting new chains:
```julia
(1).{
    it                      # 1
    it      it+1            # 1,2
    it      it      it+1    # 1,2,3
    them.+1...              # 2,3,4
    it      them.+1...      # 2,3,4,5
    them                    # collect at end
}
```
In this case, the return value is `(2, 3, 4, 5)`.

New chains can also be instantiated with an assignment to `it`. Previous values can also be splatted across new rows:

```julia
(1,2).{
    it...
    it      (it, it+1)...
    it      it              it
    them
}
```

The return value here is `(1, 2, 3)`.


# Performance Considerations

When defining a chainlink, e.g.

`chain = {f, g, h}`,

a function is created, and on its first run with a particular type it will be compiled (whether called by `x.{chain}` or by `chain(x)`). In contrast, when calling `x.{f, g, h}` directly, no function is created or compiled, so evaluation occurs at maximum possible speed.

If it's necessary to save a `chain`, it's recommended to set it to a constant value `const`. This is to avoid type-instability, which causes slower runtime:

```julia
julia> chain = {it+1}
{it + 1}

julia> @btime (1).{chain}
  22.513 ns (0 allocations: 0 bytes)
2

julia> const chain_const = {it+1}
{it + 1}

julia> @btime (1).{chain_const}
  1.400 ns (0 allocations: 0 bytes)
2
```

Namely, when `chain` isn't a `const`, its type is not known at runtime so it must be boxed, and its return value is also unknown so that too must be boxed. 