export _hagerzhang2!, satisfies_wolfe2, secant2,secant2
export secant22!, update2!, linefunc2!, bisect2!

# Display flags are represented as a bitfield
# (not exported, but can use via OptimizeMod.ITER, for example)
const one64 = convert(UInt64, 1)
const FINAL       = one64
const ITER        = one64 << 1
const PARAMETERS  = one64 << 2
const GRADIENT    = one64 << 3
const SEARCHDIR   = one64 << 4
const ALPHA       = one64 << 5
const BETA        = one64 << 6
# const ALPHAGUESS  = one64 << 7 TODO: not needed
const BRACKET     = one64 << 8
const LINESEARCH  = one64 << 9
const UPDATE      = one64 << 10
const SECANT2     = one64 << 11
const BISECT      = one64 << 12
const BARRIERCOEF = one64 << 13
display_nextbit = 14

# There are some modifications and/or extensions from what's in the
# paper (these may or may not be extensions of the cg_descent code
# that can be downloaded from Hager's site; his code has undergone
# numerous revisions since publication of the paper):
#   cgdescent: the termination condition employs a "unit-correct"
#     expression rather than a condition on gradient
#     components---whether this is a good or bad idea will require
#     additional experience, but preliminary evidence seems to suggest
#     that it makes "reasonable" choices over a wider range of problem
#     types.
#   linesearch: the Wolfe conditions are checked only after alpha is
#     generated either by quadratic interpolation or secant
#     interpolation, not when alpha is generated by bisection or
#     expansion. This increases the likelihood that alpha will be a
#     good approximation of the minimum.
#   linesearch: In step I2, we multiply by psi2 only if the convexity
#     test failed, not if the function-value test failed. This
#     prevents one from going uphill further when you already know
#     you're already higher than the point at alpha=0.
#   both: checks for Inf/NaN function values
#   both: support maximum value of alpha (equivalently, c). This
#     facilitates using these routines for constrained minimization
#     when you can calculate the distance along the path to the
#     disallowed region. (When you can't easily calculate that
#     distance, it can still be handled by returning Inf/NaN for
#     exterior points. It's just more efficient if you know the
#     maximum, because you don't have to test values that won't
#     work.) The maximum should be specified as the largest value for
#     which a finite value will be returned.  See, e.g., limits_box
#     below.  The default value for alphamax is Inf. See alphamaxfunc
#     for cgdescent and alphamax for linesearch_hz.

const DEFAULTDELTA = 0.1
const DEFAULTSIGMA = 0.9


# NOTE:
#   [1] The type `T` in the `HagerZhang{T}` need not be the same `T` as in
#       `hagerzhang!{T}`; in the latter, `T` comes from the input vector `x`.
#   [2] the only method parameter that is not included in the
#       type is `iterfinitemax` since this value needs to be
#       inferred from the input vector `x` and not from the type information
#       on the parameters

# @with_kw immutable HagerZhang{T}
#    τ₀::T = DEFAULTDELTA
#    τ₁::T = DEFAULTSIGMA
#    alphamax::T = Inf
#    rho::T = 5.0
#    epsilon::T = 1e-6
#    gamma::T = 0.66
#    linesearchmax::Int = 50
#    psi3::T = 0.1
#    display::Int = 0
# end

# (ls::HagerZhang)(args...) = _hagerzhang!(args...,
#       ls.τ₀, ls.τ₁, ls.alphamax, ls.rho, ls.epsilon, ls.gamma,
#       ls.linesearchmax, ls.psi3, ls.display)

T = Float64


function _hagerzhang2!{T}(h :: LineModel,
                          f :: Real,
                          slope :: Real,
                          ∇ft :: Array{T,1};
                          lsr  ::  LineSearchResults{T} =
                                    LineSearchResults([0.0], [f], [slope], 0),
                          mayterminate :: Bool = false,
                          c :: Real = 1.0,
                          τ₀ :: Real = DEFAULTDELTA,
                          τ₁ :: Real = DEFAULTSIGMA,
                          alphamax :: Real = convert(T, Inf),
                          rho :: Real = convert(T, 5),
                          epsilon :: Real = convert(T, 1e-6),
                          gamma :: Real = convert(T, 0.66),
                          linesearchmax :: Integer = 50,
                          psi3 :: Real = convert(T, 0.1),
                          display :: Integer = 0,
                          iterfinitemax :: Integer = ceil(Integer, -log2(eps(T))),
                          kwargs...)
    s = h.d
    x = copy(h.x)
    df = h.nlp
    xtmp = copy(h.x)
    #lsr = LineSearchResults([0.0],[f],[slope],0)

    # println("on a τ₀ = $τ₀ et τ₁ = $τ₁")

    if display & LINESEARCH > 0
        println("New linesearch")
    end

    phi0 = lsr.value[1] # Should this be [1] or [end]?
    dphi0 = lsr.slope[1] # Should this be [1] or [end]?
    (isfinite(phi0) && isfinite(dphi0)) || error("Initial value and slope must be finite")
    philim = phi0 + epsilon * abs(phi0)
    @assert c > 0
    @assert isfinite(c) && c <= alphamax
    phic, dphic = linefunc2!(df, x, s, c, xtmp, true)
    iterfinite = 1
    while !(isfinite(phic) && isfinite(dphic)) && iterfinite < iterfinitemax
        mayterminate = false
        lsr.nfailures += 1
        iterfinite += 1
        c *= psi3
        phic, dphic = linefunc2!(df, x, s, c, xtmp, true)
    end
    if !(isfinite(phic) && isfinite(dphic))
        println("Warning: failed to achieve finite new evaluation point, using alpha=0")
        return zero(T), zero(T), false, NaN, iterfinite, NaN, false # phi0
    end
    push!(lsr, c, phic, dphic)
    # If c was generated by quadratic interpolation, check whether it
    # satisfies the Wolfe conditions
    if mayterminate &&
          satisfies_wolfe2(c, phic, dphic, phi0, dphi0, philim, τ₀, τ₁)
        if display & LINESEARCH > 0
            println("Wolfe condition satisfied on point alpha = ", c)
        end
        return c, c, false, phic, iterfinite, NaN, false # phic
    end
    # Initial bracketing step (HZ, stages B0-B3)
    isbracketed = false
    ia = 1
    ib = 2
    @assert length(lsr) == 2
    iter = 1
    cold = -one(T)
    while !isbracketed && iter < linesearchmax
        if display & BRACKET > 0
            println("bracketing: ia = ", ia,
                    ", ib = ", ib,
                    ", c = ", c,
                    ", phic = ", phic,
                    ", dphic = ", dphic)
        end
        if dphic >= 0
            # We've reached the upward slope, so we have b; examine
            # previous values to find a
            ib = length(lsr)
            for i = (ib - 1):-1:1
                if lsr.value[i] <= philim
                    ia = i
                    break
                end
            end
            isbracketed = true
        elseif lsr.value[end] > philim
            # The value is higher, but the slope is downward, so we must
            # have crested over the peak. Use bisection.
            ib = length(lsr)
            ia = ib - 1
            if c != lsr.alpha[ib] || lsr.slope[ib] >= 0
                error("c = ", c, ", lsr = ", lsr)
            end
            # ia, ib = bisect(phi, lsr, ia, ib, philim) # TODO: Pass options
            ia, ib = bisect2!(df, x, s, xtmp, lsr, ia, ib, philim, display)
            isbracketed = true
        else
            # We'll still going downhill, expand the interval and try again
            cold = c
            c *= rho
            if c > alphamax
                c = (alphamax + cold)/2
                if display & BRACKET > 0
                    println("bracket: exceeding alphamax, bisecting: alphamax = ", alphamax,
                            ", cold = ", cold, ", new c = ", c)
                end
                if c == cold || nextfloat(c) >= alphamax
                    return cold, cold, false, phic, iter, NaN, false
                end
            end
            phic, dphic = linefunc2!(df, x, s, c, xtmp, true)
            iterfinite = 1
            while !(isfinite(phic) && isfinite(dphic)) && c > nextfloat(cold) && iterfinite < iterfinitemax
                alphamax = c
                lsr.nfailures += 1
                iterfinite += 1
                if display & BRACKET > 0
                    println("bracket: non-finite value, bisection")
                end
                c = (cold + c) / 2
                phic, dphic = linefunc2!(df, x, s, c, xtmp, true)
            end
            if !(isfinite(phic) && isfinite(dphic))
                return cold, cold, false, phic, iter, NaN, false
            elseif dphic < 0 && c == alphamax
                # We're on the edge of the allowed region, and the
                # value is still decreasing. This can be due to
                # roundoff error in barrier penalties, a barrier
                # coefficient being so small that being eps() away
                # from it still doesn't turn the slope upward, or
                # mistakes in the user's function.
                if iterfinite >= iterfinitemax
                    println("Warning: failed to expand interval to bracket with finite values. If this happens frequently, check your function and gradient.")
                    println("c = ", c,
                            ", alphamax = ", alphamax,
                            ", phic = ", phic,
                            ", dphic = ", dphic)
                end
                return c, c,false, phic, iter, NaN, false
            end
            push!(lsr, c, phic, dphic)
        end
        iter += 1
    end
    while iter < linesearchmax
        a = lsr.alpha[ia]
        b = lsr.alpha[ib]
        @assert b > a
        if display & LINESEARCH > 0
            println("linesearch: ia = ", ia,
                    ", ib = ", ib,
                    ", a = ", a,
                    ", b = ", b,
                    ", phi(a) = ", lsr.value[ia],
                    ", phi(b) = ", lsr.value[ib])
        end
        if b - a <= eps(b)
            return a, a,false, lsr.value[ia], iter, NaN, false # lsr.value[ia]
        end
        iswolfe, iA, iB = secant22!(df, x, s, xtmp, lsr, ia, ib, philim, τ₀, τ₁, display)
        if iswolfe
            return lsr.alpha[iA], lsr.alpha[iA], false, lsr.value[iA], iter, NaN, false # lsr.value[iA]
        end
        A = lsr.alpha[iA]
        B = lsr.alpha[iB]
        @assert B > A
        if B - A < gamma * (b - a)
            if display & LINESEARCH > 0
                println("Linesearch: secant succeeded")
            end
            if nextfloat(lsr.value[ia]) >= lsr.value[ib] && nextfloat(lsr.value[iA]) >= lsr.value[iB]
                # It's so flat, secant didn't do anything useful, time to quit
                if display & LINESEARCH > 0
                    println("Linesearch: secant suggests it's flat")
                end
                return A, A, false, lsr.value[iA], iter, NaN, false
            end
            ia = iA
            ib = iB
        else
            # Secant is converging too slowly, use bisection
            if display & LINESEARCH > 0
                println("Linesearch: secant failed, using bisection")
            end
            c = (A + B) / convert(T, 2)
            # phic = phi(gphi, c) # TODO: Replace
            phic, dphic = linefunc2!(df, x, s, c, xtmp, true)
            @assert isfinite(phic) && isfinite(dphic)
            push!(lsr, c, phic, dphic)
            # ia, ib = update(phi, lsr, iA, iB, length(lsr), philim) # TODO: Pass options
            ia, ib = update2!(df, x, s, xtmp, lsr, iA, iB, length(lsr), philim, display)
        end
        iter += 1
    end

    # throw(LineSearchException("Linesearch failed to converge,
    # reached maximum iterations $(linesearchmax).",
    #                           lsr.alpha[ia],lsr))

    return 0.0, 0.0, false, NaN, iter, NaN, true


end

# Check Wolfe & approximate Wolfe
function satisfies_wolfe2{T<:Number}(c::T,
                                    phic::Real,
                                    dphic::Real,
                                    phi0::Real,
                                    dphi0::Real,
                                    philim::Real,
                                    τ₀::Real,
                                    τ₁::Real)
    wolfe1 = τ₀ * dphi0 >= (phic - phi0) / c &&
               dphic >= τ₁ * dphi0
    wolfe2 = (2.0 * τ₀ - 1.0) * dphi0 >= dphic >= τ₁ * dphi0 &&
               phic <= philim
    return wolfe1 || wolfe2
end

# HZ, stages S1-S4
function secant2(a::Real, b::Real, dphia::Real, dphib::Real)
    return (a * dphib - b * dphia) / (dphib - dphia)
end
function secant2(lsr::LineSearchResults, ia::Integer, ib::Integer)
    return secant2(lsr.alpha[ia], lsr.alpha[ib], lsr.slope[ia], lsr.slope[ib])
end
# phi
function secant22!{T}(df::AbstractNLPModel,
                     x::Array,
                     s::Array,
                     xtmp::Array,
                     lsr::LineSearchResults{T},
                     ia::Integer,
                     ib::Integer,
                     philim::Real,
                     τ₀::Real = DEFAULTDELTA,
                     τ₁::Real = DEFAULTSIGMA,
                     display::Integer = 0)
    phi0 = lsr.value[1]
    dphi0 = lsr.slope[1]
    a = lsr.alpha[ia]
    b = lsr.alpha[ib]
    dphia = lsr.slope[ia]
    dphib = lsr.slope[ib]
    if !(dphia < 0 && dphib >= 0)
        error(string("Search direction is not a direction of descent; ",
                     "this error may indicate that user-provided derivatives are inaccurate. ",
                      @sprintf "(dphia = %f; dphib = %f)" dphia dphib))
    end
    c = secant2(a, b, dphia, dphib)
    if display & SECANT2 > 0
        println("secant2: a = ", a, ", b = ", b, ", c = ", c)
    end
    @assert isfinite(c)
    # phic = phi(tmpc, c) # Replace
    phic, dphic = linefunc2!(df, x, s, c, xtmp, true)
    @assert isfinite(phic) && isfinite(dphic)
    push!(lsr, c, phic, dphic)
    ic = length(lsr)
    if satisfies_wolfe2(c, phic, dphic, phi0, dphi0, philim, τ₀, τ₁)
        if display & SECANT2 > 0
            println("secant2: first c satisfied Wolfe conditions")
        end
        return true, ic, ic
    end
    # iA, iB = update(phi, lsr, ia, ib, ic, philim)
    iA, iB = update2!(df, x, s, xtmp, lsr, ia, ib, ic, philim, display)
    if display & SECANT2 > 0
        println("secant2: iA = ", iA, ", iB = ", iB, ", ic = ", ic)
    end
    a = lsr.alpha[iA]
    b = lsr.alpha[iB]
    doupdate = false
    if iB == ic
        # we updated b, make sure we also update a
        c = secant2(lsr, ib, iB)
    elseif iA == ic
        # we updated a, do it for b too
        c = secant2(lsr, ia, iA)
    end
    if a <= c <= b
        if display & SECANT2 > 0
            println("secant2: second c = ", c)
        end
        # phic = phi(tmpc, c) # TODO: Replace
        phic, dphic = linefunc2!(df, x, s, c, xtmp, true)
        @assert isfinite(phic) && isfinite(dphic)
        push!(lsr, c, phic, dphic)
        ic = length(lsr)
        # Check arguments here
        if satisfies_wolfe2(c, phic, dphic, phi0, dphi0, philim, τ₀, τ₁)
            if display & SECANT2 > 0
                println("secant2: second c satisfied Wolfe conditions")
            end
            return true, ic, ic
        end
        iA, iB = update2!(df, x, s, xtmp, lsr, iA, iB, ic, philim, display)
    end
    if display & SECANT2 > 0
        println("secant2 output: a = ", lsr.alpha[iA], ", b = ", lsr.alpha[iB])
    end
    return false, iA, iB
end

# HZ, stages U0-U3
# Given a third point, pick the best two that retain the bracket
# around the minimum (as defined by HZ, eq. 29)
# b will be the upper bound, and a the lower bound
function update2!(df::AbstractNLPModel,
                 x::Array,
                 s::Array,
                 xtmp::Array,
                 lsr::LineSearchResults,
                 ia::Integer,
                 ib::Integer,
                 ic::Integer,
                 philim::Real,
                 display::Integer = 0)
    a = lsr.alpha[ia]
    b = lsr.alpha[ib]
    # Debugging (HZ, eq. 4.4):
    @assert lsr.slope[ia] < 0
    @assert lsr.value[ia] <= philim
    @assert lsr.slope[ib] >= 0
    @assert b > a
    c = lsr.alpha[ic]
    phic = lsr.value[ic]
    dphic = lsr.slope[ic]
    if display & UPDATE > 0
        println("update: ia = ", ia,
                ", a = ", a,
                ", ib = ", ib,
                ", b = ", b,
                ", c = ", c,
                ", phic = ", phic,
                ", dphic = ", dphic)
    end
    if c < a || c > b
        return ia, ib, 0, 0  # it's out of the bracketing interval
    end
    if dphic >= 0
        return ia, ic, 0, 0  # replace b with a closer point
    end
    # We know dphic < 0. However, phi may not be monotonic between a
    # and c, so check that the value is also smaller than phi0.  (It's
    # more dangerous to replace a than b, since we're leaving the
    # secure environment of alpha=0; that's why we didn't check this
    # above.)
    if phic <= philim
        return ic, ib, 0, 0  # replace a
    end
    # phic is bigger than phi0, which implies that the minimum
    # lies between a and c. Find it via bisection.
    return bisect2!(df, x, s, xtmp, lsr, ia, ic, philim, display)
end

# HZ, stage U3 (with theta=0.5)
function bisect2!{T}(df::AbstractNLPModel,
                    x::Array,
                    s::Array,
                    xtmp::Array,
                    lsr::LineSearchResults{T},
                    ia::Integer,
                    ib::Integer,
                    philim::Real,
                    display::Integer = 0)
    gphi = convert(T, NaN)
    a = lsr.alpha[ia]
    b = lsr.alpha[ib]
    # Debugging (HZ, conditions shown following U3)
    @assert lsr.slope[ia] < 0
    @assert lsr.value[ia] <= philim
    @assert lsr.slope[ib] < 0       # otherwise we wouldn't be here
    @assert lsr.value[ib] > philim
    @assert b > a
    while b - a > eps(b)
        if display & BISECT > 0
            println("bisect: a = ", a, ", b = ", b, ", b - a = ", b - a)
        end
        d = (a + b) / convert(T, 2)
        phid, gphi = linefunc2!(df, x, s, d, xtmp, true)
        @assert isfinite(phid) && isfinite(gphi)
        push!(lsr, d, phid, gphi)
        id = length(lsr)
        if gphi >= 0
            return ia, id # replace b, return
        end
        if phid <= philim
            a = d # replace a, but keep bisecting until dphib > 0
            ia = id
        else
            b = d
            ib = id
        end
    end
    return ia, ib
end

# Define one-parameter function for line searches
function linefunc2!(df::AbstractNLPModel,
                   x::Array,
                   s::Array,
                   alpha::Real,
                   xtmp::Array,
                   calc_grad::Bool)
    for i = 1:length(x)
        xtmp[i] = x[i] + alpha * s[i]
    end
    gphi = convert(eltype(s), NaN)
    if calc_grad
        # val = NLSolversBase.value_gradient!(df,xtmp)
        val = obj(df,xtmp)
        if isfinite(val)
            # gphi = vecdot(NLSolversBase.gradient(df), s)
            gphi = vecdot(grad(df,xtmp), s)
        end
    else
        val = obj(df,xtmp)
    end
    return val, gphi
end
