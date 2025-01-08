module TestAllocations

using Chairmarks: Chairmarks

export @nallocs

function check_expr(expr)
    Meta.isexpr(expr, :call) || error("The first argument to this macro must be a function call")
    if expr.args[1] in (:(==), :(!=), :(<), :(<=), :(>), :(>=), :(===), :(!==))
        func = sprint(print, expr.args[2])
        op = sprint(print, expr.args[1])
        val = sprint(print, expr.args[3])
        ErrorException("You have included the comparison operator within the `@nallocs` macro.\nRemember to use the parenthesis form of the macro call in these cases:\n- `@nallocs($func) $op $val")
    else
        expr
    end
end

function process_func!(func_expr)
    for (i, arg) in enumerate(func_expr.args)
        i == 1 && continue # Func name
        if Meta.isexpr(arg, :parameters)
            for (ki, kwarg) in enumerate(arg.args)
                arg.args[ki] = process_kwarg(kwarg)
            end
        else
            func_expr.args[i] = process_arg(arg)
        end
    end
end

process_arg(s::Symbol) = Expr(:$, s)
process_arg(arg) = arg
function process_arg(arg::Expr)
    arg.head === :kw && error("Only pass keyword arguments after the `;` within the @check_allocations macro")
    if Meta.isexpr(arg, :(...))
        Expr(:..., process_arg(arg.args[1]))
    elseif Meta.isexpr(arg, :$)
        arg.args[1]
    else
        Expr(:$, arg)
    end
end

function process_kwarg(kwarg)
    if kwarg isa Symbol
        Expr(:kw, kwarg, process_arg(kwarg))
    elseif Meta.isexpr(kwarg, :kw)
        Expr(:kw, kwarg.args[1], process_arg(kwarg.args[2]))
    elseif Meta.isexpr(kwarg, :(...))
        process_arg(kwarg)
    else
        error("Invalid keyword argument: $kwarg")
    end
end

"""
    @nallocs(func_call)

Evaluate the number of allocations when calling the function identified by the `func_call` expression. It uses `Chairmarks` internally with `evals=1, samples = 0` and makes sure that all arguments and keyword arguments within `func_call` are interpolated to avoid phantom allocations.

In some cases, one might want to avoid interpolating args and kwargs before passing them to the function call. To do this, one can use the `\$` operator in front of the variables that should not be interpolated, effectively reversing the effect of interpolation w.r.t. the `@be` macro

This function is mostly useful during tests, and it can be chained with the `@test` macro directly as

# Example
```jldoctest
using TestAllocations
using Test

f(args...;kwargs...) = reduce(+, args; init=0) + reduce(+, values(kwargs); init=0)
g() = 5
a = 1
c = 2
args = (3, 5)
kwargs = (;f = 5, ff = 15)

@test @nallocs(f(a, 3; c, d = g())) == 0 # passes as no allocations
@test @nallocs(f(a, 3+2, args...; c, d = g(), kwargs...)) < c # passes as no allocations

# output

Test Passed
```
"""
macro nallocs(expr)
    func = check_expr(expr)
    func isa ErrorException && return :(throw($func))
    process_func!(func)
    be_expr = Chairmarks.process_args((func, :(evals = 1), :(samples = 0)))
    :(let
        b = $be_expr
        allocations = first(b.samples).allocs
    end)
end

end # module TestAllocations

