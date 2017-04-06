kernelopts(assertlevel=2): # be strict on all assertions while testing
kernelopts(opaquemodules=false): # allow testing of internal routines
if not (NewSLO :: `module`) then
  WARNING("loading NewSLO failed");
  `quit`(3);
end if;

with(Hakaru):
with(NewSLO):
with(Partition):

#####################################################################
#
# disintegration tests
#
#####################################################################
d1 := Bind(Lebesgue(-infinity,infinity), x, Ret(Pair(-5*x,3/x))):
d1r := {Weight(1/5,Ret(-15/t))}:

# should try d2 with 1/c as well
d2 := Bind(Lebesgue(-infinity,infinity), x, Ret(Pair((-1/7)*x-1,3))):
d2r := {Weight(7, Ret(3))}:

#The next two tests are simplified versions of the Borel-Kolmogorov paradox.
#https://en.wikipedia.org/wiki/Borel-Kolmogorov_paradox
d3 := Bind(Uniform(0,1), x, Bind(Uniform(0,1), y, Ret(Pair(x-y,f(x,y))))):
d3r := {
  PARTITION([Piece(t <= -1
                  ,Msum())
            ,Piece(t <= 0 and -1 < t
                  ,Weight(t+1,Bind(Uniform(-t,1),`y`,Ret(f(t+`y`,`y`)))))
            ,Piece(t <= 1 and 0 < t
                  ,Weight(1-t,Bind(Uniform(0,1-t),`y`,Ret(f(t+`y`,`y`)))))
            ,Piece(1 < t
                  ,Msum())
            ]) ,
  PARTITION([Piece(t <= -1
                  ,Msum())
            ,Piece(t <= 0 and -1 < t
                  ,Weight(t+1,Bind(Uniform(0,t+1),`x`,Ret(f(`x`,-t+`x`)))))
            ,Piece(t <= 1 and 0 < t
                  ,Weight(1-t,Bind(Uniform(t,1),`x`,Ret(f(`x`,-t+`x`)))))
            ,Piece(1 < t,Msum())
            ])
}:


BUniform := proc(x,b,$) Bind(Uniform(0,1), x, b) end proc:
d3_3 := BUniform(x, BUniform(y, BUniform(z, Ret(Pair(x+y+z,f(x,y,z)))))):
d3_3_r := {}:

d4 := Bind(Uniform(0,1), x, Bind(Uniform(0,1), y, Ret(Pair(x/y,x)))):
d4r := {
  Weight(1/abs(t)^2,
    Bind(Uniform(0,1),x,
         piecewise(x < t,Weight(x,Ret(x)),Msum()))),
  piecewise(0 < t,
    Bind(Uniform(0,1),y,
         piecewise(t < 1/y,
           Weight(y,Ret(t*y)),
           Msum())),
    Msum()),
  PARTITION([Piece(t <= 0,Msum())
           , Piece(t <= 1 and 0 < t,Weight(1/t,Bind(Uniform(0,t),x,Weight(x,Ret(x)))))
           , Piece(1 < t,Weight(1/2/t^2,BetaD(2,1)))])
}:

# like d3 but positive, and the entire parametric family.
d3posfam := Bind(Uniform(0, 1), x, Bind(Uniform(0, 1), y, Ret(Pair(x+y+K_0, f(x, y))))):
d3posfam_r := {
  PARTITION([ Piece(t <= K_0, Msum())
            , Piece(K_0 < t and t <= 1+K_0, Weight(t-K_0, Bind(Uniform(0, t-K_0), x, Ret(f(x, t-x-K_0)))))
            , Piece(t < 2+K_0 and 1+K_0 < t, Weight(2-t+K_0, Bind(Uniform(-1+t-K_0, 1), x, Ret(f(x, t-x-K_0)))))
            , Piece(2+K_0 <= t, Msum())]) }:
d3posfam_ctx := [K_0::real]:

d5 := Bind(Gaussian(0,1), x, Bind(Gaussian(x,1), y, Ret(Pair(y,x)))):
d5r := {Weight((1/2)*exp(-(1/4)*t^2)/Pi^(1/2), Gaussian((1/2)*t, (1/2)*2^(1/2)))}:

d6 := Bind(Gaussian(0,1), x, Bind(Gaussian(x,1), y, Ret(Pair(x,y)))):
d6r := {Weight(1/2*2^(1/2)/Pi^(1/2)*exp(-1/2*t^2),Gaussian(t,1))}:

# note (y+y), which gives trouble for a syntactic approach
normalFB1 :=
  Bind(Gaussian(0,1), x,
  Bind(Gaussian(x,1), y,
  Ret(Pair((y+y)+x, _Unit)))):

normalFB1r := {Weight(1/26*exp(-1/26*t^2)/Pi^(1/2)*13^(1/2)*2^(1/2),Ret(_Unit))}:

# tests taken from haskell/Tests/Disintegrate.hs
# use same names, to be clearer
norm0a :=
  Bind(Gaussian(0,1), x,
  Bind(Gaussian(x,1), y,
  Ret(Pair(y, x)))):
  # note that the answer below is much nicer than the one expected in Haskell
norm0r := {Weight(1/2*exp(-1/4*t^2)/Pi^(1/2),Gaussian(t/2,sqrt(2)/2))}:

norm1a :=
  Bind(Gaussian(3,2), x,Ret(piecewise(x<0, Pair(-x, _Unit), Pair(x, _Unit)))):
norm1b :=
  Bind(Gaussian(3,2), x,piecewise(x<0, Ret(Pair(-x, _Unit)), Ret(Pair(x, _Unit)))):


norm1r_w := (1/4)*sqrt(2)*exp(-9/8)*((exp(t))^(3/4)/(exp(t^2))^(1/8)+1/((exp(t^2))^(1/8)*(exp(t))^(3/4)))/sqrt(Pi):
norm1r := {
  Weight( piecewise(t < 0  , 0
                   ,0 <= t , norm1r_w
                   )
        , Ret(_Unit)
        ) ,
  Weight( PARTITION([Piece(t < 0  , 0)
                    ,Piece(0 <= t , norm1r_w)
                   ])
        , Ret(_Unit)
        )
}:

assume(s::real, noiseT >= 3, noiseT <= 8, noiseE >= 1, noiseE <= 8);
easyRoad:= [
  Bind(Uniform(3, 8), noiseT,
  Bind(Uniform(1, 4), noiseE,
  Bind(Gaussian(0, noiseT), x1,
  Bind(Gaussian(x1, noiseE), m1,
  Bind(Gaussian(x1, noiseT), x2,
  Bind(Gaussian(x2, noiseE), m2,
  Ret(Pair(Pair(m1,m2), Pair(noiseT,noiseE)))
  )))))),
  Pair(s,t)
]:
#The first expression below comes from the actual output of disint, hand-
#simplified 1) to bring factors into the innnermost integral, 2) to combine
#products of exps, and 3) to express the polynomial arg of exp in a logical way
#by sub-factoring.
easyRoadr:= {
  Weight(                #Weight 1
    Pi/8,
    Bind(                #Bind 1
      Uniform(3, 8), noiseT,
      Weight(            #Weight 2
        1/noiseT^2,
        Bind(            #Bind 2
          Uniform(1, 4), noiseE,
          Weight(        #Weight 3
            int(         #Int 1
              int(       #Int 2
                exp(
                  -(x2^2/2 - x1*x2 + x1^2)/noiseT^2 -
                  ((t-x2)^2 + (s-x1)^2)/noiseE^2
                )*2/Pi/noiseE,
                x2= -infinity..infinity
              ),         #-Int 2
              x1= -infinity..infinity
            ),           #-Int 1
            Ret(Pair(noiseT, noiseE))
          )              #-Weight 3
        )                #-Bind 2
      )                  #-Weight 2
    )                    #-Bind 1
  ),                     #-Weight 1

  #Hopefully, that's equivalent to...
  Bind(Uniform(3, 8), noiseT,
  Bind(Uniform(1, 4), noiseE,
  Bind(Gaussian(0, noiseT), x1,
  Bind(Weight(density[Gaussian](x1, noiseE)(s), Ret(_Unit)), _,
  Bind(Gaussian(x1, noiseT), x2,
  Weight(density[Gaussian](x2, noiseE)(t), Ret(Pair(noiseT, noiseE)))
  )))))
}:
helloWorld:=
  Bind(Gaussian(0,1), mu,
  Bind(Plate(n, k, Gaussian(mu, 1)), nu,
  Ret(Pair(nu, mu))
  )):
helloWorldr:= {
  Bind(Gaussian(0,1), mu,
  Plate(n, i, Weight(density[Gaussian](mu, 1)(idx(t,i)), Ret(mu)))
  )
}:

pair_x_x := Bind(Uniform(0, 1), x, Ret(Pair(x, x))):
pair_x_x_r := {
  PARTITION([Piece(t < 0, Msum()), Piece(0 <= t and t <= 1, Ret(t)), Piece(1 < t, Msum())]) }:

#This first block of tests is to test the basic functionality of disint, and,
#to some extent, the system as a whole. These tests may be meaningless to you,
#the statistician and end user of this Hakaru product; they aren't meant to
#have any statistical meaning.--Carl 2016Oct04

TestDisint(
     [Ret(Pair(sqrt(Pi), x)), t &M Ret(7)],
     {Msum()},
     label= "(d0_2) `Dirac` test 1"
);

TestDisint(
     [Ret(Pair(sqrt(Pi), x^2)), t &M Ret(sqrt(Pi))],
     {Ret(x^2)},
     label= "(d0_3) `Dirac` test 2"
);

TestDisint(
     [Bind(Lebesgue((-1,1)*~infinity), x, Ret(Pair(sqrt(Pi), x^2))),
      t &M Ret(sqrt(Pi))
     ],
     {Bind(Lebesgue((-1,1)*~infinity), x1, Ret(x1^2))},
     label= "(d0_4) `Dirac` test with `Bind`"
);

TestDisint(d1, d1r, label = "(d1) Disintegrate linear function");
TestDisint(d2, d2r, label = "(d2) Disintegrate linear function II");
TestDisint(d5, d5r, label = "(d5) Disintegrate N(0,1)*N(x,1), over y");
TestDisint(d6, d6r, label = "(d6) Disintegrate N(0,1)*N(x,1), over x");
TestDisint(norm0a, norm0r,
     label = "(norm0a) U(0,1) >>= \x -> U(x,1) >>= \y -> Ret(y,x)"
);

## This one is kind of cosmetic; it would be 'fixed' properly if the
## disintegration process did not use 'improve' to do "domain information
## discovery", but rather had a specific function (and then improve could
## indeed do this integral).
# should work now
TestDisint( normalFB1, normalFB1r,
     label = "(d7_normalFB1) Disintegrate N(0,1)*N(x,1), over (y+y)+x"
            );

TestDisint(d3, d3r, label = "(d3) Disintegrate U(0,1) twice, over x-y");

######################################################################
#
# These tests fail, and are expected to.  Move them up when they
# start passing (and are expected to).
#
# They are, however, roughly in order of what we'd like to have work.
#

# change of variables
TestDisint(d4, d4r, label = "(d4) Disintegrate U(0,1) twice, over x/y");
# funky piecewise
TestDisint(norm1a, norm1r,
     label = "(norm1a) U(0,1) into Ret of pw"
);
TestDisint(norm1b, norm1r,
     label = "(norm1b) U(0,1) into pw of Ret"
);
#In this one the function in the inequality, x+x^3, is injective but nonlinear.
TestDisint(
     Bind(Gaussian(0,1), x, Ret(Pair(x+x^3, f(x)))),
     {}, #I don't know what to expect.
     label= "(d0_5) Injective nonlinear inequality"
);

TestDisint(pair_x_x, pair_x_x_r, label="(pair_x_x) Disintegrate U(0,1) over Ret(x,x)");
TestDisint(d3_3, d3_3_r, label = "(d3_3) Disintegrate U(0,1) thrice, over x+y+z");
TestDisint(d3posfam, d3posfam_r, d3posfam_ctx
          , label = "(d3posfam) Disintegrate U(0,1) twice, over x+y+K");

#This one is a basic test of the Counting wrt-var type.
#This one gives the Weight(-1, ...) error
TestDisint(
     [Bind(PoissonD(2), n, Ret(Pair(3,n))), n_ &M Counting((-1,1)*~infinity)],
     {},  #I don't know what to expect.
     [n::integer, n >= 0],
     label= "(d0_1) `Counting` test; `Weight` bug (currently failing)"
);

TestDisint(
     helloWorld, helloWorldr,
     [n::integer, n > 0],
     label= "(helloWorld) Plate of Normals"
);

# tests which take too long
TestDisint(
     easyRoad, easyRoadr, [],
     120, #takes 6 - 8 minutes to `improve` on an Intel i7
     label= "(easyRoad) Combo of Normals with distinct Uniform noises"
);
