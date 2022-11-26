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
@mc function foo(x)
    y = x.{f, g}
    z = y.{h}
end
```

To make it execute on every line in the REPL, run this:
```julia
MethodChains.init_repl()
```

Then, you won't have to worry about typing `@mc` every time. 🤩

That only seems to work for the REPL; VSCode and IJulia seems to be having trouble at the moment. (It works in the VSCode REPL, but not for SHIFT+ENTER or CTRL+ENTER.) For this reason, it's recommended to use the REPL.

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

You'll often find it handy to use chaining syntax even when the "chain" is only one element long, and that's dandy!

```julia
my_arr.{length}.prop + 1

```

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

In this case, `m` is called a "chainlink." Chainlinks are single-input, single-output functions defined with chaining syntax.

You can also construct a chainlink and immediately call it, but that's not really necessary (and takes greater compile time than putting the chain in suffix position):

```julia
y = {f, g, h}(x)
```

Now, unless every function is a Clojure-style transducer, or another chainlink, chances are that your functions won't compose perfectly like this. This situation happens in real life too—and to handle this, in the English language we reserve the pronoun "it," to give the object a local and temporary name to allow short (but flexible) manipulations spliced between larger functions. So, `MethodChains` also uses `it`.

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

When constructing a chainlink, a function of `it` is created:
```julia
julia> @macroexpand @mc {f, √(it - 1), g}
:(MethodChainLink{Symbol("{f, √(it - 1), g}")}((it->begin
              it = f(it)
              it = √(it - 1)
              it = g(it)
          end)))
```

Pretty simple, neh? `it` is a keyword *defined only locally inside the chain*, and on every step it takes on a new value. If an expression in the chain has `it` in it, then it's simply executed and the result overwrites `it`; otherwise it's assumed that it evaluates to a function, which is called on `it` (and again, the result is assigned to `it`).

These two do the same thing:

```julia
map({it^2}, 1:10)
(1:10).{map({it^2}, it)}
```

A couple more examples:
```julia
julia> x = (0,3,5);

julia> x.{(first(it):last(it)...,)}
(0, 1, 2, 3, 4, 5)

julia> (x.{first}:x.{last}...,)
(0, 1, 2, 3, 4, 5)

julia> x.{x.{sum} > 7 ? maximum : minimum}
5

julia> (1,2,3).{it.^2, sum, sqrt}
3.7416573867739413

julia> "1,2,3".{split(it,","), parse.(Int,it), it.^2, join(it,",")}
"1,4,9"
```

Now, the rule for whether to *call* the expression, or to leave it intact, or to assign `it` to it, is actually a bit more complicated (but pretty natural and straightforward). Check it out:

```julia
julia> const avg = {len=it.{length}; sum(it)/len}
{len = length(it), sum(it) / len}

julia> (1,2,3).{avg}
2.0

julia> const stdev = {μ = it.{avg}, it.-μ, it.^2, avg, sqrt};

julia> (1,2,3).{stdev}
0.816496580927726

julia> Dict(:a=>1, :b=>2, :c=>3).{for k ∈ keys(it) it[k]=it[k]^2 end}
Dict{Symbol, Int64} with 3 entries:
  :a => 1
  :b => 4
  :c => 9
```

(Note that expressions can be separated by commas or by semicolons.)

Namely, regarding expressions inside the curly braces:

* If an expression is an assignment, leave it intact and do not assign `it` to it. This allows local variables to be assigned.
* If an expression type returns nothing, such as a `for` or `while` loop, then it is executed but its result is not assigned to `it`. (Note: this does *not* apply to function calls, such as `println`.)
* If an expression is a non-callable type, such as a comprehension, generator, tuple, or vector, then it is not called and is simply assigned to `it`.
* If an expression is an expression of `it`, then it is simply executed and assigned to `it`.
* Otherwise it's assumed that the expression evaluates to something callable, and so it should be called on `it` and assigned to `it`. This is the default behavior.

If it's desired to override the default behavior of method calling, you can make an explicit assignment to `it`.

## Examples

*My Examples*
```julia
[1,2,3].{map({it^2}, it)}
[1,2,3].{join(it, ", ")}
"1".{parse(Int, it)} == 1
(1,2).{(a,b)=it, (;b,a)}
```

*Operator Precedence*
```julia
julia> (1,2).{(a,b)=it,(;b,a)}.b
2

julia> (1,2).{(a,b)=it,(;b,a)}[1]
2
```

*Examples from [Pipe.jl](https://github.com/oxinabox/Pipe.jl) Readme*

```julia
a.{b(it...)}
a.{b(it(1,2))}
a.{b(it[3])}
(2,4).{get_angle(it...)}
```

*Block Chaining*

```julia
julia> [1,2,3].{
           filter(isodd, it),
           map({it^2}, it),
           sum,
           sqrt
       }
3.1622776601683795
```

*Example from [Chain.jl](https://github.com/jkrumbiegel/Chain.jl) Readme*

```julia
df.{
    dropmissing
    filter(:id => >(6), it)
    groupby(it, :group)
    (println(it); it) # show intermediate value, discard return value
    combine(it, :age => sum)
}
```

*Example from [DataPipes.jl](https://gitlab.com/aplavin/DataPipes.jl) Readme*

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

*More*

```julia
julia> "1 2, 3; hehe4".{
           eachmatch(r"(\d+)", it)
           map({first, parse(Int, it)}, it)
           join(it, ", ")
       }
"1, 2, 3, 4"
```

*Saving a Chainlink*

```julia
julia> chainlink = {split(it, r",\s*"), {parse(Int, it)^2}.(it), join(it, ", ")};

julia> "1, 2, 3, 4".{chainlink}
"1, 4, 9, 16"
```

*Transducer Chain*

(example taken from [this presentation](https://www.youtube.com/watch?v=6mTbuzafcII))

```julia
process_bags = {
    mapcatting(unbundle_pallet)
    filtering(is_nonfood)
    mapping(label_heavy)
}
process_bags.{into(airplane, it, pallets)}
```

# *Advanced Use*

That was fun! This chaining syntax allows for really basic composition, like `x.{f, g, h}`, but also some more advanced stuff too like `x.{f, it.a, g}` or `x.{i for i ∈ 1:it}`. 

Why would you use this instead of normal function call syntax? Because on every line you're presumed *most likely* to call a function on, or otherwise manipulate, the object `it`, this default behavior frequently enables very concise expressions. It also hints to the IDE autocomplete what type of object you're likely about to call a function on, as well as providing a natural "flow" of thought as the object passes through a sequence of transformations. Finally, calling the chain immediately (e.g. `x.{expr1, expr2, ...}`) doesn't allocate a function, which keeps compile time minimized, while still being a shorthand for creating locally-scoped variables.

But there's even more to it. (This is the *really* experimental feature of this syntax, so please play with it and offer feedback!)

## Multi-Chains


So far we've discussed one-dimensional chains, wherein a single object undergoes a sequence of transformations in time. However, we can also express two-dimensional chains, wherein multiple objects spread across space undergo their own transformation chains, and occasionally interact, through time. 

The syntax is similar to that for vector and matrix building. Semicolons or newlines separate rows, and horizontal whitespace separates expressions within a row. When newlines delimit rows, semicolons are optional.

I suggest you skip to the bottom to look at the examples to gain some motivation for what this syntax could be used for, and then return here.

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

The result of this chain is equivalent to `(h(g(f(a)))+3, f(h(g(b)))*2, g(f(h(c)))+1)`. Notice that the expression represents three chains; the three elements of the input argument have been splatted across the top row, and the values waterfall down to the bottom where they are collected into a tuple. The pronoun `it` is, again, local to each chain, and the pronoun `them`, any time it appears in a row, collects all `it`s from the previous row into a tuple. Another example:

```julia
(2-2im).{
    real        imag
    it^2        it^2
    Complex(them...)
}
```

Here, the input argument was \*not\* splatted across the top row. When the next row has more columns than the last, and the last did not splat, then the last element of the row above is copied across. At the bottom, the two chains came together and interacted by first being collected into `them`, which was then splatted into the `Complex` constructor.

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

> Question for the reader: Is dropping the *rightmost* values the preferred behavior? Or should we drop the left?

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
    them[2:3]...
    it      it
    them
}
```

The return value here is `(2, 3)`.

It's a little funky to be playing around with expressions of just `it` and `them`, but it's instructive (and weirdly therapeutic), so try it!

Fun question: On the line with two `it`s after `them[2:3]...`, what happens if you add another `it`? 😏

## Going Deeper

Let's discuss how it works, so you really understand what's going on.

When you create a multi-chain (a method chain with multiple columns), first a "background chain" is started. The background chain has two local keywords defined, `it` and `them`. The keyword `it` acts just as before. The keyword `them` has interesting behavior, which we'll explore in a bit. Like expressions of `it`, expressions of `them` are not called, and are instead assigned to `it`. As with single chains, any variables defined in a multi-chain are local to that chain.

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
           avg = {len=it.{length}, sum(it)/len}
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

Notice that `_` is used as a continuation of the chain on the last line. `it` can also be used. 

> This behavior for `_` is experimental and not guaranteed for the future (pending a more final decision on the character's use in the language). Would've been perfect if I could use `⋮`, but it's defined to be an operator so I can't.

Note that if it's desired to make a chain shorter (e.g., because one chain is much longer than its adjacent chains), you can package several operations together inside `{}`. Within the context of a chain, it's syntax transformed away so a function needn't be declared.

To inspect the intermediate values mid-chain:

```julia
julia> (0:10...,).{
           avg = {len=it.{length}; sum(it)/len}
           μ = it.{avg}             ; (println(μ); it)
           it .- μ                  ; (println(it); it)

         # stdev   var     mad
           it.^2   it.^2   abs.(it) ; (println(them); them)...
           avg     avg     maximum  ; (println(them); them)...
           sqrt    _       _        ; (println(them); them)...
           them
       }
(3.1622776601683795, 10.0, 5.0)
```


*FFT Butterfly*

```julia
@mc const toy_fft = {
    # setup
    Vector{ComplexF64}
    n = it.{length}
    n == 2 && (return [it[1]+it[2]; it[1]-it[2]]) || it # base case
    W = exp(-2π*im/n)
    # butterfly
    it[1:2:end-1].{toy_fft}   it[2:2:end].{toy_fft}
    _                         it.*W.^(0:n÷2-1)
#   ⋮        ⋱                ⋰         ⋮
                (x1,x2)=them
#   ⋮        ⋰                ⋱         ⋮
    [x1.+x2          ;            x1.-x2]::Vector{ComplexF64}
}
```

This is a fully-functioning recursive FFT. Note that this is radix-2 (i.e., it only works for arrays whose length is a power of two). 

On the performance front, there's no way these fourteen lines (ten excluding comments) will beat the monster that is FFTW, but it's a cute toy. As expected, it's definitely better than a DFT doing naïve matrix multiplication (whose time and resource consumption are $O(n^2)$, versus $O(n\log n)$ for FFT):

```julia
julia> @mc function dft(x̲)
           N = x̲.{length}
           ℱ = [exp(-2π*im*m*n/N) for m=0:N-1, n=0:N-1]
           ℱ * x̲
       end
dft (generic function with 1 method)

julia> x=randn(2); @btime $x.{toy_fft}; @btime $x.{dft};
  45.197 ns (2 allocations: 192 bytes)
  162.435 ns (3 allocations: 320 bytes)

julia> x=randn(4); @btime $x.{toy_fft}; @btime $x.{dft};
  245.596 ns (11 allocations: 1.09 KiB)
  409.000 ns (3 allocations: 592 bytes)

julia> x=randn(8); @btime $x.{toy_fft}; @btime $x.{dft};
  669.737 ns (29 allocations: 3.19 KiB)
  1.320 μs (3 allocations: 1.44 KiB)

julia> x=randn(16); @btime $x.{toy_fft}; @btime $x.{dft};
  1.540 μs (65 allocations: 7.97 KiB)
  4.857 μs (3 allocations: 4.78 KiB)

julia> x=randn(32); @btime $x.{toy_fft}; @btime $x.{dft};
  3.325 μs (137 allocations: 18.70 KiB)
  18.800 μs (3 allocations: 17.25 KiB)

julia> x=randn(64); @btime $x.{toy_fft}; @btime $x.{dft};
  7.075 μs (281 allocations: 42.34 KiB)
  127.500 μs (4 allocations: 66.17 KiB)

julia> x=randn(128); @btime $x.{toy_fft}; @btime $x.{dft};
  15.000 μs (569 allocations: 94.25 KiB)
  379.300 μs (4 allocations: 260.30 KiB)

julia> x=randn(256); @btime $x.{toy_fft}; @btime $x.{dft};
  32.400 μs (1145 allocations: 207.38 KiB)
  1.421 ms (4 allocations: 1.01 MiB)

julia> x=randn(512); @btime $x.{toy_fft}; @btime $x.{dft};
  69.200 μs (2297 allocations: 451.62 KiB)
  5.528 ms (4 allocations: 4.02 MiB)

julia> x=randn(1024); @btime $x.{toy_fft}; @btime $x.{dft};
  147.800 μs (4601 allocations: 976.12 KiB)
  21.369 ms (4 allocations: 16.03 MiB)

julia> x=randn(2048); @btime $x.{toy_fft}; @btime $x.{dft};
  339.000 μs (9211 allocations: 2.05 MiB)
  84.898 ms (6 allocations: 64.06 MiB)

julia> x=randn(4096); @btime $x.{toy_fft}; @btime $x.{dft};
  761.300 μs (18436 allocations: 4.38 MiB)
  340.492 ms (6 allocations: 256.13 MiB)

julia> x=randn(8192); @btime $x.{toy_fft}; @btime $x.{dft};
  1.736 ms (36886 allocations: 9.32 MiB)
  1.363 s (6 allocations: 1.00 GiB)

julia> x=randn(16384); @btime $x.{toy_fft}; @btime $x.{dft};
  3.881 ms (73786 allocations: 19.76 MiB)
  5.544 s (6 allocations: 4.00 GiB)

julia> x=randn(32768); @btime $x.{toy_fft}; @btime $x.{dft};
  8.915 ms (147586 allocations: 41.77 MiB)
  22.615 s (6 allocations: 16.00 GiB)
```

GLHF!

# Performance Considerations

When defining a chainlink, e.g.

`chain = {f, g, h}`,

a function is created, and on its first run with a particular type it will be compiled (whether called by `x.{chain}` or by `chain(x)`). In contrast, when calling `x.{f, g, h}` directly, no function is created or compiled, so execution occurs with minimum time and resources.

If it's necessary to save a `chain` as a global object, it's recommended to set it to a constant value `const`. This is to avoid type-instability, which causes slower runtime:

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

Namely, when `chain` isn't a `const`, its type is not known at runtime so it must be boxed, and its return value is also unknown so that too must be boxed. But this is true of any global variable.

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

From this test, it appears that the method chain has caused extra runtime and an extra allocation. However, this is just an artifact of the measurement technique, as you can easily confirm:
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

# *Errata / Points of Debate*

1. I don't have multi-threading implemented yet.
2. It might also be nice to have macros to make it easier to call `println`, or otherwise ignore an expression's return value.
3. Up for debate: instead of `it` and `them`, use `me` and `us`? 🤔
4. To add: subchain splatting (so that long rows can be made by splatting in vertically arranged expressions)?
5. What's the adjoint of a chain or multi-chain?
6. As mentioned before: what's the best way to copy values into new chains, and drop old chains? Left-aligned, right-aligned, etc.?
