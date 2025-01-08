# TestAllocations.jl

This package simply provides a macro to test for allocations based on Chairmarks.jl. It tries to solve the potential problems of false allocations that can occur when using the `@allocated` or `@allocations` macros (see e.g. [this zulip link](https://julialang.zulipchat.com/#narrow/stream/225542-helpdesk/topic/.E2.9C.94.20Testing.20allocations/near/290507860) or [this discourse post](https://discourse.julialang.org/t/is-it-possible-to-add-reliable-tests-that-functions-do-not-allocate/85320/4)).

The package exports a single macro `@check_allocations` that can be used to test for allocations. Check its docstring for more details.
