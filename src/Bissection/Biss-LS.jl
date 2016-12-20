export Biss_ls
function Biss_ls(h :: AbstractLineFunction,
                 h₀ :: Float64,
                 g₀ :: Float64,
                 g :: Array{Float64,1};
                 τ₀ :: Float64=1.0e-4,
                 τ₁ :: Float64=0.9999,
                 maxiter :: Int=50,
                 verbose :: Bool=false)

    t = 1.0
    ht = obj(h,t)
    gt = grad!(h, t, g)
    if Armijo(t,ht,gt,h₀,g₀,τ₀) && Wolfe(gt,g₀,τ₁)
      return (t, true, ht, 0,0)
    end


    (ta,tb)=trouve_intervalle_ls(h,h₀,g₀,g)
    #println("a la sorti de trouve_intervalle_ls ta=",ta," tb=",tb)
    φ(t) = obj(h,t) - h₀ - τ₀*t*g₀  # fonction et
    dφ(t) = grad!(h,t,g) - τ₀*g₀    # dérivée

    tp=(ta+tb)/2

    iter=0

    # test d'arrêt sur dφ
    ɛa = (τ₁-τ₀)*g₀
    ɛb = -(τ₁+τ₀)*g₀

    admissible = false
    tired=iter > maxiter
    verbose && @printf("   iter   ta       tb        tp        φp        dφp\n");
    verbose && @printf(" %4d %9.2e %9.2e  %9.2e  %9.2e %9.2e\n", iter,ta,tb,tp,φp,dφp);

    while !(admissible | tired) #admissible: respecte armijo et wolfe, tired: nb d'itérations
      #println("on est dans while \n")
      tp=(ta+tb)/2
      #println("tp=",tp)
      dφp=dφ(tp)

      if dφp<=0
        ta=tp
        dφa=dφp
      else
        tb=tp
        dφb=dφp
      end

      iter=iter+1
      admissible = (dφp>=ɛa) & (dφp<=ɛb)
      # if admissible==true
      #   println("on déclare topt")
      #   topt=tp
      # end
      tired=iter>maxiter

      verbose && @printf(" %4d %9.2e %9.2e  %9.2e  %9.2e %9.2e\n", iter,ta,tb,tp,φp,dφp);
    end;

    #println("après le while \n")
    #println("ta=",ta," tb=",tb)

    ht = φ(tp) + h₀ + τ₀*tp*g₀
    #println("on a ht \n")
    return (tp,false, ht, iter,0)  #pourquoi le true et le 0?
end
