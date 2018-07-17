kernelopts(assertlevel=2): # be strict on all assertions while testing
kernelopts(opaquemodules=false): # allow testing of internal routines
if not (NewSLO :: `module`) then
  WARNING("loading NewSLO failed");
  `quit`(3);
end if;

with(Hakaru):
with(NewSLO):
with(Partition):

# covers primitive constructs
model1 :=
  Bind(Gaussian(0,1), x,
  Bind(Msum(Ret(0),Weight(1,Lebesgue(-infinity,infinity))), y,
  Ret(1/exp(x^2+y^2)))):

# simplifies to
model1s :=
  Bind(Gaussian(0,1), x,
  Msum(Ret(exp(-x^2)),
       Bind(Lebesgue(-infinity,infinity), y,
       Ret(exp(-(x^2+y^2)))))):

CodeTools[Test](value(integrate(model1,z->z)), (sqrt(Pi)+1)/sqrt(3), equal,
  label="primitive constructs + integrate + value");

TestHakaru(model1, model1s, label = "primitive constructs simplification");

# Unknown measures -- no changes
u1 := Bind(m, x, Ret(x^2)):
u2 := Bind(Gaussian(0,1), x, m(x)):

TestHakaru(u1, label = "binding unknown m");
TestHakaru(u2, u2, label = "sending to unknown m");

# hygiene for Bind
TestHakaru(Bind(Bind(Uniform(0,1),x,Ret(x^2)),y,Ret(x^3)),
           Ret(x^3),
           label = "hygiene for Bind");

# example with an elaborate simplifier to do reordering of
# integration, which in turn integrates out a variable
model3 := Bind(Gaussian(0,1),x,Gaussian(x,1)):

TestHakaru(model3, Gaussian(0,sqrt(2)),
 simp = (lo -> subsindets(lo, 'specfunc(Int)',
  i -> subsindets(IntegrationTools[CollapseNested](
                  IntegrationTools[Combine](i)), 'Int(anything,list)',
  i -> subsop(0=int, applyop(ListTools[Reverse], 2, i))))),
  label = "use simplifier to integrate out variable");

TestHakaru(Bind(GammaD(1,1),lambda,PoissonD(lambda)), NegativeBinomial(1,1/2),
           label = "integrate out GammaD with PoissonD likelihood to Geometric");
TestHakaru(Bind(GammaD(r,1/(1/p-1)),lambda,PoissonD(lambda)),
           NegativeBinomial(r,p),
           ctx = [0<p,p<1],
           label = "integrate out GammaD with PoissonD likelihood to"
                   " NegativeBinomial");

# Kalman filter; note the parameter + assumption
module()
  local y, kalman;
  kalman :=
    Bind(Gaussian(0,1),x,Weight(NewSLO:-density[Gaussian](x,1)(y),Ret(x))):
  TestHakaru(kalman,
    Weight(exp(-y^2/4)/2/sqrt(Pi),Gaussian(y/2,1/sqrt(2))),
    label = "Kalman filter", ctx = [y::real]);
end module:

# piecewise
model4 :=
  Bind(Gaussian(0,1),x,
  Bind(piecewise(x<0,Ret(0),x>4,Ret(4),Ret(x)),y,
  Ret(y^2))):
model4s := { Bind(Gaussian(0,1),x,piecewise(x<0,Ret(0),4<x,Ret(16),
  0<x and x<4, Ret(x^2))) ,
  Bind(Gaussian(0,1),`x`,piecewise(`x` < 0,Ret(0),4 < `x`,Ret(16),
                                   0 <= `x` and `x` <= 4,Ret(`x`^2))),
  Bind(Gaussian(0,1),x,piecewise(x < 0,Ret(0),4 < x,Ret(16),Ret(x^2)))
 }:

TestHakaru(model4, model4s, label = "piecewise test");
sliced :=
  Weight(exp(-lu),
  Bind(Gaussian(0,1), x,
  Weight(1/exp(-x^2/2),
  piecewise(exp(-lu) < exp(-x^2/2), piecewise(0<exp(-lu), Ret(x)))))):
sliceds :=
  Weight(2*sqrt(lu)*exp(-lu)/sqrt(Pi),
  Uniform(-sqrt(2*lu),sqrt(2*lu))):
TestHakaru(sliced, sliceds, label = "slice sampling", ctx = [lu>0]);
module()
  local d, m, uMax, kb, result;
  for d in [Gaussian(0,1), GammaD(1,1)] do
    m := Bind(d, x,
              piecewise(And(0<u, u<density[op(0,d)](op(d))(x)),
              Weight(1/density[op(0,d)](op(d))(x),
              Ret(x)))):
    uMax := maximize(density[op(0,d)](op(d))(x), x):
    kb := KB:-assert(And(0<u, u<uMax), KB:-empty):
    result := fromLO(improve(toLO(m), _ctx=kb), _ctx=kb):
    CodeTools[Test](
      type(result, 'Weight(anything, Uniform(anything, anything))'),
      true,
      label = sprintf("slice sampling %a", d)):
  end do;
end module:

# test with uniform.  No change without simplifier, eliminates it with
# call to value.
introLO_opt := {
  Bind(Uniform(0,1),x,
  Bind(Uniform(0,1),y,
  piecewise(x<y,Ret(true),x>=y,Ret(false)))),
  Bind(Uniform(0,1),x,
  Bind(Uniform(0,1),y,
  piecewise(x<y,Ret(true),Ret(false)))),
  Bind(Uniform(0,1),xH2,Bind(Uniform(0,1),yF2,
    piecewise(xH2 < yF2,Ret(true),Not(xH2 < yF2),Ret(false))))}:
introLO := op(1,introLO_opt):
introLOs := Msum(Weight(1/2, Ret(false)), Weight(1/2, Ret(true))):

TestHakaru(introLO, introLO_opt, simp = (x -> x),
           label = "2 uniform - no change");
TestHakaru(introLO, introLOs, simp = ((x,y) -> value(x)),
           label = "2 uniform + value = elimination");
TestHakaru(introLO, introLOs, label = "2 uniform + simplifier  elimination");

# a variety of other tests
TestHakaru(LO(h,(x*applyintegrand(h,5)+applyintegrand(h,3))/x),
           Weight(1/x, Msum(Weight(x, Ret(5)), Ret(3))),
           label="Weight of recip of sum");
TestHakaru(Bind(Gaussian(0,1),x,Weight(x,Msum())), Msum(),
           label="Bind into Reject is Reject");
TestHakaru(Bind(Uniform(0,1),x,Weight(x^alpha,Ret(x))),
           Weight(1/(1+alpha),BetaD(1+alpha,1)),
           label="BetaD recog. [2] (with scalar weight)");
TestHakaru(Bind(Uniform(0,1),x,Weight(x^alpha*(1-x)^beta,Ret(x))),
           Weight(Beta(1+alpha,1+beta),BetaD(1+alpha,1+beta)),
           label="BetaD recog. [3] (with Beta weight)");
TestHakaru(Bind(Uniform(0,1),x,Weight((1-x)^beta,Ret(x))),
           Weight(1/(1+beta),BetaD(1,1+beta)),
           label="BetaD recog. [4] (with scalar weight)");

# tests that basic densities are properly recognized
# continuous
TestHakaru(Bind(Uniform(0,1),x,Weight(x*2,Ret(x))), BetaD(2,1),
  label="BetaD(2,1) recog");
TestHakaru(BetaD(alpha,beta), label="BetaD recog.");
TestHakaru(GammaD(a,b), label="GammaD recog.", ctx = [a>0,b>0]);
TestHakaru(GammaD(1/2,2), label="GammaD(1/2,2) recog.");
TestHakaru(LO(h, int(exp(-x/2)*applyintegrand(h,x),x=0..infinity)),
           Weight(2,GammaD(1,2)), label="GammaD(1,2) recog.");
TestHakaru(LO(h, int(x*exp(-x/2)*applyintegrand(h,x),x=0..infinity)),
           Weight(4,GammaD(2,2)), label="GammaD(2,2) recog.");
TestHakaru(Bind(Lebesgue(-infinity,infinity), x, Weight(1/x^2, Ret(x))),
           label="Lebesgue roundtrip");
TestHakaru(Cauchy(loc,scale), ctx = [scale>0], label="Cauchy recog.");
TestHakaru(StudentT(nu,loc,scale), ctx=[nu>0,scale>0],
           label = "StudentT recog.");
TestHakaru(StudentT(1,loc,scale),Cauchy(loc,scale), ctx = [scale>0],
  label = "StudentT(1,loc,scale) recog.");
# discrete
TestHakaru(Weight(1/26,Counting(17,43)), label="Discrete uniform recog.");
TestHakaru(NegativeBinomial(r,1-p-q), label="NegativeBinomial recog.");
TestHakaru(Poisson(foo/exp(bar)), label="Poisson recog.");

# how far does myint get us?
TestHakaru(
  Bind(Uniform(0,1),x,Weight(x,Ret(Unit))),
  Weight(1/2,Ret(Unit)),
  label = "eliminate Uniform");

# just the front-end is already enough to get this
TestHakaru(
  Bind(Weight(1/2,Ret(Unit)),x,Ret(Unit)),
  Weight(1/2, Ret(Unit)),
  label = "integrate at work");

# and more various
model_exp := Bind(Uniform(-1,1),x,Ret(exp(x))):
TestHakaru(model_exp, model_exp, label = "uniform -1..1 into exp");
TestHakaru(
  LO(h, IntegrationTools[Expand](Int((1+y)*applyintegrand(h,y),y=0..1))),
  Msum(Uniform(0,1), Weight(1/2,BetaD(2,1))), label="Uniform + BetaD");
TestHakaru(
  Bind(Uniform(0,1),x,Bind(
    LO(h, IntegrationTools[Expand](Int((1+y)*applyintegrand(h,y),y=0..1))),
    y,Ret([x,y]))),
  { Weight(3/2,Bind(Uniform(0,1),x,
                    Msum(Weight(2/3,Bind(Uniform(0,1),y,Ret([x,y]))),
                         Weight(1/3,Bind(BetaD(2,1),y,Ret([x,y])))))) ,
    Msum(           Bind(Uniform(0,1),x98,Bind(Uniform(0,1),y,Ret([x98, y]))),
         Weight(1/2,Bind(Uniform(0,1),x98,Bind(BetaD(2,1),y,Ret([x98, y]))))) }
           , label="Uniform + BetaD [2]");

# easy-easy-HMM
eeHMM := Bind(GammaD(1,1),t,
                 Weight(NewSLO:-density[Gaussian](0,1/sqrt(t))(a),
                 Ret(t))):
ees := Weight(1/(a^2+2)^(3/2), GammaD(3/2, 1/((1/2)*a^2+1))):


TestHakaru(eeHMM, ees, ctx = [a::real], label = "easy-easy-HMM");

# from an email conversation on Sept. 11
model6 := Bind(Gaussian(0,1),x, piecewise(x>4,Ret(4),Ret(x))):
TestHakaru(model6, model6, label = "clamped Gaussian");

# and now models (then tests) taken from Tests.RoundTrip
t1 := Bind(Uniform(0, 1), a0, Msum(Weight(a0, Ret(Unit)))):
t2 := BetaD(1,1):
t2s := Uniform(0, 1):
t3 := Gaussian(0,10):
t4 := Bind(BetaD(1, 1), a0,
      Bind(Msum(Weight(a0, Ret(true)),
                Weight((1-a0), Ret(false))), a1,
      Ret(Pair(a0, a1)))):
t4s := {Bind(Uniform(0, 1), a0,
       Msum(Weight(a0, Ret(Pair(a0, true))),
            Weight((1+(a0*(-1))), Ret(Pair(a0, false))))),
        Msum(Weight(1/2,Bind(BetaD(1,2),a0,Ret(Pair(a0,false)))),
             Weight(1/2,Bind(BetaD(2,1),a0,Ret(Pair(a0,true)))))}:
t5 := Bind(Msum(Weight((1/2), Ret(Unit))), a0, Ret(Unit)):
t5s := Weight((1/2), Ret(Unit)):
t6 := Ret(5):
t7 := Bind(Uniform(0, 1), a0,
  Bind(Msum(Weight((a0+1), Ret(Unit))), a1, Ret((a0*a0)))):
t7s := Bind(Uniform(0,1),a3,Weight(a3+1,Ret(a3^2))):
t7n := Bind(Uniform((-1), 0), a0,
  Bind(Msum(Weight((a0+1), Ret(Unit))), a1, Ret((a0*a0)))):
t7ns := Bind(Uniform(-1,0),a3,Weight(a3+1,Ret(a3^2))):
t8 := Bind(Gaussian(0, 10), a0, Bind(Gaussian(a0, 20), a1, Ret(Pair(a0, a1)))):
t9 := Bind(Lebesgue(-infinity,infinity), a0,
  Bind(Msum(Weight(piecewise(And((3<a0), (a0<7)), (1/2), 0), Ret(Unit))),
       a1, Ret(a0))):
t9a := Bind(Lebesgue(-infinity,infinity), a0,
  piecewise(3>=a0, Msum(), a0>=7, Msum(), Weight(1/2, Ret(a0)))):
t9s := Weight(2, Uniform(3,7)):

#t23, "bayesNet", to show exact inference.  Original used bern, which
# is here expanded in terms of MSum.
t23 :=
  Bind(Msum(Weight((1/2), Ret(true)), Weight((1-(1/2)), Ret(false))), a0,
  Bind(Msum(Weight(piecewise(a0 = true, (9/10), (1/10)), Ret(true)),
            Weight((1-piecewise(a0 = true, (9/10), (1/10))), Ret(false))), a1,
  Bind(Msum(Weight(piecewise(a0 = true, (9/10), (1/10)), Ret(true)),
            Weight((1-piecewise(a0 = true, (9/10), (1/10))), Ret(false))), a2,
  Ret(Pair(a1, a2))))):
t23s := Msum(Weight(41/100,Ret(Pair(true,true))),
             Weight(9/100,Ret(Pair(true,false))),
             Weight(9/100,Ret(Pair(false,true))),
             Weight(41/100,Ret(Pair(false,false)))):

# to exercise myint_pw
model_pw := Bind(Uniform(0,4), x,
  piecewise(x<1, Ret(x), x<2, Ret(2*x), x<3, Ret(3*x), Ret(5*x))):
model_pw1 := { Bind(Uniform(0,4), x,
  piecewise(x<1, Ret(x), x<2, Ret(2*x), x<3, Ret(3*x), 3<x, Ret(5*x))),
               Bind(Uniform(0,4),`x`,
  piecewise(x<1, Ret(x),
            1<=x and x<2, Ret(2*x),
            2<=x and x<3, Ret(3*x),
            3 <= x,Ret(5*x)))
}:
model_pw2 := Bind(Uniform(0,4), x, Weight(piecewise(x<1, 1, x<2, 2, x<3, 3, 5),
                                          Ret(x))):
model_pw3 := Bind(Uniform(0,4), x,
  piecewise(x<1, Ret(x), x<2, Weight(2,Ret(x)), x<3, Weight(3,Ret(x)), x>=3,
            Weight(5,Ret(x)))):
model_pw3_r := { Bind(Uniform(0,4), x,
  piecewise(x<1, Ret(x), x<2, Weight(2,Ret(x)), x<3, Weight(3,Ret(x)), x>=3,
            Weight(5,Ret(x)))) ,
  Bind(Uniform(0,4), x,
  piecewise(x<1, Ret(x), x<2, Weight(2,Ret(x)), x<3, Weight(3,Ret(x)), x>3,
            Weight(5,Ret(x)))) ,
               Bind(Uniform(0,4),x,
  piecewise(x < 1,Ret(x),1 <= x and x < 2,Weight(2,Ret(x)),2 <= x and x < 3,
            Weight(3,Ret(x)),3 <= x,Weight(5,Ret(x))))
}:
model_pw5 := Bind(Uniform(0,4), x,
                  Weight(piecewise(x<1, 1, x<2, 2, x<3, 3, x>=3, 5),Ret(x))):
TestHakaru(model_pw , model_pw1, label = "multi-branch choice");
TestHakaru(model_pw3, model_pw3_r, label = "fake multi-branch weight");
TestHakaru(model_pw2, model_pw5, label = "proper multi-branch weight");

fake_pw1 := Bind(Uniform(1,3),x, piecewise(0 < x, Msum(), Ret(x))):
fake_pw2 := Bind(Uniform(1,3),x, piecewise(x < 0, Ret(x), Msum())):
TestHakaru(fake_pw1, Msum(), label = "fake piecewise 1"):
TestHakaru(fake_pw2, Msum(), label = "fake piecewise 2"):

# t43 without the explicit lam
t43 := piecewise(x0=true, Uniform(0, 1), Bind(BetaD(1, 1), a1, Ret(a1))):
t43s := Uniform(0, 1):

t80 := Bind(GammaD(1, 1), a0, Gaussian(0, a0)):

t57 := Msum(Weight(1, Partition(t < 1, Ret(Datum(unit, Inl(Done))), Msum() )),
            Weight(1, Partition(0 < t, Ret(Datum(unit, Inl(Done))), Msum() ))):
t57s := Partition( And(0 < t, t < 1), Weight(2, Ret(Datum(unit, Inl(Done)))),
                   Ret(Datum(unit, Inl(Done))) ):

TestHakaru(t1, t5s, label = "t1");
TestHakaru(t2, t2s, label = "t2");
TestHakaru(t3, t3, label = "t3");
TestHakaru(t4, t4s, label = "t4");
TestHakaru(t5, t5s, label = "t5");
TestHakaru(t6, t6, label = "t6");
TestHakaru(t7, t7s, label = "t7");
TestHakaru(t7n, t7ns, label = "t7n");
TestHakaru(t8, t8, label = "t8");
TestHakaru(t9, t9s, label = "t9");
TestHakaru(t9a, t9s, label = "t9a");
TestHakaru(t23, t23s, label = "t23");
TestHakaru(t43, t43s, label = "t43"):
TestHakaru(t57, t57s, label = "t57"):
TestHakaru(t80, t80, label = "t80");

## "clamp" tests based on https://github.com/hakaru-dev/hakaru/issues/60
module()
  local kb, clamp_t, clamp_r, q;
  kb := [y::real]:
  clamp_t :=
    Bind(Gaussian(0,1),x,
         Partition(And(0<y,y<density[Gaussian](0,1)(x)),
                   Weight(density[Uniform](0,density[Gaussian](0,1)(x))(y),
                          Ret(x)),
                   Msum())):
  clamp_r := {seq(
    Partition(And(0<y, y<density[Gaussian](0,1)(0)),
              Weight(2 * sqrt(-ln(2)-ln(Pi)-2*ln(y)),
                     Uniform(-sqrt(-ln(2)-ln(Pi)-2*ln(y)),
                             sqrt(-ln(2)-ln(Pi)-2*ln(y)))),
              eval(q),Msum()),
    q=['NULL', Or(0>=y, y>=density[Gaussian](0,1)(0))])}:
  TestHakaru( clamp_t, clamp_r, ctx=kb,
              label="clamp condition to move it out of integral" ):
end module:

module()
  local kb, clamp_t, clamp_r;
  kb := [ly::real]:
  clamp_t :=
    Bind(Gaussian(0,1),x,
         piecewise(And(exp(ly)<density[Gaussian](0,1)(x)),
                   Weight(density[Uniform](0,density[Gaussian](0,1)(x))(exp(ly)),
                          Ret(x)),
                   Msum())):

  clamp_r :=
    Partition(ly < -(1/2)*ln(2)-(1/2)*ln(Pi),
              Weight(2*(-ln(2)-ln(Pi)-2*ly)^(1/2),
                     Uniform(-(-ln(2)-ln(Pi)-2*ly)^(1/2),
                             (-ln(2)-ln(Pi)-2*ly)^(1/2))),
              Msum()):
  TestHakaru( clamp_t, clamp_r, ctx=kb,
              label="clamp condition to move it out of integral"
                    " (ln coordinate)" ):
end module:

###
# From disintegration paper
disint1 :=
Bind(Lebesgue(-infinity,infinity),y, Weight(piecewise(0<y and y<1, 1, 0),
                                            Weight(y/2, Ret(y)))):

TestHakaru(disint1, Weight(1/4,BetaD(2,1)), label="minor miracle");

ind1  := Bind(Uniform(0,1),x,
              Weight(piecewise(x>0,1,0),
                     Weight(piecewise(x>1/2,0,1),
                            Weight(piecewise(0<x,1,0), Ret(x))))):
ind1s := Weight(1/2, Uniform(0,1/2)):
ind2  := Bind(Lebesgue(-infinity,infinity),x,
              Weight(piecewise(x<0,0,x<1,x,0), Ret(x))):
ind2s := Weight(1/2, BetaD(2,1)):
ind3  := Bind(Uniform(0,1),x, Weight(piecewise(1<x and x<0,1,0), Ret(x))):
ind3s := Msum():
TestHakaru(ind1, ind1s, label="exponentiated indicator");
TestHakaru(ind2, ind2s, label="negated and conjoined indicator");
TestHakaru(ind3, ind3s, label="bounds ordering");
TestHakaru(Msum(ind1,ind2), Msum(ind1s,ind2s), label="simplify under sum");
TestHakaru(piecewise(c>0,ind1,ind2), piecewise(c>0,ind1s,ind2s),
           label="simplify under piecewise");

# test how banish handles piecewise
m1 := Uniform(0,1):
m2 := BetaD(2,1):
m3 := BetaD(1,2):
bp := proc() Bind(Gaussian(0,1), x,
             Bind(Gaussian(0,1), y,
             piecewise(_passed))) end proc:
TestHakaru(bp(x>y, m1, m2         ),
           Msum(Weight(1/2, m1), Weight(1/2, m2)                 ),
           label="banish piecewise 1");
TestHakaru(bp(x>0, m1, m2         ),
           Msum(Weight(1/2, m1), Weight(1/2, m2)                 ),
           label="banish piecewise 2");
TestHakaru(bp(y>0, m1, m2         ),
           Msum(Weight(1/2, m1), Weight(1/2, m2)                 ),
           label="banish piecewise 3");
TestHakaru(bp(x>y, m1, x>0, m2, m3),
           Msum(Weight(1/2, m1), Weight(1/8, m2), Weight(3/8, m3)),
           label="banish piecewise 4");
TestHakaru(bp(x>0, m1, x>y, m2, m3),
           Msum(Weight(1/2, m1), Weight(1/8, m2), Weight(3/8, m3)),
           label="banish piecewise 5");
TestHakaru(bp(y>x, m1, y>0, m2, m3),
           Msum(Weight(1/2, m1), Weight(1/8, m2), Weight(3/8, m3)),
           label="banish piecewise 6");
TestHakaru(bp(y>0, m1, y>x, m2, m3),
           Msum(Weight(1/2, m1), Weight(1/8, m2), Weight(3/8, m3)),
           label="banish piecewise 7");

# Simplify is not yet idempotent
TestHakaru(Bind(Uniform(0,1), x, Weight(x, Uniform(0,x))),
           Weight(1/2, BetaD(1, 2)),
          label="Uniform[x] into Weight x is BetaD");

# Test for change of variables; see Tests/Relationships.hs
# t1
# cv1 := Bind(Gaussian(mu, sigma), x, Ret((x-mu)/sigma)):
# cv1s := Gaussian(0,1):
# TestHakaru(cv1, cv1s, ctx = [sigma>0], label = "renormalize Gaussian");

# t28
# cv2 := Bind(BetaD(a,b), x, Ret(1-x)):
# cv2s := BetaD(b,a):
# TestHakaru(cv2, cv2s, ctx=[a>0,b>0], label = "swap BetaD");

unk_pw := Bind(m, y, Bind(Gaussian(0,1), x, piecewise(x<0, Ret(-x), Ret(x)))):
unk1   := Bind(Gaussian(0,1), x, Bind(m, y, Bind(Gaussian(x,1), z, Ret([y,z])))):
unk1s  := Bind(m, y, Bind(Gaussian(0,sqrt(2)), z, Ret([y,z]))):
unk2   := Bind(Gaussian(0,1), x, Bind(Gaussian(x,1), z, Bind(m, y, Ret([y,z])))):
unk2s  := Bind(Gaussian(0,sqrt(2)), z, Bind(m, y, Ret([y,z]))):
unk3   := Bind(Gaussian(0,1), x,
               Bind(m(x), y,
                    Bind(Gaussian(x,1), z,
                         Ret([y,z])))):
unk4   := Bind(Gaussian(0,1), x,
               Bind(Gaussian(x,1), z,
                    Bind(m(x), y,
                         Ret([y,z])))):
TestHakaru(unk_pw, unk_pw, label="Don't simplify Integrand willy-nilly");
TestHakaru(unk1, unk1s, label="Banish into Integrand 1");
TestHakaru(unk2, unk2s, label="Banish into Integrand 2");
TestHakaru(unk3, unk3, label="Banish into Integrand 3");
TestHakaru(unk4, unk4, label="Banish into Integrand 4");

# Disintegration of easierRoadmapProg1 -- variables to be integrated out
rmProg1 := Msum(Weight(1, Msum(Weight(1, Msum(Weight(1, Msum(Weight(1, Bind(Lebesgue(-infinity,infinity), a4, Msum(Weight(1, Msum(Weight(1, Bind(Lebesgue(-infinity,infinity), a5, Msum(Weight(1, Bind(Lebesgue(-infinity,infinity), a6, Msum(Weight(((exp((-(((p3-a6)*(p3-a6))*(1/(2*exp((ln(a5)*2)))))))*(1/a5))*(1/exp((ln((2*Pi))*(1/2))))), Msum(Weight(1, Bind(Lebesgue(-infinity,infinity), a7, Msum(Weight(((exp((-(((a6-a7)*(a6-a7))*(1/(2*exp((ln(a4)*2)))))))*(1/a4))*(1/exp((ln((2*Pi))*(1/2))))), Msum(Weight(((exp((-(((p2-a7)*(p2-a7))*(1/(2*exp((ln(a5)*2)))))))*(1/a5))*(1/exp((ln((2*Pi))*(1/2))))), Msum(Weight(((exp((-((a7*a7)*(1/(2*exp((ln(a4)*2)))))))*(1/a4))*(1/exp((ln((2*Pi))*(1/2))))), Msum(Weight((1/3), Msum(Weight(1, piecewise((a5<4), piecewise((1<a5), Msum(Weight((1/5), Msum(Weight(1, piecewise((a4<8), piecewise((3<a4), Ret(Pair(a4, a5)), Msum()), Msum())), Weight(1, Msum())))), Msum()), Msum())), Weight(1, Msum())))))))))))))))))))))), Weight(1, Msum())))))), Weight(1, Msum())))))):
rmProg1_w := Weight(exp(-(1/2)*(2*p2^2*a4^2+p2^2*a5^2-2*p2*p3*a4^2+p3^2*a4^2+p3^2*a5^2)/(a4^4+3*a4^2*a5^2+a5^4))/sqrt(a4^4+3*a4^2*a5^2+a5^4), Ret(Pair(a4, a5))):
rmProg1_r := {
Weight(1/(2*Pi), Bind(Uniform(1, 4), a5, Bind(Uniform(3, 8), a4, rmProg1_w))),
Weight(1/(2*Pi), Bind(Uniform(3, 8), a4, Bind(Uniform(1, 4), a5, rmProg1_w)))}:
TestHakaru(rmProg1, rmProg1_r, label="Tests.RoundTrip.rmProg1");
# easierRoadmapProg4 -- MH transition kernel with unclamped acceptance ratio
module()
  local unpair, rmProg4;
  unpair := proc(f,p)
    f(fst(p),snd(p))
  end proc;
  rmProg4 := lam(x0,blah, app(lam(x1,blah, lam(x2,blah, Bind(unpair(( (p3 , p4) -> Msum(Weight((1/2), Bind(Uniform(3, 8), a5, Ret(Pair(a5, p4)))), Weight((1/2), Bind(Uniform(1, 4), a6, Ret(Pair(p3, a6)))))), x2), a7, Ret(Pair(a7, (app(x1,a7)/app(x1,x2))))))),lam(x8,blah, unpair(( (p151 , p152) -> app(p152,lam(x153,blah, 1))), app(app(lam(x9,blah, lam(x10,blah, unpair(( (p11 , p12) -> app(lam(x13,blah, app(lam(x14,blah, Pair(Msum(Weight(x13, unpair(( (p15 , p16) -> p15), x14))), lam(x17,blah, (0+(x13*app(unpair(( (p18 , p19) -> p19), x14),x17)))))),app(lam(x20,blah, app(lam(x21,blah, Pair(Msum(Weight(x20, unpair(( (p22 , p23) -> p22), x21))), lam(x24,blah, (0+(x20*app(unpair(( (p25 , p26) -> p26), x21),x24)))))),app(lam(x27,blah, app(lam(x28,blah, app(lam(x29,blah, app(lam(x30,blah, Pair(Msum(Weight(x27, unpair(( (p31 , p32) -> p31), x28)), Weight(x29, unpair(( (p33 , p34) -> p33), x30))), lam(x35,blah, ((0+(x27*app(unpair(( (p36 , p37) -> p37), x28),x35)))+(x29*app(unpair(( (p38 , p39) -> p39), x30),x35)))))),Pair(Msum(), lam(x40,blah, 0)))),1)),app(lam(x41,blah, app(lam(x42,blah, Pair(Msum(Weight(x41, unpair(( (p43 , p44) -> p43), x42))), lam(x45,blah, (0+(x41*app(unpair(( (p46 , p47) -> p47), x42),x45)))))),app(lam(x48,blah, app(lam(x49,blah, app(lam(x50,blah, app(lam(x51,blah, Pair(Msum(Weight(x48, unpair(( (p52 , p53) -> p52), x49)), Weight(x50, unpair(( (p54 , p55) -> p54), x51))), lam(x56,blah, ((0+(x48*app(unpair(( (p57 , p58) -> p58), x49),x56)))+(x50*app(unpair(( (p59 , p60) -> p60), x51),x56)))))),Pair(Msum(), lam(x61,blah, 0)))),1)),app(lam(x62,blah, app(lam(x63,blah, Pair(Msum(Weight(x62, unpair(( (p64 , p65) -> p64), x63))), lam(x66,blah, (0+(x62*app(unpair(( (p67 , p68) -> p68), x63),x66)))))),unpair(( (p69 , p70) -> unpair(( (p71 , p72) -> unpair(( (p73 , p74) -> unpair(( (p75 , p76) -> unpair(( (p77 , p78) -> unpair(( (p79 , p80) -> unpair(( (p81 , p82) -> unpair(( (p83 , p84) -> unpair(( (p85 , p86) -> unpair(( (p87 , p88) -> app(lam(x89,blah, app(lam(x90,blah, Pair(Msum(Weight(x89, unpair(( (p91 , p92) -> p91), x90))), lam(x93,blah, (0+(x89*app(unpair(( (p94 , p95) -> p95), x90),x93)))))),app(lam(x96,blah, app(lam(x97,blah, Pair(Msum(Weight(x96, unpair(( (p98 , p99) -> p98), x97))), lam(x100,blah, (0+(x96*app(unpair(( (p101 , p102) -> p102), x97),x100)))))),app(lam(x103,blah, app(lam(x104,blah, app(lam(x105,blah, app(lam(x106,blah, Pair(Msum(Weight(x103, unpair(( (p107 , p108) -> p107), x104)), Weight(x105, unpair(( (p109 , p110) -> p109), x106))), lam(x111,blah, ((0+(x103*app(unpair(( (p112 , p113) -> p113), x104),x111)))+(x105*app(unpair(( (p114 , p115) -> p115), x106),x111)))))),Pair(Msum(), lam(x116,blah, 0)))),1)),piecewise((p12<4), piecewise((1<p12), app(lam(x117,blah, app(lam(x118,blah, Pair(Msum(Weight(x117, unpair(( (p119 , p120) -> p119), x118))), lam(x121,blah, (0+(x117*app(unpair(( (p122 , p123) -> p123), x118),x121)))))),app(lam(x124,blah, app(lam(x125,blah, app(lam(x126,blah, app(lam(x127,blah, Pair(Msum(Weight(x124, unpair(( (p128 , p129) -> p128), x125)), Weight(x126, unpair(( (p130 , p131) -> p130), x127))), lam(x132,blah, ((0+(x124*app(unpair(( (p133 , p134) -> p134), x125),x132)))+(x126*app(unpair(( (p135 , p136) -> p136), x127),x132)))))),Pair(Msum(), lam(x137,blah, 0)))),1)),piecewise((p11<8), piecewise((3<p11), app(lam(x138,blah, app(lam(x139,blah, Pair(Msum(Weight(x138, unpair(( (p140 , p141) -> p140), x139))), lam(x142,blah, (0+(x138*app(unpair(( (p143 , p144) -> p144), x139),x142)))))),app(lam(x145,blah, Pair(Ret(x145), lam(x146,blah, app(x146,x145)))),Pair(p11, p12)))),5), Pair(Msum(), lam(x147,blah, 0))), Pair(Msum(), lam(x148,blah, 0))))),1))),(1/5)), Pair(Msum(), lam(x149,blah, 0))), Pair(Msum(), lam(x150,blah, 0))))),1))),(1/3)))),((((1/Pi)*exp((((((((((p69*p71)*(p11*p11))*2)+((((p11*p11)*p73)*p76)*(-2)))+((p78*p80)*(p11*p11)))+((p12*p12)*(p81*p83)))+((p12*p12)*(p86*p88)))*(1/((((p11*p11)*(p11*p11))+(((p12*p12)*(p11*p11))*3))+((p12*p12)*(p12*p12)))))*(-(1/2)))))*exp((ln(((exp(((x -> piecewise(x<0, -337, ln(x)))(p11)*4))+((exp(((x -> piecewise(x<0, -337, ln(x)))(p12)*2))*exp(((x -> piecewise(x<0, -337, ln(x)))(p11)*2)))*3))+exp(((x -> piecewise(x<0, -337, ln(x)))(p12)*4))))*(-(1/2)))))*(1/10)))), x9)), x9)), x9)), x9)), x9)), x9)), x9)), x9)), x9)), x9))),1))),1))),1))),1))),1))),1)), x10))),x0),x8))))):
  TestHakaru(app(app(rmProg4,Pair(r1,r2)),Pair(p1,p2)), Msum(Weight(1/2, Bind(Uniform(3, 8), a5, Ret(Pair(Pair(a5, p2), exp((1/2)*(-p1+a5)*(a5+p1)*(p1^2*p2^2*r1^2+p1^2*p2^2*r2^2+2*p1^2*r1^2*a5^2-2*p1^2*r1*r2*a5^2+p1^2*r2^2*a5^2+p2^4*r1^2+2*p2^4*r1*r2+2*p2^4*r2^2+p2^2*r1^2*a5^2+p2^2*r2^2*a5^2)/((p2^4+3*p2^2*a5^2+a5^4)*(p1^4+3*p1^2*p2^2+p2^4)))*sqrt(p1^4+3*p1^2*p2^2+p2^4)/sqrt(p2^4+3*p2^2*a5^2+a5^4))))), Weight(1/2, Bind(Uniform(1, 4), a6, Ret(Pair(Pair(p1, a6), exp((1/2)*(-p2+a6)*(a6+p2)*(5*p1^4*r1^2-6*p1^4*r1*r2+2*p1^4*r2^2+2*p1^2*p2^2*r1^2-2*p1^2*p2^2*r1*r2+p1^2*p2^2*r2^2+2*p1^2*r1^2*a6^2-2*p1^2*r1*r2*a6^2+p1^2*r2^2*a6^2+p2^2*r1^2*a6^2+p2^2*r2^2*a6^2)/((p1^4+3*p1^2*a6^2+a6^4)*(p1^4+3*p1^2*p2^2+p2^4)))*sqrt(p1^4+3*p1^2*p2^2+p2^4)/sqrt(p1^4+3*p1^2*a6^2+a6^4)))))),
  label="rmProg4",
  ctx= [3<p1, p1<8, 1<p2, p2<4]);
end module:

#####################################################################
#
# conjugacy tests
#
#####################################################################
gaussian_gaussian   :=
  Bind(Gaussian(mu0,sigma0),mu,
       Weight(NewSLO:-density[Gaussian](mu,sigma1)(x), Ret(mu))):
gaussian_gaussian_s :=
  Weight((1/2)*sqrt(2)*exp(-(1/2)*(mu0-x)^2/(sigma0^2+sigma1^2))/
         (sqrt(Pi)*sqrt(sigma0^2+sigma1^2)),
         Gaussian((mu0*sigma1^2+sigma0^2*x)/(sigma0^2+sigma1^2),
                  sigma0*sigma1/sqrt(sigma0^2+sigma1^2))):
TestHakaru(gaussian_gaussian, gaussian_gaussian_s,
  label="gaussian_gaussian conjugacy",
  ctx = [mu0::real, sigma0>0, sigma1>0, x::real]);
invgamma_gaussian   :=
  Bind(GammaD(shape,scale),lambda,
       Weight(NewSLO:-density[Gaussian](mu,lambda^(-1/2))(x), Ret(lambda))):
invgamma_gaussian_s :=
  Weight(GAMMA(1/2+shape)*sqrt(scale)*
         ((1/2)*scale*mu^2-scale*mu*x+(1/2)*scale*x^2+1)^
         (-shape)/(GAMMA(shape)*
                   sqrt(scale*mu^2-2*scale*mu*x+scale*x^2+2)*sqrt(Pi)),
         GammaD(1/2+shape, 2*scale/(scale*mu^2-2*scale*mu*x+scale*x^2+2))):
TestHakaru(invgamma_gaussian, invgamma_gaussian_s,
  label="invgamma_gaussian conjugacy",
  ctx = [mu::real, shape>0, scale>0, x::real]);
gaussian_invgamma_gaussian   :=
  Bind(GammaD(shape,scale),tau,
       Bind(Gaussian(mu0*sqrt(tau),1/sqrt(nu)),mu,
            Weight(NewSLO:-density[Gaussian](mu*tau^(-1/2),tau^(-1/2))(x),
                   Ret([mu,tau])))):
gaussian_invgamma_gaussian_s :=
  Weight(GAMMA(1/2+shape)*sqrt(nu)*sqrt(scale)*
         (scale*mu0^2*nu-2*scale*mu0*nu*x+scale*nu*x^2+2*nu+2)^(-1/2-shape)*
         (2*nu+2)^shape/(GAMMA(shape)*sqrt(Pi)),
         Bind(GammaD(1/2+shape, 2*scale*(nu+1)/
                     (scale*mu0^2*nu-2*scale*mu0*nu*x+scale*nu*x^2+2*nu+2)),
              tau, Bind(Gaussian(sqrt(tau)*(mu0*nu+x)/(nu+1), 1/sqrt(nu+1)),
                        mu, Ret([mu,tau])))):
TestHakaru(gaussian_invgamma_gaussian, gaussian_invgamma_gaussian_s,
  label="gaussian_invgamma_gaussian conjugacy",
  ctx = [mu0::real, nu>0, shape>0, scale>0, x::real]);
gamma_gamma   :=
  Bind(GammaD(alpha0,1/beta0),beta,
       Weight(NewSLO:-density[GammaD](alpha,1/beta)(x), Ret(beta))):
gamma_gamma_s :=
  Weight(beta0^alpha0*x^(alpha-1)*GAMMA(alpha+alpha0)*(beta0+x)^(-alpha-alpha0)/
         (GAMMA(alpha0)*GAMMA(alpha)), GammaD(alpha+alpha0, 1/(beta0+x))):
TestHakaru(gamma_gamma, gamma_gamma_s, label="gamma_gamma conjugacy",
  ctx = [alpha0>0, beta0>0, alpha>0, x>0]);
gamma_poisson   :=
  Bind(GammaD(shape,scale),lambda,
       Weight(NewSLO:-density[PoissonD](lambda)(k), Ret(lambda))):
gamma_poisson_s :=
  Weight(scale^k*(scale+1)^(-k-shape)*GAMMA(k+shape)/
         (GAMMA(shape)*GAMMA(k+1)), GammaD(k+shape, scale/(scale+1))):
TestHakaru(gamma_poisson, gamma_poisson_s, label="gamma_poisson conjugacy",
           ctx=[shape>0, scale>0, k::nonnegint]);

# For the following test, banishing fails because Maple currently evaluates
#   int(piecewise(x < y, 1/(1-x), 0), x = 0 .. 1) assuming y<1
# to "undefined".  (See ppaml-l discussion "NewSLO giving weird output"
# around 2015-12-10.)  The test is that we handle the failure gracefully.
TestHakaru(Bind(Uniform(0,1), x, Uniform(x,1)),
          {Bind(Uniform(0,1), x, Uniform(x,1)),
           Bind(Uniform(0,1), x, Weight(ln(1/(1-x)), Ret(x)))},
  label="roundtrip despite banishing failure");

TestHakaru(Bind(Ret(ary(n,i,i*2)), v, Ret(idx(v,42))), Ret(84),
           label="basic array indexing");

#####################################################################
#
# Tests for type-directed simplification
#
#####################################################################

module()
  local hpair, hbool,         heither,       hreal, hprob,
        ppair, ptrue, pfalse, pleft, pright,
        dpair, dtrue, dfalse, dleft, dright,
        unpair;
  uses CodeTools;
  hpair   := (t1,t2) -> HData(DatumStruct(pair,[Konst(t1),Konst(t2)])):
  hbool   := HData(DatumStruct(true,[]),DatumStruct(false,[])):
  heither := (t1,t2) -> HData(DatumStruct(left,[Konst(t1)]),
                              DatumStruct(right,[Konst(t2)])):
  hreal   := HReal():
  hprob   := HReal(Bound(`>=`,0)):
  ppair   := (p1,p2) -> PDatum(pair,PInl(PEt(p1,PEt(p2,PDone)))):
  ptrue   := PDatum(true,PInl(PDone)):
  pfalse  := PDatum(false,PInr(PInl(PDone))):
  pleft   := p -> PDatum(left,PInl(PEt(p,PDone))):
  pright  := p -> PDatum(right,PInr(PInl(PEt(p,PDone)))):
  dpair   := (d1,d2) -> Datum(pair,Inl(Et(d1,Et(d2,Done)))):
  dtrue   := Datum(true,Inl(Done)):
  dfalse  := Datum(false,Inr(Inl(Done))):
  dleft   := d -> Datum(left,Inl(Et(d,Done))):
  dright  := d -> Datum(right,Inr(Inl(Et(d,Done)))):
  unpair  := (e1,x,y,e0) -> case(e1,Branches(Branch(ppair(PVar(x),PVar(y)),e0))):
  TestSimplify(lam(pr,hpair(hprob,hreal),unpair(pr,x,y,sqrt(x^2)+y)),
               HFunction(hpair(hprob,hreal),hreal),
               lam(pr,hpair(hprob,hreal),unpair(pr,x,y,x+y)),
               label="Transfer function argument type to KB");
  TestSimplify(lam(b,hbool,case(b,Branches(Branch(pfalse,3),Branch(ptrue,4)))),
               HFunction(hbool,HInt()),
               lam(b,hbool,case(b,Branches(Branch(ptrue,4),Branch(pfalse,3)))),
               label="Eta-expand pure function from boolean");
  TestSimplify(lam(pr,hpair(hbool,hbool),unpair(pr,x,y,dpair(y,x))),
               HFunction(hpair(hbool,hbool), hpair(hbool,hbool)),
               lam(pr,hpair(hbool,hbool),case(pr,Branches(
                 Branch(ppair(ptrue ,ptrue ), dpair(dtrue ,dtrue )),
                 Branch(ppair(ptrue ,pfalse), dpair(dfalse,dtrue )),
                 Branch(ppair(pfalse,ptrue ), dpair(dtrue ,dfalse)),
                 Branch(ppair(pfalse,pfalse), dpair(dfalse,dfalse))))),
               label="Eta-expand pure function from pair of booleans");
  TestSimplify(lam(b,hbool,
                     Bind(Uniform(0,1),p,
                     Weight(case(b,Branches(Branch(pfalse,1-p),
                                            Branch(ptrue,p))),
                     Ret(p)))),
               HFunction(hbool,HMeasure(hreal)),
               lam(b,hbool,
                     case(b,Branches(Branch(ptrue , Weight(1/2,BetaD(2,1))),
                                     Branch(pfalse, Weight(1/2,BetaD(1,2)))))),
               label="Eta-expand function from boolean to measure");
end module:

###########
#
# RoundTrip tests;

module()
  local ty, kb, rt1, rt1r, res, l;
  kb := x::real:
  rt1 := Context(kb, Bind(Gaussian(0,1), x, Ret(0))):
  ty  := HMeasure(HReal()):
  rt1r := sprintf("%a", eval(ToInert(Context(kb, Ret(0))),
                             _Inert_ATTRIBUTE=NULL)):
  (proc(rt1r)
     # due to bug in CodeTest, the expected arguement to `CodeTools' cannot be a
     # local var, except a parameter
     CodeTools[Test]( RoundTrip(rt1, ty, _ret_type='string'), rt1r,
                      label="simple case of RoundTrip" );
   end proc)(rt1r);
end module:

# Categorical distribution
TestHakaru(Counting(0,11),
           label="Counting roundtrip");
TestHakaru(Bind(Counting(0,2),x,Weight(p^x*(1-p)^(1-x),Ret(x))),
           Categorical([1-p,p]),
           label="Categorical introduction",
           ctx=[0<=p, p<=1]);
TestHakaru(Bind(Categorical([p,1-p]),x,Weight(p^x*(1-p)^(1-x),Ret(x))),
           Weight(p*(1-p),Counting(0,2)),
           label="Categorical elimination",
           ctx=[0<=p, p<=1]);
TestHakaru(Bind(BetaD(6,4), p, Categorical([p,1-p])),
           Weight(1/10, Categorical([6,4])),
           label="BetaD elimination");
module()
  local bern, burglary;
  bern := p -> Bind(Categorical(ary(2,i,piecewise(i=0,p,1-p))), i, Ret(i=0)):
  burglary := Bind(bern(1/10000), b,
              Bind(bern(piecewise(b=true,19/20,1/100)), a,
              Ret(a))):
  TestHakaru(burglary, bern(5047/500000), label="burglary");
  TestHakaru(Bind(BetaD(alpha,beta), p, bern(p)),
             Weight(1/(alpha+beta),
                    Bind(Categorical([alpha,beta]), i, Ret(i=0))),
             label="integrate BetaD out of BetaD-Bernoulli"):
end module:

module()
  # From `disintegrate examples/burglary.hk'
  local burg2, burg2_r;
  burg2 :=
  lam(x5, HData(DatumStruct(true,[]),DatumStruct(false,[])),
   eval(Bind(app(bern, (1 * 1/(10000))), burglary,
    eval(Bind(Msum(Weight((idx([p, (1 + (-(p)))],
     case(x5, Branches(Branch(PDatum(true, PInl(PDone)), 0),
         Branch(PDatum(false, PInr(PInl(PDone))), 1))))
       * 1/(Sum(idx([p, (1 + (-(p)))], x0),
                x0=0..(size([p, (1 + (-(p)))]))-1))),
      Ret(Datum(unit, Inl(Done))))), x16, Ret(burglary)),
         p=(case(burglary,
                 Branches(Branch(PDatum(true, PInl(PDone)), (19 * 1/(20))),
                          Branch(PDatum(false, PInr(PInl(PDone))),
                                 (1 * 1/(100)))))))),
           bern=(lam(p, HReal(Bound(`>=`,0)),
                     Bind(Categorical([p, (1 + (-(p)))]), x,
                          Ret(idx([true, false], x))))))),
     HFunction(HData(DatumStruct(true,[]),DatumStruct(false,[])),
               HMeasure(HData(DatumStruct(true,[]),DatumStruct(false,[])))):
  burg2_r :=
  lam(x5, HData(DatumStruct(true, []), DatumStruct(false, [])),
      piecewise(x5 = true,
                Msum(Weight(19/200000, Ret(true)),
                     Weight(9999/1000000, Ret(false))),
                Msum(Weight(1/200000, Ret(true)),
                     Weight(989901/1000000, Ret(false))))):
  TestSimplify(burg2, burg2_r, label="burglary 2"):
end module:
