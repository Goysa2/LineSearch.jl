export Biss_Cub_ls
function Biss_Cub_ls(h :: LineModel, stop_ls :: LS_Stopping;
                     f_meta = LS_Function_Meta(),
                     h₀ = obj(h, 0.0), g₀ = grad(h, 0.0),
                     φ_dφ :: Function = (x, y) -> phi_dphi(x, y),
                     γ :: Float64 = 0.8, verboseLS :: Bool = false,
                     kwargs...)

  state = stop_ls.current_state

  t = 1.0
  update!(state, x = t)
  φt, dφt = φ_dφ(h, state; kwargs...)
  tqnp = 0.0; φtqnp = 0.0; dφtqnp = h₀ * (1.0 + 0.01)
  ht = obj(h, t); gt = grad(h, t)
  OK = update_and_start!(stop_ls, ht = ht, gt = gt, h0 = h₀, g0 = g₀)

  (ta, φta, dφta, tb, φtb, dφtb) = find_interval_ls(h, stop_ls,
                                                    verboseLS = verboseLS;
                                                    kwargs...)
  verboseLS && println("ta = $ta tb = $tb")

  t = ta
  tp = tb
  tqnp = tb

  iter = 0

  dφt = dφta; dφa = dφta; dφb = dφtb;

  verboseLS && @printf(" iter     tqnp        t         dφtqnp     dφt \n")
  verboseLS && @printf(" %4d %7.2e  %7.2e  %7.2e  %7.2e\n",
                        iter, tqnp, t, dφa, dφb)

  while !OK             # admissible: satisfies Armijo & Wolfe,
                        # tired: exceeds maximum number of iterations
    s = t - tqnp; y = dφt - dφtqnp; α = -s;
    z = dφt + dφtqnp + 3.0 * (φt - φtqnp) / α
    discr = z ^ 2 - dφt * dφtqnp; denom = dφt + dφtqnp + 2.0 * z
    if discr > 0.0 && abs(denom) > eps(Float64)
      # use cubic interpolation if possible
      w = sqrt(discr)
      dN = -s * (dφt + z + sign(α) * w) / (denom)
    else # we do secant interpolation
      dN = -dφt * s / y
    end

    if ((tp - t) * dN > 0.0) && (dN / (tp - t) < γ)
      tplus = t + dN
      verboseLS && println("N")
    else
      tplus = (t + tp) / 2
      verboseLS && println("B")
    end
    update!(state, x = tplus)
    φplus, dφplus = φ_dφ(h, state; kwargs...)

    if t > tp
      if dφplus < 0.0
        tp = t
        tqnp = t
      else
        tqnp = t
      end
    else
      if dφplus > 0.0
        tp = t
        tqnp = t
      else
        tqnp = t
      end
    end

    t = tplus
    dφtqnp = dφt
    φtqnp = φt
    dφt = dφplus

    iter += 1
    OK = update_and_stop!(stop_ls, ht = obj(h, t), gt = grad(h, t))

    verboseLS && @printf(" %4d %7.2e  %7.2e  %7.2e  %7.2e\n",
                          iter, tqnp, t, dφtqnp, dφt)
  end

  return (stop_ls.current_state, stop_ls.meta.optimal)
end
