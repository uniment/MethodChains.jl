using MethodChains
using Test

@testset "MethodChains.jl" begin
    @mc @testset "Chain Tuples" begin
        @test (1:2:9).{first, last, step} === (1, 9, 2)

    end

    @testset "Single Sequential Chains" begin
        x=2
        f(x) = x^2
        g(x) = x+1
        @test @mc g(√(f(x)-1)) == x.{f; √(it-1); g}
        @test @mc map({it^2}, 1:10) == (1:10).{map({it^2}, it)}
        @test @mc map({it^2}, 1:10) == map(x->x^2, 1:10)
        @test @mc (1,2,5).{(first(it):last(it)...,)} == (1:5...,)
        @test @mc "1,2,3".{split(it,","); parse.(Int,it); it.^2; join(it,",")} == "1,4,9"
        @mc avg = {len=length(it); sum(it)/len}
        @test @mc (1,2,3).{avg} == sum((1,2,3))/3
        @test @mc Dict(:a=>1, :b=>2, :c=>3).{for k ∈ keys(it) it[k]=it[k]^2 end; it} == Dict(:a=>1, :b=>4, :c=>9)
        @test @mc "a=1 b=2 c=3".{
                split
                map({
                    split(it, "=")
                    (Symbol(it[1]) => parse(Int, it[2]))
                }, it)
                NamedTuple
            } == (a=1, b=2, c=3)
        @test @mc [1,2,3].{map({it^2}, it)} == [1, 4, 9]
        @test @mc [1,2,3].{join(it, ", ")} == "1, 2, 3"
        @test @mc "1".{parse(Int, it)} == 1
        @test @mc (1,2).{(a,b)=it; (;b,a)} == (b=2, a=1)
        @test @mc "1 2, 3; hehe4".{
                eachmatch(r"(\d+)", it)
                map({first; parse(Int, it)}, it)
                join(it, ", ")
            } == "1, 2, 3, 4"
        @mc chain = {split(it, r",\s*"); {parse(Int, it)^2}.(it); join(it, ", ")};
        @test @mc "1, 2, 3, 4".{chain} == "1, 4, 9, 16"
        @test @mc (9).{it+1; {it ≤ 1 ? it : recurse(it-1)+recurse(it-2)}} == 55
        @test @mc (5).{it+5; {it ≤ 1 ? it : (it-1).{recurse}+(it-2).{recurse}}} == 55
        @test @mc map([1,2,3]) do {it^2} end == [1, 4, 9]
    end

    @testset "Multi Sequential Chains" begin
        @test @mc (1,2,3).{them; them; them} === ((((1, 2, 3),),),)
        @test @mc (1:2:10).{first step last} === (1, 2, 9)
        p(x) = x+1; q(x) = 2x; r(x) = x^2
        @test @mc (1, 2, 3).{
                it...
                p       q       r
                q       r       p
                r       p       q
                it+3    it*2    it+1
                them
            } == (19, 34, 21)
        @test @mc (2-2im).{
                real        imag
                it^2        it^2
                Complex(them...)
            } == 4+4im
        @test @mc (1, 2, 3).{
                it...
                it      it      it
                it
                them
            } == (1,)
        @test @mc (1).{
                it                      # 1
                it      it+1            # 1,2
                it      it      it+1    # 1,2,3
                them.+1...              # 2,3,4
                it      them.+1...      # 2,3,4,5
                them                    # collect at end
            } == (2, 3, 4, 5)
        @test @mc (1,2).{
                it...
                it      (it, it+1)...
                it      it              it
                them
            } == (1,2,3)
        @test @mc (1,2,3).{them; them; them} == ((((1, 2, 3),),),)
        @test @mc ((0:10...,).{
            avg = {len=length(it); sum(it)/len}
            μ = it.{avg}
            it .- μ
 
          # stdev     var      mad
            it.^2     it.^2    abs.(it)
            avg       avg      maximum
            sqrt      _        _
            them
        } .≈ (3.1622776601683795, 10.0, 5.0)) |> all

        @test @mc (3.141).{{sin}; cos} == cos(sin(3.141))

        @mc toy_fft = {
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

        @test @mc [1,2,3,4].{toy_fft} ≈ [10.0 + 0.0im, -2.0 + 2.0im, -2.0 + 0.0im, -2.0 - 2.0im]

        @mc toy_fft = {
            # setup
            Vector{ComplexF64}
            n = it.{length}
            n == 2 && (return [it[1]+it[2]; it[1]-it[2]]) || it # base case
            W = exp(-2π*im/n)
            # butterfly
            recurse(it[1:2:end-1])    recurse(it[2:2:end])
            _                         it.*W.^(0:n÷2-1)
        #   ⋮        ⋱                ⋰         ⋮
                        (x1,x2)=them
        #   ⋮        ⋰                ⋱         ⋮
            [x1.+x2          ;            x1.-x2]::Vector{ComplexF64}
        }

        @mc toy_fft = {
            n = length(it)
            if n == 2  ComplexF64[it[1]+it[2]; it[1]-it[2]]
            else it.{
                W = exp(-2π*im/n)
                recurse(it[1:2:end-1])    recurse(it[2:2:end])
                _                         it.*W.^(0:n÷2-1)
            #   ⋮        ⋱                ⋰         ⋮
                            (x1,x2)=them
            #   ⋮        ⋰                ⋱         ⋮
                [x1.+x2          ;            x1.-x2]
            } end
        }

        @mc function toy_fft(inputvec)
            d = Vector{ComplexF64}(inputvec)
            n = length(d)
            if n == 2  return [d[1]+d[2]; d[1]-d[2]]  end
            d.{
                W = exp(-2π*im/n)
                toy_fft(it[1:2:end-1])    toy_fft(it[2:2:end])
                _                         it.*W.^(0:n÷2-1)
            #   ⋮        ⋱                ⋰         ⋮
                            (x1,x2)=them
            #   ⋮        ⋰                ⋱         ⋮
                [x1.+x2          ;            x1.-x2]
            }
        end

        @test @mc [1,2,3,4].{toy_fft} ≈ [10.0 + 0.0im, -2.0 + 2.0im, -2.0 + 0.0im, -2.0 - 2.0im]

        @test @mc (1,2,3).{x=5;it...;them.+x} == (6, 7, 8)
    end

end
