# *MethodChains.jl*

```julia
α.{a}.{b}.{c}.{d}.{e}.{f}.{g}.{h}.{i}.{j}.{k}.{l}.{m}.{n}.{o}.{p}.{q}.{r}.{s}.{t}.{u}.{v}.{w}.{x}.{y}.{z}
```

## Welcome!

This is an ambitious (and somewhat experimental, and fun!) approach to generalize method chaining and function composition.

To install:
```julia
] add https://github.com/uniment/MethodChains.jl
```
and
```julia
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

To make it execute on every line in the REPL, run this at startup:
```julia
MethodChains.init_repl()
```

Then, you won't have to worry about typing `@mc` every time. 🤩

Definitely do not add this to your startup.jl file if you don't like having fun:

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

You can also construct one and immediately call it, but that's not really necessary (and takes greater compile time than suffix position):
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
julia> const avg = {len=length(it), sum(it)/len}
{len = length(it), sum(it) / len}

julia> (1,2,3).{avg}
2.0

julia> const stdev = {μ = it.{avg}, it .- μ, it.^2, avg, sqrt};

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
* If an expression type returns nothing, such as a `for` or `while` loop, then it is executed but its result is not assigned to `it`.
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
    _=println(it) # show intermediate value, discard return value
    combine(it, :age => sum)
}
```

*Example from DataPipes.jl Readme*

```julia
julia> "a=1 b=2 c=3".{
           split
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
(a=1,b=2,c=3).{(a, b, c) = it, it=(a=a^2, b=b^2, c=c^2)}
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

That was fun! This chaining syntax allows for really basic composition, like `x.{f, g, h}`, but also some more advanced stuff too like `x.{f, it.a, g}` or `x.{i for i ∈ 1:it}`. Why would you use this instead of a function? Because on every line you're presumed *most likely* to call a function on, or otherwise manipulate, the object `it`, this default behavior frequently enables very concise expressions. It also hints to the IDE autocomplete what type of object you're likely about to call a function on, as well as providing a natural "flow" of thought as the object passes through a sequence of transformations. Finally, calling the chain immediately (e.g. `x.{expr1, expr2, ...}`) doesn't allocate a function, which keeps compile time minimized, while still being a shorthand for creating locally-scoped variables.

But there's even more to it. (This is the *really* experimental feature of this syntax, so please play with it and offer feedback!)

## 2-dimensional chains


So far we've discussed one-dimensional chains, wherein a single object undergoes a sequence of transformations in time. However, we can also express two-dimensional chains, wherein multiple objects spread across space undergo their own transformation chains, and occasionally interact, through time. 

Take this for example:

```julia
(a, b, c).{
    it...
    f       g       h
    g       h       f
    h       f       g
    it+3    it*2    it+1    
    them
}
```
The result of this chain is equivalent to `(h(g(f(a)))+3, f(h(g(b)))*2, g(f(h(c)))+1)`. Notice that the expression represents three chains; the three input elements have been splatted across the top row, and the values waterfall down to the bottom where they are collected into a tuple. The pronoun `it` is, again, local to each chain, and the pronoun `them`, whenever it appears, collects all `it`s into a tuple. For example:

```julia
(2-2im).{
    real        imag
    it^2        it^2
    Complex(them...)
}
```

Here, the input was not splatted across the top row. When the next row has more elements than the last, and the last did not splat, then the last element of the row above is copied across. Notice that after the chains, the two chains came together and interacted.

> Question for the reader: Is copying the *last* value across the preferred behavior? Or perhaps, would copying the sequence, e.g.:
>
> Suppose the last line had `1 2 3`, and the next line has `it it it it it it`. Current behavior would copy across `1 2 3 3 3 3`. But maybe it would be better to copy across `1 2 3 1 2 3`? Behavior is not fixed, and feedback is welcome.

It is presumed that each line will have the same number of expressions as the one above it. But if it doesn't, or if there is any splat on the previous line, or if there's any expression of `them` on the next line, then all the individual chains terminate, their values are collected into `them`, and new chains commence.

Values can also be discarded, which causes their respective chains to end as well:

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

## Going Deeper

Let's discuss how it works, so you really understand what's going on.

When you create a multi-chain (a method chain with multiple columns), first a "background chain" is started. The background chain has two local keywords defined, `it` and `them`. The keyword `it` acts just as before. The keyword `them` has interesting behavior, which we'll see in a bit. Like expressions of `it`, expressions of `them` are not called, and are instead assigned to `it`. As with 1-D chains, any variables defined in a 2-D chain are local to that chain.

When a row with more than one column starts, subchains begin (and execution of the background chain is paused). Any local variables in the background chain are accessible to the subchains, except that of course each sub-chain has its own local `it` defined.

When sub-chains begin, they take their local `it` values as the elements of the background chain's collection `them`. Nominally, `them` is just a tuple `them=(it,)`. When new subchains exceed the length of `them`, then `last(them)` is copied across into the new chains' `it` values.

When multiple chains exist, then `them` becomes a tuple of the chains' values. Also, if a value is splatted into a row, `them` slurps up those values.

For any row where the number of columns changes, where an object is splatted across a row, or where `them` is accessed, all subchains are halted (destroying any locally-defined variables) and an inventory is taken of all the chains' local `it` values, which are collected into `them`. 

One non-intuitive consequence of this behavior is that, if you have a multi-chain where all you do is access `them` repeatedly (which, you'll remember, causes an assignment `it=them`), you just get a deeper and deeper nested tuple.

```julia
julia> (1,2,3).{them; them; them}
((((1, 2, 3),),),)
```

But that's okay! That's exactly how it should operate.

As before, if you're not sure how a multi-chain will operate, run `@macroexpand @mc ...`. Let's see if you think its behavior is as intuitive and unambiguous as I think it is.

## Examples

*Standard Deviation, Variance, and Maximum Absolute Deviation*

```julia
julia> (0:10...,).{
           avg = {len=length(it), sum(it)/len}
           μ = it.{avg}
           it .- μ

         # stdev     var      mad
           it.^2     it.^2    abs.(it)
           avg       avg      maximum
           sqrt      _        _
           them
       }
(3.1622776601683795, 10.0, 5.0)
```

Notice that `_` is used as a continuation of the chain on the last line. `it` can also be used for this. 

> This behavior for `_` is experimental and not guaranteed for the future (pending a more final decision on the character's use in the language). Would've been perfect if I could use `⋮`, but it's defined to be an operator so I can't.

To inspect the intermediate values mid-chain:

```julia
julia> (0:10...,).{
           avg = {len=length(it), sum(it)/len}
           μ = it.{avg}
           it .- μ

         # stdev   var     mad
           it.^2   it.^2   abs.(it); _=println(them)
           avg     avg     maximum
           sqrt    _       _
           them
       }
(3.1622776601683795, 10.0, 5.0)
```


*FFT Butterfly*

Example is a WIP



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

When performing benchmarks, be careful to ensure the correct things are being measured. For example, let's try this:

```julia
julia> @btime [1,2].{it./2}
  70.329 ns (2 allocations: 160 bytes)
2-element Vector{Float64}:
 0.5
 1.0

julia> x = [1,2];

julia> @btime $x./2
  41.515 ns (1 allocation: 80 bytes)
2-element Vector{Float64}:
 0.5
 1.0
```

From this test, it appears that the method chain has caused extra runtime and an extra allocation. However, this is just an artifact of the measurement technique, as you can confirm:
```julia
julia> @btime [1,2]./2
  72.181 ns (2 allocations: 160 bytes)
2-element Vector{Float64}:
 0.5
 1.0

 julia> @btime $x.{it./2}
  41.446 ns (1 allocation: 80 bytes)
2-element Vector{Float64}:
 0.5
 1.0
```