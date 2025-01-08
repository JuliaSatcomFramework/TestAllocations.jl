using TestAllocations
using Test

f(a,b;c,d) = a+b+c+d
g() = 5
a = 1
c = 2
@test @check_allocations f(a, 3; c, d = g()) # passes as no allocations
@test @check_allocations f(a, 3+2; c, d = g()) < c