export Biss_Nwt_ls
function Biss_Nwt_ls(h :: AbstractLineFunction,
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
 ddφ(t) = hess(h,t)

 iter=0

 dφt=dφ(t)
 dφa=dφ(ta)
 dφb=dφ(tb)

 ɛa = (τ₁-τ₀)*g₀
 ɛb = -(τ₁+τ₀)*g₀

 admissible=false
 nftot=h.nlp.counters.neval_obj+h.nlp.counters.neval_grad+h.nlp.counters.neval_hprod
 tired=nftot > max_eval

 verbose && @printf(" iter        ta        tb         dφa        dφb        \n")
 verbose && @printf(" %7.2e %7.2e  %7.2e  %7.2e  %7.2e\n", iter,tqnp,t,dφa,dφb)

 while !(admissible | tired)

   ddφt=ddφ(t)
   dN=-dφt/ddφt

   if ((tp-t)*dN>0) & (dN/(tp-t)<γ)
     tplus = t + dN
     #hplus = obj(h, tplus)
     dφplus= dφ(tplus)
     verbose && println("N")
   else
     tplus = (t+tp)/2
     #hplus = obj(h, tplus)
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

   dφt=dφplus

   iter=iter+1
   admissible = (dφt>=ɛa) & (dφt<=ɛb)
   nftot=h.nlp.counters.neval_obj+h.nlp.counters.neval_grad+h.nlp.counters.neval_hprod
   tired=nftot > max_eval

   verbose && @printf(" %7.2e %7.2e  %7.2e  %7.2e  %7.2e\n", iter,tqnp,t,dφa,dφb)
 end

 ht = φ(t) + h₀ + τ₀*t*g₀
 return (t,true,ht,nftot)
end
