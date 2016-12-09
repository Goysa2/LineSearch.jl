export Biss_Cub_ls
function Biss_Cub_ls(h :: AbstractLineFunction,
                   h₀ :: Float64,
                   g₀ :: Float64,
                   g :: Array{Float64,1};
                   τ₀ :: Float64=1.0e-4,
                   τ₁ :: Float64=0.9999,
                   max_eval :: Int64=100,
                   verbose :: Bool=false)

inc0=g[1]

(ta,tb, admissible, ht,iter)=trouve_intervalle_ls(h,h₀,g₀,inc0,g)
if admissible==true
  nftot=h.nlp.counters.neval_obj+h.nlp.counters.neval_grad+h.nlp.counters.neval_hprod
  return (ta,true, ht,nftot)
end

g=[0.0]

 γ=0.8
 t=ta
 tp=tb
 tqnp=tb
 iter=0

 φ(t) = obj(h,t) - h₀ - τ₀*t*g₀  # fonction et
 dφ(t) = grad(h,t) - τ₀*g₀    # dérivée


 iter=0

 φt=φ(t)
 φtm1=φ(tqnp)
 dφt=dφ(t)
 dφtm1=dφ(tqnp)

 dφa=dφ(ta)
 dφb=dφ(tb)

 ɛa = (τ₁-τ₀)*g₀
 ɛb = -(τ₁+τ₀)*g₀
 admissible=false
 nftot=h.nlp.counters.neval_obj+h.nlp.counters.neval_grad+h.nlp.counters.neval_hprod
 tired =  nftot>max_eval

 verbose && @printf(" iter        ta        tb         dφa        dφb        \n")
 verbose && @printf(" %7.2e %7.2e  %7.2e  %7.2e  %7.2e\n", iter,ta,tb,dφa,dφb)

 while !(admissible | tired)

   s=t-tqnp
   y=dφt-dφtm1

   α=-s
   z=dφt+dφtm1+3*(φt-φtm1)/α
   discr=z^2-dφt*dφtm1
   denom=dφt+dφtm1+2*z
   if (discr>0) & (abs(denom)>eps(Float64))
     #si on peut on utilise l'interpolation cubique
     w=sqrt(discr)
     dN=-s*(dφt+z+sign(α)*w)/(denom)
   else #on se rabat sur une étape de sécante
     dN=-dφt*s/y
   end

   if ((tp-t)*dN>0) & (dN/(tp-t)<γ)
     tplus = t + dN
     φplus = obj(h, tplus)
     dφplus= dφ(tplus)
     verbose && println("N")
   else
     tplus = (t+tp)/2
     φplus = obj(h, tplus)
     dφplus = dφ(tplus)
     verbose && println("B")
   end

   if t>tp
     if dφplus<0
       tp=t
       tqnp=t
       t=tplus
     else
       tqnp=t
       t=tplus
     end
   else
     if dφplus>0
       tp=t
       tqnp=t
       t=tplus
     else
       tqnp=t
       t=tplus
     end
   end

   φtm1=φt
   dφtm1=dφt
   φt=φplus
   dφt=dφplus

   iter=iter+1
   admissible = (dφt>=ɛa) & (dφt<=ɛb)
   nftot=h.nlp.counters.neval_obj+h.nlp.counters.neval_grad+h.nlp.counters.neval_hprod
   tired=nftot > max_eval

   verbose && @printf(" %7.2e %7.2e  %7.2e  %7.2e  %7.2e\n", iter,ta,tb,dφa,dφb)
 end

 # t=(ta+tb)/2


 ht = φ(t) + h₀ + τ₀*t*g₀
 return (t,true,ht,nftot)
end
