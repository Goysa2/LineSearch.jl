export ARC_generic_ls
function ARC_generic_ls(h :: AbstractLineFunction2,
                        h₀ :: Float64,
                        g₀ :: Float64,
                        g :: Array{Float64,1};
                        eps1 = 0.25,
                        eps2 = 0.75,
                        red = 0.5,
                        aug = 5.0,
                        Δ=1.0,
                        τ₀ :: Float64=1.0e-4,
                        τ₁ :: Float64=0.9999,
                        maxiterLS :: Int64=50,
                        verboseLS :: Bool=false,
                        direction :: String="Nwt",
                        check_param :: Bool = false,
                        debug :: Bool = false,
                        kwargs...)

    (τ₀ == 1.0e-4) || (check_param && warn("Different parameters"))

    #println("on rentre dans ARC τ₀ = $τ₀ τ₁ = $τ₁")

    (t,ht,gt,A_W,ɛa,ɛb)=init_ARC(h,h₀,g₀,g,τ₀,τ₁)
    if A_W
      # verboseLS && @printf("   iter   t        Δ\n");
      # verboseLS && @printf("%4d %9.2e %9.2e\n", 0,1.0,Δ);
      return (t, true, ht, 0, 0, false, h.f_eval, h.g_eval, h.h_eval)
    end

    # Specialized TR for handling non-negativity constraint on t
    # Trust region parameters

    iter = 0

    φ(t) = obj(h,t) - h₀ - τ₀*t*g₀  # fonction et
    dφ(t) = grad!(h,t,g) - τ₀*g₀    # dérivée

    if direction=="Nwt"
      ddφ(t) = hess(h,t)
    end

    φt = φ(t)

    dφt = dφ(t)

    ddφt = NaN

    if direction=="Nwt"
      ddφt = ddφ(t)
      #q(d) = φt + dφt*d + 0.5*ddφt*d^2
    elseif direction=="Sec" || direction=="SecA"
      seck=1.0
      #q(d)=φt + dφt*d + 0.5*seck*d^2
    end

    verboseLS && println("   ϵₐ = $ɛa ϵᵦ = $ɛb")


    admissible = false
    tired=iter>maxiterLS

    debug && PyPlot.figure(1)
    debug && PyPlot.scatter([t],[φt + h₀ + τ₀*t*g₀])

    verboseLS && @printf("   iter   t       φt        dφt        ddφt        Δ        Successful        dN\n");
    verboseLS && @printf("%4d %9.2e  %9.2e  %9.2e %9.2e  %9.2e\n", iter,t,φt,dφt,ddφt,Δ);

    while !(admissible | tired) #admissible: respecte armijo et wolfe, tired: nb d'itérations

        if direction=="Nwt"
          d=ARC_step_computation(ddφt,dφt,Δ; kwargs...)
        elseif direction=="Sec" || direction=="SecA"
          d=ARC_step_computation(seck,dφt,Δ; kwargs...)
        end

        # println("calcul d = $d")

        φtestTR = φ(t+d)
        dφtestTR= dφ(t+d)

        # println("avant calcul dφt = $dφt φt = $φt  ddφt = $ddφt d = $d φtestTR = $φtestTR dφtestTR = $dφtestTR")

        # test d'arrêt sur dφ
        if direction=="Nwt"
          (pred,ared,ratio)=pred_ared_computation(dφt,φt,ddφt,d,φtestTR,dφtestTR)
        elseif direction=="Sec" || direction=="SecA"
          (pred,ared,ratio)=pred_ared_computation(dφt,φt,seck,d,φtestTR,dφtestTR)
        end

        #verboseLS && println("ratio = $ratio eps1 = $eps1")

        if direction=="Nwt"
          tprec = t
          φtprec = φt
          dφtprec = dφt
          ddφtprec = ddφt
        elseif direction=="Sec"
          tprec = t
          dφtprec = dφt
        elseif direction=="SecA"
          tprec = t
          φtprec=φt
          dφtprec = dφt
        end

        if ratio < eps1  # Unsuccessful
          Δ=red*Δ
          iter += 1
          verboseLS && @printf("%4d %9.2e %9.2e  %9.2e  %9.2e  %9.2e %9.2e %7.2e\n", iter,t,φt,dφt,ddφt,Δ,0,d);
          # sleep(30)
          #print_with_color(:red,"!!! \n")
        else             # Successful

          if direction=="Nwt"
            (t,φt,dφt,ddφt)=Nwt_computation_ls(t, d , φtestTR, dφtestTR, h)
          elseif direction=="Sec"
            (t,φt,dφt,seck)=Sec_computation_ls(t, tprec, dφtprec, d, φtestTR,dφtestTR)
          elseif direction=="SecA"
            (t,φt,dφt,s,y,seck)=SecA_computation_ls(t, tprec, φtprec, dφtprec, d, φtestTR,dφtestTR)
          end

          if ratio > eps2
            Δ = aug*Δ
          end

          admissible = ((dφt>=ɛa) & (dφt<=ɛb)) # Wolfe, Armijo garanti par la
                                                  # descente
          debug && PyPlot.figure(1)
          debug && PyPlot.scatter([t],[φt + h₀ + τ₀*t*g₀])
          iter += 1
          tired = iter > maxiterLS
          verboseLS && @printf("%4d %9.2e %9.2e  %9.2e  %9.2e  %9.2e  %9.2e %7.2e \n", iter,t,φt,dφt,ddφt,Δ,1,d);
        end;
    end;

    # recover h
    ht = φt + h₀ + τ₀*t*g₀

    return return (t, true, ht, iter, 0, false, h.f_eval, h.g_eval, h.h_eval)  #pourquoi le true et le 0?

end
