using TestAllocations
using Test

@test_throws "Remember to use the parenthesis form" @nallocs 3+2 < 0

using Documenter
Documenter.doctest(TestAllocations; manual = false)