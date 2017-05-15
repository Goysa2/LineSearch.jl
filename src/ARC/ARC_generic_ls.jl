export ARC_generic_ls
function ARC_generic_ls(h :: AbstractLineFunction,
                        h₀ :: Float64,
                        g₀ :: Float64,
                        g :: Array{Float64,1};
                        eps1 = 0.1,
                        eps2 = 0.7,
                        red = 0.15,
                        aug = 10,
                        Δ=1.0,
                        τ₀ :: Float64=1.0e-4,
                        τ₁ :: Float64=0.9999,
                        maxiter :: Int64=50,
                        verbose :: Bool=false,
                        direction :: String="Nwt",
                        kwargs...)

    #println("on est dans ARC_Nwt_ls")

    (t,ht,gt,A_W,ɛa,ɛb)=init_ARC(h,h₀,g₀,g,τ₀,τ₁)
    if A_W
      return (t,true,ht,0.0,0.0)
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

    if direction=="Nwt"
      ddφt = ddφ(0.0)
      #q(d) = φt + dφt*d + 0.5*ddφt*d^2
    elseif direction=="Sec" || direction=="SecA"
      seck=1.0
      #q(d)=φt + dφt*d + 0.5*seck*d^2
    end

    # test d'arrêt sur dφ
    # ɛa = (τ₁-τ₀)*g₀
    # ɛb = -(τ₁+τ₀)*g₀

    admissible = false
    tired=iter>maxiter
    verbose && @printf("   iter   t       φt        dφt        Δ\n");
    verbose && @printf(" %4d %9.2e  %9.2e  %9.2e %9.2e\n", iter,t,φt,dφt,Δ);

    while !(admissible | tired) #admissible: respecte armijo et wolfe, tired: nb d'itérations

        if direction=="Nwt"
          d=ARC_step_computation(ddφt,dφt,Δ)
        elseif direction=="Sec" || direction=="SecA"
          d=ARC_step_computation(seck,dφt,Δ)
        end

        φtestTR = φ(t+d)
        dφtestTR= dφ(t+d)
        # test d'arrêt sur dφ
        if direction=="Nwt"
          (pred,ared,ratio)=pred_ared_computation(dφt,φt,ddφt,d,φtestTR,dφtestTR)
        elseif direction=="Sec" || direction=="SecA"
          (pred,ared,ratio)=pred_ared_computation(dφt,φt,seck,d,φtestTR,dφtestTR)
        end

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
            verbose && @printf("U %4d %9.2e %9.2e  %9.2e  %9.2e %9.2e %9.2e\n", iter,t,φt,dφt,α,t+d,φtestTR);
        else             # Successful

            if direction=="Nwt"
              (t,φt,dφt,ddφt)=Nwt_computation_ls(t,d,φtestTR,h,dφ)
            elseif direction=="Sec"
              (t,φt,dφt,s,y,seck)=Sec_computation_ls(t,tprec, dφtprec, d, φtestTR,dφtestTR)
            elseif direction=="SecA"
              (t,φt,dφt,s,y,seck)=SecA_computation_ls(t, tprec, φtprec, dφtprec, d, φtestTR,dφtestTR)
            end

            if ratio > eps2
            Δ=aug*Δ
            end
            admissible = (dφt>=ɛa) & (dφt<=ɛb)  # Wolfe, Armijo garanti par la
                                                # descente
            verbose && @printf("S %4d %9.2e %9.2e  %9.2e  %9.2e\n", iter,t,φt,dφt,α);
        end;

        iter=iter+1
        tired=iter>maxiter
    end;

    # recover h
    ht = φt + h₀ + τ₀*t*g₀
    return (t,true, ht, iter,0)  #pourquoi le true et le 0?

end