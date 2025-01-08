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
                arg[ki] = process_kwarg(kwarg)
            end
        else
            func_expr.args[i] = process_arg(arg)
        end
    end
end

function process_arg(arg)
    Meta.isexpr(arg, :kw) && error("Only pass keyword arguments after the `;` within the @check_allocations macro")
    if arg isa Union{Expr, Symbol}
        Expr(:$, arg)
    else
        arg
    end
end

function process_kwarg(kwarg)
    if kwarg isa Symbol
        Expr(:kw, kwarg, process_arg(kwarg))
    elseif Meta.isexpr(kwarg, :kw)
        Expr(:kw, kwarg.args[1], process_arg(kwarg.args[2]))
    else
        error("Invalid keyword argument: $kwarg")
    end
end

macro check_allocations(expr)
    (; op, func, limit) = extract_args(expr)
    if limit isa Expr
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

