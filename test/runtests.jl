using TestAllocations
using Test

@test_throws "Remember to use the parenthesis form" @nallocs 3+2 < 0

# We test the interpolation functionality
ex = @macroexpand @nallocs f($a)
inner_ex = ex.args[end].args[2] # The return expression is a let, so we want to check the first inner ex which the one using Charimarks
@test inner_ex.args[end].head !== :let

using Documenter
Documenter.doctest(TestAllocations; manual = false)