# type declarations

abstract type AbstractMethodChain end
abstract type AbstractMethodChainLink end
abstract type AbstractBroadcastingMethodChainLink<:AbstractMethodChainLink end

struct MethodChainLink{ex, F}<:AbstractMethodChainLink f::F end
MethodChainLink{ex}(f::F) where {ex, F} = MethodChainLink{ex, F}(f)
MethodChainLink(f) = MethodChainLink{nameof(f)}(f)
(f::MethodChainLink)(arg) = f.f(arg)
Base.show(io::IO, f::MethodChainLink{ex, F}) where {ex, F} = print(io, "$ex")

struct MethodMultiChainLink{ex, F}<:AbstractMethodChainLink f::F end
MethodMultiChainLink{ex}(f::F) where {ex, F} = MethodMultiChainLink{ex, F}(f)
MethodMultiChainLink(f) = MethodMultiChainLink{nameof(f)}(f)
(f::MethodMultiChainLink)(args) = f.f(args...)
Base.show(io::IO, f::MethodMultiChainLink{ex, F}) where {ex, F} = print(io, "$ex")

struct BroadcastingMethodChainLink{ex, F}<:AbstractBroadcastingMethodChainLink f::F end
BroadcastingMethodChainLink{ex}(f::F) where {ex, F} = BroadcastingMethodChainLink{ex, F}(f)
BroadcastingMethodChainLink(f) = BroadcastingMethodChainLink{nameof(f)}(f)
(f::BroadcastingMethodChainLink)(arg) = f.f(arg)
Base.show(io::IO, f::BroadcastingMethodChainLink{ex, F}) where {ex, F} = print(io, "$ex")

struct BroadcastingMethodMultiChainLink{ex, F}<:AbstractBroadcastingMethodChainLink f::F end
BroadcastingMethodMultiChainLink{ex}(f::F) where {ex, F} = BroadcastingMethodMultiChainLink{ex, F}(f)
BroadcastingMethodMultiChainLink(f) = BroadcastingMethodMultiChainLink{nameof(f)}(f)
(f::BroadcastingMethodMultiChainLink)(args) = f.f(args...)
Base.show(io::IO, f::BroadcastingMethodMultiChainLink{ex, F}) where {ex, F} = print(io, "$ex")

#∘(f, g::AbstractMethodChain) = f ∘ g.f
