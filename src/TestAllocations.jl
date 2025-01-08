module TestAllocations


using Chairmarks: Chairmarks
using Test

export @check_allocations

function extract_args(expr)
    Meta.isexpr(expr, :call) || error("The first argument to this macro must be a function call")
    op, func, limit = if expr.args[1] in (:(==), :(!=), :(<), :(<=), :(>), :(>=), :(===), :(!==))
        # We have an explicit test provided
        expr.args
    else
        # We have only the function, so we assume op is == and limit is 0
        :(==), expr, 0
    end
    (; op, func, limit)
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

function process_arg(arg)
    Meta.isexpr(arg, :kw) && error("Only pass keyword arguments after the `;` within the @check_allocations macro")
    if arg isa Symbol
        Expr(:$, arg)
    elseif arg isa Expr
        if Meta.isexpr(arg, :(...))
            Expr(:..., process_arg(arg.args[1]))
        else
            Expr(:$, arg)
        end
    else
        arg
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
    @check_allocations func_call
    @check_allocations func_call op val

Evaluate the allocations of calling the function identified by the `func_call` expression using `Chairmarks` and making sure that all arguments and keyword arguments within `func_call` are interpolated to avoid phantom allocations.

Optionally, a check on the number of allocations can be performed with the extended signature containing `op` and `val`, where `op` can be one of:
 - `==`
 - `!=`
 - `<`
 - `<=`
 - `>`
 - `>=`

and `val` is either a number or a symbol/expression that is evaluated in the caller's scope.

When called with just one argument, the macro is equivalent to:
- `@check_allocations func_call == 0`

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

@test @check_allocations f(a, 3; c, d = g()) # passes as no allocations
@test @check_allocations f(a, 3+2, args...; c, d = g(), kwargs...) < c 

# output

Test Passed
```
"""
macro check_allocations(expr)
    (; op, func, limit) = extract_args(expr)
    if limit isa Union{Symbol, Expr}
        limit = esc(limit)
    end
    process_func!(func)
    passed = Expr(:call, op, :allocations, limit)
    be_expr = Chairmarks.process_args((func, :(evals = 1), :(samples = 0)))
    :(let
        b = $be_expr
        allocations = first(b.samples).allocs
        $passed
    end)
end

end # module TestAllocations

