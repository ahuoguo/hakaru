{-# LANGUAGE NoImplicitPrelude
           , DataKinds
           , TypeOperators
           , TypeFamilies
           , ScopedTypeVariables
           , FlexibleContexts
           , MultiParamTypeClasses
           , FunctionalDependencies
           , TypeSynonymInstances
           , GADTs
           , FlexibleInstances 
           , FlexibleContexts 
           , ConstraintKinds
           #-}
{-# OPTIONS_GHC -Wall -fwarn-tabs #-}
module Tests.RoundTrip where

import           Prelude ((.), ($), asTypeOf, String, FilePath, Show(..), (++), Bool(..), concat)
import qualified Prelude 
import qualified Data.List.NonEmpty as L
import           Data.Ratio
import qualified Data.Text.Utf8 as IO 

import Language.Hakaru.Syntax.Prelude
import Language.Hakaru.Types.DataKind
import Language.Hakaru.Pretty.Concrete (pretty)
import Language.Hakaru.Syntax.AST (Term, PrimOp(..))
import Language.Hakaru.Syntax.AST.Transforms
import Language.Hakaru.Syntax.ABT (ABT, TrivialABT(..))
import Language.Hakaru.Expect     (total)
import Language.Hakaru.Inference  (priorAsProposal, mcmc, mh)
import Language.Hakaru.Types.Sing
import System.IO 
import System.Directory 
import Control.Monad (mapM_, Monad(return))
import Data.Foldable (null)
import Data.List (intercalate) 

import qualified Data.Text as Text 
import Test.HUnit hiding ((~:), test)
import qualified Test.HUnit as HUnit
import Tests.TestTools hiding (testStriv, testSStriv, testConcreteFiles)
import qualified Tests.TestTools as Tools
import Tests.Models
    (uniform_0_1, normal_0_1, gamma_1_1,
     uniformC, normalC, beta_1_1, t4, t4', norm, unif2)

unsafeSuperpose
    :: (ABT Term abt)
    => [(abt '[] 'HProb, abt '[] ('HMeasure a))]
    -> abt '[] ('HMeasure a)
unsafeSuperpose = superpose . L.fromList


class IsTestGroup t where 
  test :: [t] -> t 

class IsTest' ta t | ta -> t, t -> ta where
  (~:) :: String -> ta -> t 

class IsTestAssertion ta where 
  testStriv 
    :: TrivialABT Term '[] a
    -> ta 

  testSStriv 
    :: [(TrivialABT Term '[] a)] 
    -> TrivialABT Term '[] a 
    -> ta 

  testConcreteFiles
      :: FilePath
      -> FilePath
      -> ta   

  
instance IsTestGroup Test where test = HUnit.test; 
instance IsTest' Assertion Test where (~:) = (HUnit.~:)
instance IsTestAssertion Assertion where 
  testStriv = Tools.testStriv; testSStriv = Tools.testSStriv; testConcreteFiles = Tools.testConcreteFiles


data SaveInput = forall a . TestInput [TrivialABT Term '[] a] (TrivialABT Term '[] a) | DoNothing
newtype SaveTests = SaveTests { runSaveTests :: IO () }

instance IsTestAssertion SaveInput where 
  testStriv = TestInput [] 
  testSStriv = TestInput 
  testConcreteFiles _ _ = DoNothing

instance IsTestGroup SaveTests where 
  test = SaveTests . mapM_ runSaveTests

instance IsTest' SaveInput SaveTests where 
  (~:) _ DoNothing = SaveTests (return ()) 
  (~:) tnm (TestInput xs r) = 
    let go (s,x) = do 
          createDirectoryIfMissing True $ intercalate "/" dn 
          (IO.writeFile fn . Text.pack . show . pretty . expandTransformations) x
            where 
              dn = ["tests", "RoundTrip"]
              fn = intercalate "/" $ dn ++ [concat [tnm, if null s then "" else ".", s, ".hk"]]
            
        xs' = case xs of
                [] -> [("",r)]
                _  -> ("expected",r) : Prelude.zip (Prelude.map Prelude.show [0..]) xs 
    in SaveTests $ mapM_ go xs' 

type IsTest ta t = (IsTest' ta t, IsTestGroup t, IsTestAssertion ta)
  

testMeasureUnit :: IsTest ta t => t
testMeasureUnit = test [
    "t1,t5"   ~: testSStriv [t1,t5] (weight half),
    "t10"     ~: testSStriv [t10] (reject sing),
    "t11,t22" ~: testSStriv [t11,t22] (dirac unit),
    "t12"     ~: testSStriv [] t12,
    "t20"     ~: testSStriv [t20] (lam $ \y -> weight (y * half)),
    "t24"     ~: testSStriv [t24] t24',
    "t25"     ~: testSStriv [t25] t25',
    "t44Add"  ~: testSStriv [t44Add] t44Add',
    "t44Mul"  ~: testSStriv [t44Mul] t44Mul',
    "t53"     ~: testSStriv [t53,t53'] t53'',
    "t54"     ~: testStriv t54,
    "t55"     ~: testSStriv [t55] t55',
    "t56"     ~: testSStriv [t56,t56'] t56'',
    "t57"     ~: testSStriv [t57] t57',
    "t58"     ~: testSStriv [t58] t58',
    "t59"     ~: testStriv t59,
    "t60"     ~: testSStriv [t60,t60'] t60'',
    "t62"     ~: testSStriv [t62] t62',
    "t63"     ~: testSStriv [t63] t63',
    "t64"     ~: testSStriv [t64,t64'] t64'',
    "t65"     ~: testSStriv [t65] t65',
    "t77"     ~: testSStriv [] t77
    ]

testMeasureProb :: IsTest ta t => t
testMeasureProb = test [
    "t2"  ~: testSStriv [t2] (unsafeProb <$> uniform zero one),
    "t26" ~: testSStriv [t26] (dirac half),
    "t30" ~: testSStriv [] t30,
    "t33" ~: testSStriv [] t33,
    "t34" ~: testSStriv [t34] (dirac (prob_ 3)),
    "t35" ~: testSStriv [t35] (lam $ \x -> if_ (x < (fromRational 4)) (dirac (fromRational 3)) (dirac (fromRational 5))),
    "t38" ~: testSStriv [] t38,
    "t42" ~: testSStriv [t42] (dirac one),
    "t49" ~: testSStriv [] t49,
    "t61" ~: testSStriv [t61] t61',
    "t66" ~: testSStriv [] t66,
    "t67" ~: testSStriv [] t67,
    "t69x" ~: testSStriv [t69x] (dirac $ prob_ 1.5),
    "t69y" ~: testSStriv [t69y] (dirac $ prob_ 3.5)
    ]

testMeasureReal :: IsTest ta t => t
testMeasureReal = test
    [ "t3"  ~: testSStriv [] t3
    , "t6"  ~: testSStriv [t6'] t6
    , "t7"  ~: testSStriv [t7] t7'
    , "t7n" ~: testSStriv [t7n] t7n'
    , "t8'" ~: testSStriv [t8'] (lam $ \s1 ->
                                 lam $ \s2 ->
                                 normal zero (sqrt $ (s2 ^ (nat_ 2) + s1 ^ (nat_ 2))))
    , "t9"  ~: testSStriv [t9] (unsafeSuperpose [(prob_ 2, uniform (real_ 3) (real_ 7))])
    , "t13" ~: testSStriv [t13] t13'
    , "t14" ~: testSStriv [t14] t14'
    , "t21" ~: testStriv t21
    , "t28" ~: testSStriv [] t28
    , "t31" ~: testSStriv [] t31
    , "t36" ~: testSStriv [] t36
    , "t37" ~: testSStriv [] t37
    , "t39" ~: testSStriv [] t39
    , "t40" ~: testSStriv [] t40
    , "t43" ~: testSStriv [t43, t43'] t43''
    , "t45" ~: testSStriv [t46,t47] t45
    , "t50" ~: testStriv t50
    , "t51" ~: testStriv t51
    , "t68" ~: testStriv t68
    , "t68'" ~: testStriv t68'
    , "t70a" ~: testSStriv [t70a] (uniform one (real_ 3))
    , "t71a" ~: testSStriv [t71a] (uniform one (real_ 3))
    , "t72a" ~: testSStriv [t72a] (withWeight half $ uniform one (real_ 2))
    , "t73a" ~: testSStriv [t73a] (reject sing)
    , "t74a" ~: testSStriv [t74a] (reject sing)
    , "t70b" ~: testSStriv [t70b] (reject sing)
    , "t71b" ~: testSStriv [t71b] (reject sing)
    , "t72b" ~: testSStriv [t72b] (withWeight half $ uniform (real_ 2) (real_ 3))
    , "t73b" ~: testSStriv [t73b] (uniform one (real_ 3))
    , "t74b" ~: testSStriv [t74b] (uniform one (real_ 3))
    , "t70c" ~: testSStriv [t70c] (uniform one (real_ 3))
    , "t71c" ~: testSStriv [t71c] (uniform one (real_ 3))
    , "t72c" ~: testSStriv [t72c] (withWeight half $ uniform one (real_ 2))
    , "t73c" ~: testSStriv [t73c] (reject sing)
    , "t74c" ~: testSStriv [t74c] (reject sing)
    , "t70d" ~: testSStriv [t70d] (reject sing)
    , "t71d" ~: testSStriv [t71d] (reject sing)
    , "t72d" ~: testSStriv [t72d] (withWeight half $ uniform (real_ 2) (real_ 3))
    , "t73d" ~: testSStriv [t73d] (uniform one (real_ 3))
    , "t74d" ~: testSStriv [t74d] (uniform one (real_ 3))
    , "t76" ~: testStriv t76
    , "t78" ~: testSStriv [t78] t78'
    , "t79" ~: testSStriv [t79] (dirac one)
    , "t80" ~: testStriv t80
    , "t81" ~: testSStriv [] t81
    -- TODO, "kalman" ~: testStriv kalman
    --, "seismic" ~: testSStriv [] seismic
    , "lebesgue1" ~: testSStriv [] (lebesgue >>= \x -> if_ ((real_ 42) < x) (dirac x) (reject sing))
    , "lebesgue2" ~: testSStriv [] (lebesgue >>= \x -> if_ (x < (real_ 42)) (dirac x) (reject sing))
    , "lebesgue3" ~: testSStriv [lebesgue >>= \x -> if_ (x < (real_ 42) && (real_ 40) < x) (dirac x) (reject sing)]
                                (withWeight (prob_ $ 2) $ uniform (real_ 40) (real_ 42))
    , "testexponential" ~: testStriv testexponential
    , "testcauchy" ~: testStriv testCauchy
    , "exceptionLebesgue" ~: testSStriv [lebesgue >>= \x -> dirac (if_ (x == (real_ 3)) one x)] lebesgue
    , "exceptionUniform"  ~: testSStriv [uniform (real_ 2) (real_ 4) >>= \x ->
                                         dirac (if_ (x == (real_ 3)) one x)
                                        ] (uniform (real_ 2) (real_ 4))
    -- TODO "two_coins" ~: testStriv two_coins -- needs support for lists
    ]

testMeasureNat :: IsTest ta t => t 
testMeasureNat = test
    [ "size" ~: testConcreteFiles "tests/size_in.hk" "tests/size_out.hk"
    ]

testMeasureInt :: IsTest ta t => t
testMeasureInt = test
    [ "t75"  ~: testStriv t75
    , "t75'" ~: testStriv t75'
    , "t83"  ~: testSStriv [t83] t83'
    -- Jacques wrote: "bug: [simp_pw_equal] implicitly assumes the ambient measure is Lebesgue"
    , "exceptionCounting" ~: testSStriv [] (counting >>= \x ->
                                            if_ (x == (int_ 3))
                                                (dirac one)
                                                (dirac x))
    , "exceptionSuperpose" ~: testSStriv 
                                [(unsafeSuperpose [ (third, dirac (int_ 2))
                                                  , (third, dirac (int_ 3))
                                                  , (third, dirac (int_ 4))
                                                  ] `asTypeOf` counting) >>= \x -> 
                                 dirac (if_ (x == (int_ 3)) one x)]
                                (unsafeSuperpose [ (third, dirac (int_ 2))
                                                 , (third, dirac one)
                                                 , (third, dirac (int_ 4))
                                                 ])
    ]

testMeasurePair :: IsTest ta t => t 
testMeasurePair = test [
    "t4"            ~: testSStriv [t4] t4',
    "t8"            ~: testSStriv [] t8,
    "t23"           ~: testSStriv [t23] t23',
    "t48"           ~: testStriv t48,
    "t52"           ~: testSStriv [] t52,
    "dup"           ~: testSStriv [dup normal_0_1] (liftM2 pair
                                                           (normal zero one)
                                                           (normal zero one)),
    "norm"          ~: testSStriv [] norm,
    "norm_nox"      ~: testSStriv [norm_nox] (normal zero (sqrt (prob_ 2))),
    "norm_noy"      ~: testSStriv [norm_noy] (normal zero one),
    "flipped_norm"  ~: testSStriv [swap <$> norm] flipped_norm,
    "priorProp"     ~: testSStriv [lam (priorAsProposal norm)]
                                  (lam $ \x -> unpair x $ \x0 x1 ->
                                               unsafeSuperpose [(half, normal zero
                                                                         (sqrt (prob_ 2)) >>= \y ->
                                                                       dirac (pair x0 y)),
                                                                (half, normal_0_1 >>= \y ->
                                                                       dirac (pair y x1))]),
    "mhPriorProp"   ~: testSStriv [testMHPriorProp] testPriorProp',
    "unif2"         ~: testStriv unif2,
    "easyHMM"       ~: testStriv easyHMM,
    "testMCMCPriorProp" ~: testStriv testMCMCPriorProp
    ]

testOther :: IsTest ta t => t
testOther = test [
    "t82" ~: testSStriv [t82] t82',
    "testRoadmapProg1" ~: testStriv rmProg1,
    "testRoadmapProg4" ~: testStriv rmProg4,
    "testKernel" ~: testSStriv [testKernel] testKernel2
    --"testFalseDetection" ~: testStriv (lam seismicFalseDetection),
    --"testTrueDetection" ~: testStriv (lam2 seismicTrueDetection)
    --"testTrueDetectionL" ~: testStriv tdl,
    --"testTrueDetectionR" ~: testStriv tdr
    ]

allTests :: IsTest ta t => t 
allTests = test
    [ testMeasureUnit
    , testMeasureProb
    , testMeasureReal
    , testMeasurePair
    , testMeasureNat
    , testMeasureInt
    , testOther
    ]

save_allTests :: IO () 
save_allTests = runSaveTests allTests 

----------------------------------------------------------------
-- In Maple, should 'evaluate' to "\c -> 1/2*c(Unit)"
t1 :: (ABT Term abt) => abt '[] ('HMeasure HUnit)
t1 = uniform_0_1 >>= \x -> weight (unsafeProb x)

t2 :: (ABT Term abt) => abt '[] ('HMeasure 'HProb)
t2 = beta_1_1

t3 :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t3 = normal zero (prob_ 10)

-- t5 is "the same" as t1.
t5 :: (ABT Term abt) => abt '[] ('HMeasure HUnit)
t5 = weight half >> dirac unit

t6, t6' :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t6 = dirac (real_ 5)
t6' = unsafeSuperpose [(one, dirac (real_ 5))]

t7,t7', t7n,t7n' :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t7   = uniform_0_1 >>= \x -> weight (unsafeProb (x+one)) >> dirac (x*x)
t7'  = uniform_0_1 >>= \x -> unsafeSuperpose [(unsafeProb (x+one), dirac (x^(nat_ 2)))]
t7n  =
    uniform (negate one) zero >>= \x ->
    weight (unsafeProb (x+one)) >>
    dirac (x*x)
t7n' =
    uniform (real_ (-1)) zero >>= \x ->
    unsafeSuperpose [(unsafeProb (x + one), dirac (x^(nat_ 2)))]

-- For sampling efficiency (to keep importance weights at or close to 1),
-- t8 below should read back to uses of "normal", not uses of "lebesgue"
-- then "weight".
t8 :: (ABT Term abt) => abt '[] ('HMeasure (HPair 'HReal 'HReal))
t8 = normal zero (prob_ 10) >>= \x -> normal x (prob_ 20) >>= \y -> dirac (pair x y)

-- Normal is conjugate to normal
t8' :: (ABT Term abt)
    => abt '[] ('HProb ':-> 'HProb ':-> 'HMeasure 'HReal)
t8' =
    lam $ \s1 ->
    lam $ \s2 ->
    normal zero s1 >>= \x ->
    normal x s2

t9 :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t9 =
    lebesgue >>= \x -> 
    weight (if_ ((real_ 3) < x && x < (real_ 7)) half zero) >> 
    dirac x

t10 :: (ABT Term abt) => abt '[] ('HMeasure HUnit)
t10 = weight zero

t11 :: (ABT Term abt) => abt '[] ('HMeasure HUnit)
t11 = weight one

t12 :: (ABT Term abt) => abt '[] ('HMeasure HUnit)
t12 = weight (prob_ 2)

t13,t13' :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t13 = bern ((prob_ 3)/(prob_ 5)) >>= \b -> dirac (if_ b (real_ 37) (real_ 42))
t13' = unsafeSuperpose
    [ (prob_ $ 3 % 5, dirac (real_ 37))
    , (prob_ $ 2 % 5, dirac (real_ 42))
    ]

t14,t14' :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t14 =
    bern ((prob_ 3)/(prob_ 5)) >>= \b ->
    if_ b t13 (bern ((prob_ 2)/(prob_ 7)) >>= \b' ->
        if_ b' (uniform (real_ 10) (real_ 12)) (uniform (real_ 14) (real_ 16)))
t14' = unsafeSuperpose 
    [ (prob_ $ 9 % 25, dirac (real_ 37))
    , (prob_ $ 6 % 25, dirac (real_ 42))
    , (prob_ $ 4 % 35, uniform (real_ 10) (real_ 12))
    , (prob_ $ 2 % 7 , uniform (real_ 14) (real_ 16))
    ]

t20 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure HUnit)
t20 = lam $ \y -> uniform_0_1 >>= \x -> weight (unsafeProb x * y)

t21 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure 'HReal)
t21 = mcmc (lam $ \x -> normal x one) (normal zero (prob_ 5))

t22 :: (ABT Term abt) => abt '[] ('HMeasure HUnit)
t22 = bern half >> dirac unit

-- was called bayesNet in Nov.06 msg by Ken for exact inference
t23, t23' :: (ABT Term abt) => abt '[] ('HMeasure (HPair HBool HBool))
t23 =
    bern half >>= \a ->
    bern (if_ a ((prob_ 9)/(prob_ 10)) ((prob_ 1)/(prob_ 10))) >>= \b ->
    bern (if_ a ((prob_ 9)/(prob_ 10)) ((prob_ 1)/(prob_ 10))) >>= \c ->
    dirac (pair b c)
t23' = unsafeSuperpose
    [ ((prob_ $ 41 % 100), dirac (pair true true))
    , ((prob_ $ 9  % 100), dirac (pair true false))
    , ((prob_ $ 9  % 100), dirac (pair false true))
    , ((prob_ $ 41 % 100), dirac (pair false false))
    ]

t24,t24' :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure HUnit)
t24 =
   lam $ \x ->
   uniform_0_1 >>= \y ->
   uniform_0_1 >>= \z ->
   weight (x * exp (cos y) * unsafeProb z)
t24' =
   lam $ \x ->
   withWeight (x * half) $
   uniform_0_1 >>= \y ->
   weight (exp (cos y))

t25,t25' :: (ABT Term abt)
   => abt '[] ('HProb ':-> 'HReal ':-> 'HMeasure HUnit)
t25 =
   lam $ \x ->
   lam $ \y ->
   uniform_0_1 >>= \z ->
   weight (x * exp (cos y) * unsafeProb z)
t25' =
   lam $ \x ->
   lam $ \y ->
   weight (x * exp (cos y) * half)

t26 :: (ABT Term abt) => abt '[] ('HMeasure 'HProb)
t26 = dirac (total t1)

t28 :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t28 = uniform zero one

t30 :: (ABT Term abt) => abt '[] ('HMeasure 'HProb)
t30 = exp <$> uniform zero one

t31 :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t31 = uniform (real_ (-1)) one

t33 :: (ABT Term abt) => abt '[] ('HMeasure 'HProb)
t33 = exp <$> t31

t34 :: (ABT Term abt) => abt '[] ('HMeasure 'HProb)
t34 = dirac (if_ ((real_ 2) < (real_ 4)) (prob_ 3) (prob_ 5))

t35 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure 'HProb)
t35 = lam $ \x -> dirac (if_ ((x `asTypeOf` log one) < (real_ 4)) (prob_ 3) (prob_ 5))

t36 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure 'HProb)
t36 = lam (dirac . sqrt)

t37 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure 'HReal)
t37 = lam (dirac . recip)

t38 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure 'HProb)
t38 = lam (dirac . recip)

t39 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure 'HReal)
t39 = lam (dirac . log)

t40 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure 'HReal)
t40 = lam (dirac . log)

t42 :: (ABT Term abt) => abt '[] ('HMeasure 'HProb)
t42 = dirac . total $ (unsafeProb <$> uniform zero (real_ 2))

t43, t43', t43'' :: (ABT Term abt) => abt '[] (HBool ':-> 'HMeasure 'HReal)
t43   = lam $ \b -> if_ b uniform_0_1 (fromProb <$> beta_1_1)
t43'  = lam $ \b -> if_ b uniform_0_1 uniform_0_1
t43'' = lam $ \_ -> uniform_0_1

t44Add, t44Add', t44Mul, t44Mul'
    :: (ABT Term abt) => abt '[] ('HReal ':-> 'HReal ':-> 'HMeasure HUnit)
t44Add  = lam $ \x -> lam $ \y -> weight (unsafeProb $ (x * x) + (y * y))
t44Add' = lam $ \x -> lam $ \y -> weight (unsafeProb $ (x ^ (nat_ 2) + y ^ (nat_ 2)))
t44Mul  = lam $ \x -> lam $ \y -> weight (unsafeProb $ (x * x * y * y))
t44Mul' = lam $ \x -> lam $ \y -> weight (unsafeProb $ (x ^ (nat_ 2)) * (y ^ (nat_ 2)))

-- t45, t46, t47 are all equivalent.
-- But t47 is worse than t45 and t46 because the importance weight generated by
-- t47 as a sampler varies between 0 and 1 whereas the importance weight generated
-- by t45 and t46 is always 1.  In general it's good to reduce weight variance.
t45 :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t45 = normal (real_ 4) (prob_ 5) >>= \x -> if_ (x < (real_ 3)) (dirac (x^(nat_ 2))) (dirac (x+(real_ (-1))))

t46 :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t46 = normal (real_ 4) (prob_ 5) >>= \x -> dirac (if_ (x < (real_ 3)) (x*x) (x-one))

t47 :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t47 = unsafeSuperpose
    [ (one, normal (real_ 4) (prob_ 5) >>= \x -> if_ (x < (real_ 3)) (dirac (x*x)) (reject sing))
    , (one, normal (real_ 4) (prob_ 5) >>= \x -> if_ (x < (real_ 3)) (reject sing) (dirac (x-one)))
    ]

t48 :: (ABT Term abt) => abt '[] (HPair 'HReal 'HReal ':-> 'HMeasure 'HReal)
t48 = lam $ \x -> uniform (real_ (-5)) (real_ 7) >>= \w -> dirac ((fst x + snd x) * w)

t49 :: (ABT Term abt) => abt '[] ('HMeasure 'HProb)
t49 = gamma (prob_ 0.01)  (prob_ 0.35)

t50 :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t50 = uniform one (real_ 3) >>= \x -> normal one (unsafeProb x)

t51 :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t51 = t31 >>= \x -> normal x one

-- Example 1 from Chang & Pollard's Conditioning as Disintegration
t52 :: (ABT Term abt) => abt '[] ('HMeasure (HPair 'HReal (HPair 'HReal 'HReal)))
t52 =
    uniform_0_1 >>= \x ->
    uniform_0_1 >>= \y ->
    dirac (pair (max y x) (pair x y))

t53, t53', t53'' :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure HUnit)
t53 =
    lam $ \x ->
    unsafeSuperpose
        [ (one, unsafeSuperpose
            [ (one,
                if_ (zero < x)
                    (if_ (x < one) (dirac unit) (reject sing))
                    (reject sing))
            ])
        , (one, if_ false (dirac unit) (reject sing))
        ]
t53' =
    lam $ \x ->
    unsafeSuperpose
        [ (one,
            if_ (zero < x)
                (if_ (x < one) (dirac unit) (reject sing))
                (reject sing))
        , (one, if_ false (dirac unit) (reject sing))
        ]
t53'' =
    lam $ \x ->
    if_ (zero < x && x < one) (dirac unit) (reject sing)

t54 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure HUnit)
t54 =
    lam $ \x0 ->
    (   dirac x0 >>= \x1 ->
        (negate <$> uniform_0_1) >>= \x2 ->
        dirac (x1 + x2)
    ) >>= \x1 ->
    (   (   (dirac zero >>= \x2 ->
            dirac x1 >>= \x3 ->
            dirac (x2 < x3)
            ) >>= \x2 ->
        if_ x2
            (recip <$> dirac x1)
            (dirac zero)
        ) >>= \x2 ->
        weight (unsafeProb x2)
    ) >>
    (log <$> dirac (unsafeProb x1)) >>= \x3 ->
    (negate <$> dirac x3) >>= \x4 ->
    (
        (dirac zero >>= \x5 ->
        dirac x4 >>= \x6 ->
        dirac (x5 < x6)
        ) >>= \x5 ->
        if_ x5
            (   (dirac x4 >>= \x6 ->
                dirac one >>= \x7 ->
                dirac (x6 < x7)
                ) >>= \x6 ->
            if_ x6 (dirac one) (dirac zero)
            )
         (dirac zero)
    ) >>= \x5 ->
    weight (unsafeProb x5)

t55, t55' :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure HUnit)
t55 =
    lam $ \t ->
    uniform_0_1 >>= \x ->
    if_ (x < t) (dirac unit) (reject sing)
t55' =
    lam $ \t ->
    if_ (t < zero) (reject sing) $
    if_ (t < one) (weight (unsafeProb t)) $
    dirac unit

t56, t56', t56'' :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure HUnit)
t56 =
    lam $ \x0 ->
    (   dirac x0 >>= \x1 ->
        (negate <$> uniform_0_1) >>= \x2 ->
        dirac (x1 + x2)
    ) >>= \x1 ->
    (   (dirac zero >>= \x2 ->
        dirac x1 >>= \x3 ->
        dirac (x2 < x3)
        ) >>= \x2 ->
    if_ x2
        (   (dirac x1 >>= \x3 ->
            dirac one >>= \x4 ->
            dirac (x3 < x4)
            ) >>= \x3 ->
        if_ x3 (dirac one) (dirac zero))
        (dirac zero)
    ) >>= \x2 ->
    withWeight (unsafeProb x2) (dirac unit)
t56' =
    lam $ \x0 ->
    uniform_0_1 >>= \x1 ->
    if_ (x0 - one < x1 && x1 < x0)
        (dirac unit)
        (reject sing)
t56'' =
    lam $ \t ->
    if_ (t <= zero) (reject sing) $
    if_ (t <= one) (weight (unsafeProb t)) $
    if_ (t <= (real_ 2)) (weight (unsafeProb ((real_ 2) + t * negate one))) $
    reject sing

t57, t57' :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure HUnit)
t57 = lam $ \t -> unsafeSuperpose
    [ (one, if_ (t < one)  (dirac unit) (reject sing))
    , (one, if_ (zero < t) (dirac unit) (reject sing)) ]
t57' = lam $ \t -> 
    if_ (t < one && zero < t) (weight (prob_ 2)) (dirac unit)

t58, t58' :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure HUnit)
t58 = lam $ \t -> unsafeSuperpose
    [ (one, if_ (zero < t && t < (real_ 2)) (dirac unit) (reject sing))
    , (one, if_ (one  < t && t < (real_ 3)) (dirac unit) (reject sing)) ]
t58' = lam $ \t ->
    if_ (if_ (zero < t) (t < (real_ 2)) false)
        (if_ (if_ (one < t) (t < (real_ 3)) false)
            (weight (prob_ 2))
            (dirac unit))
        (if_ (if_ (one < t) (t < (real_ 3)) false)
            (dirac unit)
            (reject sing))

t59 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure HUnit)
t59 =
    lam $ \x0 ->
    ((recip <$> uniform_0_1) >>= \x1 ->
     (((dirac zero >>= \x2 ->
        dirac x1 >>= \x3 ->
        dirac (x2 < x3)) >>= \x2 ->
       if_ x2
           (dirac x1)
           (negate <$> dirac x1)) >>= \x2 ->
      weight (unsafeProb x2) ) >>
     dirac x0 >>= \x3 ->
     dirac x1 >>= \x4 ->
     dirac (x3 * x4)) >>= \x1 ->
    (dirac x1 >>= \x2 ->
     (negate <$> uniform_0_1) >>= \x3 ->
     dirac (x2 + x3)) >>= \x2 ->
    ((dirac zero >>= \x3 ->
      dirac x2 >>= \x4 ->
      dirac (x3 < x4)) >>= \x3 ->
     if_ x3
         ((dirac x2 >>= \x4 ->
           dirac one >>= \x5 ->
           dirac (x4 < x5)) >>= \x4 ->
          if_ x4 (dirac one) (dirac zero))
         (dirac zero)) >>= \x3 ->
    weight (unsafeProb x3) 

t60,t60',t60'' :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure HUnit)
t60 =
    lam $ \x0 ->
    (((uniform_0_1 >>= \x1 ->
       uniform_0_1 >>= \x2 ->
       dirac (x1 + x2)) >>= \x1 ->
      dirac (recip x1)) >>= \x1 ->
     (((dirac zero >>= \x2 ->
        dirac x1 >>= \x3 ->
        dirac (x2 < x3)) >>= \x2 ->
       if_ x2
           (dirac x1)
           (negate <$> dirac x1)) >>= \x2 ->
      weight (unsafeProb x2) ) >>
     dirac x0 >>= \x3 ->
     dirac x1 >>= \x4 ->
     dirac (x3 * x4)) >>= \x1 ->
    ((dirac zero >>= \x2 ->
      dirac x1 >>= \x3 ->
      dirac (x2 < x3)) >>= \x2 ->
     if_ x2
         ((dirac x1 >>= \x3 ->
           dirac one >>= \x4 ->
           dirac (x3 < x4)) >>= \x3 ->
          if_ x3 (dirac one) (dirac zero))
         (dirac zero)) >>= \x2 ->
    weight (unsafeProb x2)
t60' =
    lam $ \x0 ->
    uniform_0_1 >>= \x1 ->
    uniform_0_1 >>= \x2 ->
    if_ (if_ (zero < x0 / (x2 + x1))
             (x0 / (x2 + x1) < one)
             false)
        (weight ((unsafeProb (x2 + x1)) ^^ negate one) )
        (reject sing)
t60'' =
    lam $ \x0 ->
    uniform_0_1 >>= \x1 ->
    uniform_0_1 >>= \x2 ->
    if_ (if_ (zero < x0 / (x2 + x1))
             (x0 / (x2 + x1) < one)
             false)
        (weight (recip (unsafeProb (x2 + x1))) )
        (reject sing)

t61, t61' :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure 'HProb)
t61 = lam $ \x -> if_ (x < zero) (dirac zero) $ dirac $ unsafeProb $ recip x
t61'= lam $ \x -> if_ (x < zero) (dirac zero) $ dirac $ unsafeProb $ recip x

---- "Special case" of t56
t62, t62' :: (ABT Term abt) => abt '[] ('HReal ':-> 'HReal ':-> 'HMeasure HUnit)
t62 = lam $ \t ->
      lam $ \x ->
      uniform_0_1 >>= \y ->
      if_ (zero < t/x - y && t/x - y < one)
          (dirac unit)
          (reject sing)
t62'= lam $ \t ->
      lam $ \x ->
      if_ (t/x <= zero) (reject sing) $
      if_ (t/x <= one) (weight (unsafeProb (t/x))) $
      if_ (t/x <= (real_ 2)) (weight (unsafeProb ((real_ 2)-t/x))) $
      reject sing

---- "Scalar multiple" of t62
t63, t63' :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure HUnit)
t63 = lam $ \t ->
      uniform_0_1 >>= \x ->
      uniform_0_1 >>= \y ->
      if_ (zero < t/x - y && t/x - y < one)
          (weight (recip (unsafeProb x)))
          (reject sing)
t63'= lam $ \t ->
      uniform_0_1 >>= \x ->
      if_ (t/x <= zero) (reject sing) $
      if_ (t/x <= one) (weight (unsafeProb (t/x) / unsafeProb x)) $
      if_ (t/x <= (real_ 2)) (weight (unsafeProb ((real_ 2)-t/x) / unsafeProb x)) $
      reject sing

-- Density calculation for (Exp (Log StdRandom)) and StdRandom
t64, t64', t64'' :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure HUnit)
t64 = lam $ \x0 ->
      (((dirac zero >>= \x1 ->
         dirac x0 >>= \x2 ->
         dirac (x1 < x2)) >>= \x1 ->
        if_ x1
            (recip <$> dirac x0)
            (dirac zero)) >>= \x1 ->
       weight (unsafeProb x1)) >>
      (log <$> dirac (unsafeProb x0)) >>= \x2 ->
      ((exp <$> dirac x2) >>= \x3 ->
       weight x3) >>
      (exp <$> dirac x2) >>= \x4 ->
      ((dirac zero >>= \x5 ->
        dirac x4 >>= \x6 ->
        dirac (x5 < x6)) >>= \x5 ->
       if_ x5
           ((dirac x4 >>= \x6 ->
             dirac one >>= \x7 ->
             dirac (x6 < x7)) >>= \x6 ->
            if_ x6 (dirac one) (dirac zero))
           (dirac zero)) >>= \x5 ->
      weight (unsafeProb x5) 
t64' =lam $ \x0 ->
      ((dirac zero >>= \x1 ->
        dirac x0 >>= \x2 ->
        dirac (x1 < x2)) >>= \x1 ->
       if_ x1
           ((dirac x0 >>= \x2 ->
             dirac one >>= \x3 ->
             dirac (x2 < x3)) >>= \x2 ->
            if_ x2 (dirac one) (dirac zero))
           (dirac zero)) >>= \x1 ->
      weight (unsafeProb x1) 
t64''=lam $ \x0 ->
      if_ (zero < x0 && x0 < one) 
          (dirac unit)
          (reject sing)

-- Density calculation for (Add StdRandom (Exp (Neg StdRandom))).
-- Maple can integrate this but we don't simplify it for some reason.
t65, t65' :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure HUnit)
t65 =
    lam $ \t ->
    uniform_0_1 >>= \x ->
    if_ (zero < t-x)
        (let_ (unsafeProb (t-x)) $ \t_x ->
        withWeight (recip t_x) $
        (if_ (zero < negate (log t_x) && negate (log t_x) < one)
            (dirac unit)
            (reject sing)))
        (reject sing)
t65' =
     lam $ \t ->
     uniform_0_1  >>= \x->
     withWeight (if_ (real_ 0 < (log (unsafeProb (t + x * real_ (-1))) * real_ (-1)) &&
                      x < (t * fromProb (exp (real_ 1)) + real_ (-1)) * fromProb (exp (real_ (-1))) &&
                      x < t)
                 (unsafeProb (recip (t * real_ (-1) + x)))
                 (prob_ 0)) $ (dirac unit)

half' :: (ABT Term abt) => abt '[] 'HReal
half' = half

t66 :: (ABT Term abt) => abt '[] ('HMeasure 'HProb)
t66 = dirac (sqrt $ prob_ 3 + (sqrt $ prob_ 3))

t67 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HReal ':-> 'HMeasure 'HProb)
t67 = lam $ \p -> lam $ \r -> dirac (exp (r * fromProb p))

t68 :: (ABT Term abt)
    => abt '[] ('HProb ':-> 'HProb ':-> 'HReal ':-> 'HMeasure 'HReal)
t68 =
    lam $ \x4 ->
    lam $ \x5 ->
    lam $ \x1 ->
    lebesgue >>= \x2 ->
    lebesgue >>= \x3 ->
    withWeight (exp (negate (x2 - x3) * (x2 - x3)
                     * recip (fromProb ((fromRational 2) * exp (log x4 * (fromRational 2)))))
              * recip x4
              * recip (exp (log ((fromRational 2) * pi) * half)))
             (withWeight (exp (negate (x1 - x3) * (x1 - x3)
                             * recip (fromProb ((fromRational 2) * exp (log x5 * (fromRational 2)))))
                      * recip x5
                      * recip (exp (log ((fromRational 2) * pi) * half)))
                     (withWeight (exp (negate x3 * x3
                                     * recip (fromProb ((fromRational 2) * exp (log x4 * (fromRational 2)))))
                              * recip x4
                              * recip (exp (log ((fromRational 2) * pi) * half)))
                             (dirac x2)))

t68' :: (ABT Term abt) => abt '[] ('HProb ':-> 'HReal ':-> 'HMeasure 'HReal)
t68' = lam $ \noise -> app (app t68 noise) noise

t69x, t69y :: (ABT Term abt) => abt '[] ('HMeasure 'HProb)
t69x = dirac (integrate one (real_ 2) $ \x -> integrate (real_ 3) (real_ 4) $ \_ -> unsafeProb x)
t69y = dirac (integrate one (real_ 2) $ \_ -> integrate (real_ 3) (real_ 4) $ \y -> unsafeProb y)

t70a, t71a, t72a, t73a, t74a :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t70a = uniform one (real_ 3) >>= \x -> if_ ((real_ 4) < x) (reject sing) (dirac x)
t71a = uniform one (real_ 3) >>= \x -> if_ ((real_ 3) < x) (reject sing) (dirac x)
t72a = uniform one (real_ 3) >>= \x -> if_ ((real_ 2) < x) (reject sing) (dirac x)
t73a = uniform one (real_ 3) >>= \x -> if_ (one < x) (reject sing) (dirac x)
t74a = uniform one (real_ 3) >>= \x -> if_ (zero < x) (reject sing) (dirac x)

t70b, t71b, t72b, t73b, t74b :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t70b = uniform one (real_ 3) >>= \x -> if_ ((real_ 4) < x) (dirac x) (reject sing)
t71b = uniform one (real_ 3) >>= \x -> if_ ((real_ 3) < x) (dirac x) (reject sing)
t72b = uniform one (real_ 3) >>= \x -> if_ ((real_ 2) < x) (dirac x) (reject sing)
t73b = uniform one (real_ 3) >>= \x -> if_ (one < x) (dirac x) (reject sing)
t74b = uniform one (real_ 3) >>= \x -> if_ (zero < x) (dirac x) (reject sing)

t70c, t71c, t72c, t73c, t74c :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t70c = uniform one (real_ 3) >>= \x -> if_ (x < (real_ 4)) (dirac x) (reject sing)
t71c = uniform one (real_ 3) >>= \x -> if_ (x < (real_ 3)) (dirac x) (reject sing)
t72c = uniform one (real_ 3) >>= \x -> if_ (x < (real_ 2)) (dirac x) (reject sing)
t73c = uniform one (real_ 3) >>= \x -> if_ (x < one) (dirac x) (reject sing)
t74c = uniform one (real_ 3) >>= \x -> if_ (x < zero) (dirac x) (reject sing)

t70d, t71d, t72d, t73d, t74d :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t70d = uniform one (real_ 3) >>= \x -> if_ (x < (real_ 4)) (reject sing) (dirac x)
t71d = uniform one (real_ 3) >>= \x -> if_ (x < (real_ 3)) (reject sing) (dirac x)
t72d = uniform one (real_ 3) >>= \x -> if_ (x < (real_ 2)) (reject sing) (dirac x)
t73d = uniform one (real_ 3) >>= \x -> if_ (x < one) (reject sing) (dirac x)
t74d = uniform one (real_ 3) >>= \x -> if_ (x < zero) (reject sing) (dirac x)

t75 :: (ABT Term abt) => abt '[] ('HMeasure 'HNat)
t75 = gamma (prob_ 6) one >>= poisson

t75' :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure 'HNat)
t75' = lam $ \x -> gamma x one >>= poisson

t76 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure 'HReal)
t76 =
    lam $ \x ->
    lebesgue >>= \y ->
    withWeight (unsafeProb (abs y)) $
    if_ (y < one)
        (if_ (zero < y)
            (if_ (x * y < one)
                (if_ (zero < x * y)
                    (dirac (x * y))
                    (reject sing))
                (reject sing))
            (reject sing))
        (reject sing)

-- the (x * (-1)) below is an unfortunate artifact not worth fixing
t77 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure HUnit)
t77 =
    lam $ \x ->
    if_ (x < zero)
        (weight (recip (exp x)))
        (weight (exp x))

t78, t78' :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t78 = uniform zero (real_ 2) >>= \x2 -> withWeight (unsafeProb x2) (dirac x2)
t78' = beta (prob_ 2) one >>= \x -> dirac ((fromProb x) * (real_ 2))

-- what does this simplify to?
t79 :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t79 = dirac (real_ 3) >>= \x -> dirac (if_ (x == (real_ 3)) one x)

t80 :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t80 = gamma_1_1 >>= \t -> normal zero t

t81 :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t81 = uniform zero pi

t82 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HProb)
t82 = lam (densityUniform zero one)

t82' :: (ABT Term abt) => abt '[] ('HReal ':-> 'HProb)
t82' = lam $ \x -> one 

t83 :: (ABT Term abt) => abt '[] ('HNat ':-> 'HMeasure 'HNat)
t83 = lam $ \k ->
      plate k (\_ -> dirac (nat_ 1)) >>= \x ->
      dirac (size x)

t83' :: (ABT Term abt) => abt '[] ('HNat ':-> 'HMeasure 'HNat)
t83' = lam dirac

-- Testing round-tripping of some other distributions
testexponential :: (ABT Term abt) => abt '[] ('HMeasure 'HProb)
testexponential = exponential third

testCauchy :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
testCauchy = cauchy (real_ 5) (prob_ 3)

testMCMCPriorProp
    :: (ABT Term abt)
    => abt '[] (HPair 'HReal 'HReal ':-> 'HMeasure (HPair 'HReal 'HReal))
testMCMCPriorProp = mcmc (lam $ priorAsProposal norm) norm

testMHPriorProp
    :: (ABT Term abt)
    => abt '[]
        (HPair 'HReal 'HReal
        ':-> 'HMeasure (HPair (HPair 'HReal 'HReal) 'HProb))
testMHPriorProp = mh (lam $ priorAsProposal norm) norm

testPriorProp'
    :: (ABT Term abt)
    => abt '[]
        (HPair 'HReal 'HReal
        ':-> 'HMeasure (HPair (HPair 'HReal 'HReal) 'HProb))
testPriorProp' =
    lam $ \old ->
    unsafeSuperpose
        [(half,
            normal_0_1 >>= \x1 ->
            dirac (pair (pair x1 (snd old))
                (exp
                    ( (x1 * negate one + (old `unpair` \x2 x3 -> x2))
                    *   ( (old `unpair` \x2 x3 -> x2)
                        + (old `unpair` \x2 x3 -> x3) * (negate (real_ 2))
                        + x1)
                    * half))))
        , (half,
            normal zero (sqrt (prob_ 2)) >>= \x1 ->
            dirac (pair (pair (fst old) x1)
                (exp
                    ( (x1 + (old `unpair` \x2 x3 -> x3) * negate one)
                    *   ( (old `unpair` \x2 x3 -> x3)
                        + (old `unpair` \x2 x3 -> x2) * (negate (real_ 4))
                        + x1)
                    * (negate (real_ 1))/(real_ 4)))))
        ]

dup :: (ABT Term abt, SingI a)
    => abt '[] ('HMeasure a)
    -> abt '[] ('HMeasure (HPair a a))
dup m = let_ m (\m' -> liftM2 pair m' m')

norm_nox :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
norm_nox =
    normal_0_1 >>= \x ->
    normal x one >>= \y ->
    dirac y

norm_noy :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
norm_noy =
    normal_0_1 >>= \x ->
    normal x one >>
    dirac x

flipped_norm :: (ABT Term abt) => abt '[] ('HMeasure (HPair 'HReal 'HReal))
flipped_norm =
    normal zero one >>= \x ->
    normal x one >>= \y ->
    dirac (pair y x)

-- pull out some of the intermediate expressions for independent study
expr1 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HProb)
expr1 =
    lam $ \x0 ->
        (lam $ \_ ->
        lam $ \x2 ->
        lam $ \x3 ->
          (lam $ \x4 ->
            zero
            + one
              * (lam $ \x5 ->
                 (lam $ \x6 ->
                  zero
                  + exp (negate (x2 - zero) * (x2 - zero) / fromProb ((fromRational 2) * exp (log (fromRational 5) * (fromRational 2))))
                    / (fromRational 5)
                    / exp (log ((fromRational 2) * pi) * half)
                    * (lam $ \x7 -> x7 `app` unit) `app` x6)
                 `app` (lam $ \_ ->
                        (lam $ \x7 ->
                         (lam $ \x8 -> x8 `app` x2)
                         `app` (lam $ \_ ->
                                (lam $ \x9 ->
                                 (lam $ \x10 -> x10 `app` unit)
                                 `app` (lam $ \x10 ->
                                        (lam $ \x11 ->
                                         (lam $ \x12 -> x12 `app` x2)
                                         `app` (lam $ \_ ->
                                                (lam $ \x13 -> x13 `app` pair x2 x10) `app` x11))
                                        `app` x9))
                                `app` x7))
                        `app` x5))
                `app` x4)
           `app` (lam $ \x4 ->
                  (lam $ \x5 -> x5 `app` (x4 `unpair` \_ x7 -> x7)) `app` x3)
        )
        `app` unit
        `app` x0
        `app` (lam $ \_ -> one)

expr2 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HReal ':-> 'HProb)
expr2 =
    lam $ \x1 ->
    lam $ \x2 ->
        (lam $ \x3 ->
        lam $ \x4 ->
        lam $ \x5 ->
           (lam $ \x6 ->
            zero
            + one
              * (lam $ \x7 ->
                 (lam $ \x8 ->
                  zero
                  + exp (((negate x4) - x3) * (x4 - x3) / fromProb ((fromRational 2) * exp (log one * (fromRational 2))))
                    / one
                    / exp (log ((fromRational 2) * pi) * half)
                    * (lam $ \x9 -> x9 `app` unit) `app` x8)
                 `app` (lam $ \_ ->
                        (lam $ \x9 ->
                         (lam $ \x10 -> x10 `app` x4)
                         `app` (lam $ \_ ->
                                (lam $ \x11 ->
                                 (lam $ \x12 -> x12 `app` unit)
                                 `app` (lam $ \x12 ->
                                        (lam $ \x13 ->
                                         (lam $ \x14 -> x14 `app` x4)
                                         `app` (lam $ \_ ->
                                                (lam $ \x15 -> x15 `app` pair x4 x12) `app` x13))
                                        `app` x11))
                                `app` x9))
                        `app` x7))
                `app` x6)
           `app` (lam $ \x6 ->
                  (lam $ \x7 -> x7 `app` (x6 `unpair` \_ x9 -> x9)) `app` x5)
        )
        `app` x1
        `app` x2
        `app` (lam $ \_ -> one)

-- the one we need in testKernel
expr3 :: (ABT Term abt)
    => abt '[] (d ':-> 'HProb)
    -> abt '[] (d ':-> d ':-> 'HProb)
    -> abt '[] d -> abt '[] d -> abt '[] 'HProb
expr3 x0 x1 x2 x3 =
    let q = x0 `app` x3
            / x1 `app` x2 `app` x3
            * x1 `app` x3 `app` x2
            / x0 `app` x2
    in if_ (one < q) one q

-- testKernel :: Sample IO ('HReal ':-> 'HMeasure 'HReal)
testKernel :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure 'HReal)
testKernel =
-- Below is the output of testMcmc as of 2014-11-05
    let_ expr1 $ \x0 ->
    let_ expr2 $ \x1 ->
    lam $ \x2 ->
    normal x2 one >>= \x3 ->
    let_ (expr3 x0 x1 x2 x3) $ \x4 ->
    bern x4 >>= \x5 ->
    dirac (if_ x5 x3 x2)

-- this should be equivalent to the above
testKernel2 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HMeasure 'HReal)
testKernel2 =
    lam $ \x2 ->
    normal x2 one >>= \x3 ->
    let q = exp(negate (real_ 1)/(real_ 50)*(x3-x2)*(x3+x2)) in
    let_ (if_ (one < q) one q) $ \x4 ->
    bern x4 >>= \x5 ->
    dirac $ if_ x5 x3 x2

-- this comes from {Tests.Lazy,Examples.EasierRoadmap}.easierRoadmapProg1.  It is the
-- program post-disintegrate, as passed to Maple to simplify
rmProg1 :: (ABT Term abt) => abt '[]
    (HUnit
    ':-> HPair 'HReal 'HReal
    ':-> 'HMeasure (HPair 'HProb 'HProb))
rmProg1 =
    lam $ \_ ->
    lam $ \x1 ->
    x1 `unpair` \x2 x3 ->
    withWeight one $
    withWeight one $
    unsafeSuperpose
        [(one,
            withWeight one $
            lebesgue >>= \x4 ->
            unsafeSuperpose
                [(one,
                    withWeight one $
                    lebesgue >>= \x5 ->
                    withWeight one $
                    lebesgue >>= \x6 ->
                    withWeight
                        ( exp (negate (x3 - x6) * (x3 - x6)
                            / (fromProb ((fromRational 2) * exp (log (unsafeProb x5) * (fromRational 2)))))
                        / unsafeProb x5
                        / (exp (log ((fromRational 2) * pi) * half))) $
                    withWeight one $
                    lebesgue >>= \x7 ->
                    withWeight
                        ( exp (negate (x6 - x7) * (x6 - x7)
                            / (fromProb ((fromRational 2) * exp (log (unsafeProb x4) * (fromRational 2)))))
                        / (unsafeProb x4)
                        / (exp (log ((fromRational 2) * pi) * half))) $
                    withWeight
                        ( exp (negate (x2 - x7) * (x2 - x7)
                            / (fromProb ((fromRational 2) * exp (log (unsafeProb x5) * (fromRational 2)))))
                        / unsafeProb x5
                        / (exp (log ((fromRational 2) * pi) * half))) $
                    withWeight
                        ( exp (negate x7 * x7
                            / (fromProb ((fromRational 2) * exp (log (unsafeProb x4) * (fromRational 2)))))
                        / unsafeProb x4
                        / (exp (log ((fromRational 2) * pi) * half))) $
                    withWeight (recip (fromRational 3)) $
                    unsafeSuperpose
                        [(one,
                            if_ (x5 < (real_ 4))
                                (if_ (one < x5)
                                    (withWeight (recip (prob_ 5)) $
                                    unsafeSuperpose
                                        [(one,
                                            if_ (x4 < (real_ 8))
                                                (if_ ((real_ 3) < x4)
                                                    (dirac (pair (unsafeProb x4)
                                                        (unsafeProb x5)))
                                                    (reject sing))
                                                (reject sing))
                                        , (one, reject sing)])
                                    (reject sing))
                                (reject sing))
                , (one, reject sing)])
            , (one, reject sing)])
        , (one, reject sing)]

-- this comes from Examples.EasierRoadmap.easierRoadmapProg4'.
rmProg4
    :: (ABT Term abt)
    => abt '[]
        (HPair 'HReal 'HReal
        ':-> HPair 'HProb 'HProb
        ':-> 'HMeasure (HPair (HPair 'HProb 'HProb) 'HProb))
rmProg4 =
    lam $ \x0 ->
    let_ (lam $ \x1 ->
        (lam $ \x2 ->
         lam $ \x3 ->
         x3 `unpair` \x4 x5 ->
         let_ one $ \x6 ->
         let_ (let_ one $ \x7 ->
               let_ (let_ one $ \x8 ->
                     let_ (let_ one $ \x9 ->
                           let_ (let_ one $ \x10 ->
                                 let_ (let_ one $ \x11 ->
                                       let_ (x2 `unpair` \x12 _ ->
                                             x2 `unpair` \x14 _ ->
                                             x2 `unpair` \x16 _ ->
                                             x2 `unpair` \_ x19 ->
                                             x2 `unpair` \_ x21 ->
                                             x2 `unpair` \_ x23 ->
                                             x2 `unpair` \x24 _ ->
                                             x2 `unpair` \x26 _ ->
                                             x2 `unpair` \_ x29 ->
                                             x2 `unpair` \_ x31 ->
                                             let_ (recip pi
                                                   * exp ((x12 * x14 * (fromProb x4 * fromProb x4)
                                                            * (fromRational 2)
                                                            + fromProb x4 * fromProb x4 * x16 * x19
                                                              * (negate (fromRational 2))
                                                            + x21 * x23 * (fromProb x4 * fromProb x4)
                                                            + fromProb x5 * fromProb x5 * (x24 * x26)
                                                            + fromProb x5 * fromProb x5 * (x29 * x31))
                                                           * recip (fromProb x4 * fromProb x4
                                                                    * (fromProb x4 * fromProb x4)
                                                                    + fromProb x5 * fromProb x5
                                                                      * (fromProb x4 * fromProb x4)
                                                                      * (fromRational 3)
                                                                    + fromProb x5 * fromProb x5
                                                                      * (fromProb x5 * fromProb x5))
                                                           * (negate half))
                                                   * exp (log (exp (log x4 * (fromRational 4))
                                                                             + exp (log x5 * (fromRational 2))
                                                                               * exp (log x4 * (fromRational 2))
                                                                               * (fromRational 3)
                                                                             + exp (log x5 * (fromRational 4)))
                                                           * (negate half))
                                                   * (fromRational 1)/(fromRational 10)) $ \x32 ->
                                             let_ (let_ (recip (fromRational 3)) $ \x33 ->
                                                   let_ (let_ one $ \x34 ->
                                                         let_ (if_ (fromProb x5 < (fromRational 4))
                                                                   (if_ (one < fromProb x5)
                                                                        (let_ (recip (fromRational 5)) $ \x35 ->
                                                                         let_ (let_ one $ \x36 ->
                                                                               let_ (if_ (fromProb x4
                                                                                          < (fromRational 8))
                                                                                         (if_ ((fromRational 3)
                                                                                               < fromProb x4)
                                                                                              (let_ (fromRational 5) $ \x37 ->
                                                                                               let_ (let_ (pair x4 x5) $ \x38 ->
                                                                                                     pair (dirac x38)
                                                                                                          (lam $ \x39 ->
                                                                                                           x39
                                                                                                           `app` x38)) $ \x38 ->
                                                                                               pair (withWeight x37 $
                                                                                                     x38 `unpair` \x39 _ ->
                                                                                                     x39)
                                                                                                    (lam $ \x39 ->
                                                                                                     zero
                                                                                                     + x37
                                                                                                       * (x38 `unpair` \_ x41 ->
                                                                                                          x41)
                                                                                                         `app` x39))
                                                                                              (pair (reject sing)
                                                                                                    (lam $ \x37 ->
                                                                                                     zero)))
                                                                                         (pair (reject sing)
                                                                                               (lam $ \x37 ->
                                                                                                zero))) $ \x37 ->
                                                                               let_ one $ \x38 ->
                                                                               let_ (pair (reject sing)
                                                                                          (lam $ \x39 ->
                                                                                           zero)) $ \x39 ->
                                                                               pair (unsafeSuperpose [(x36,
                                                                                                 x37 `unpair` \x40 x41 ->
                                                                                                 x40),
                                                                                                (x38,
                                                                                                 x39 `unpair` \x40 x41 ->
                                                                                                 x40)])
                                                                                    (lam $ \x40 ->
                                                                                     zero
                                                                                     + x36
                                                                                       * (x37 `unpair` \x41 x42 ->
                                                                                          x42)
                                                                                         `app` x40
                                                                                     + x38
                                                                                       * (x39 `unpair` \x41 x42 ->
                                                                                          x42)
                                                                                         `app` x40)) $ \x36 ->
                                                                         pair (withWeight x35 $
                                                                               x36 `unpair` \x37 x38 ->
                                                                               x37)
                                                                              (lam $ \x37 ->
                                                                               zero
                                                                               + x35
                                                                                 * (x36 `unpair` \x38 x39 ->
                                                                                    x39)
                                                                                   `app` x37))
                                                                        (pair (reject sing)
                                                                              (lam $ \x35 -> zero)))
                                                                   (pair (reject sing)
                                                                         (lam $ \x35 -> zero))) $ \x35 ->
                                                         let_ one $ \x36 ->
                                                         let_ (pair (reject sing)
                                                                    (lam $ \x37 -> zero)) $ \x37 ->
                                                         pair (unsafeSuperpose [(x34,
                                                                           x35 `unpair` \x38 x39 ->
                                                                           x38),
                                                                          (x36,
                                                                           x37 `unpair` \x38 x39 ->
                                                                           x38)])
                                                              (lam $ \x38 ->
                                                               zero
                                                               + x34
                                                                 * (x35 `unpair` \x39 x40 -> x40)
                                                                   `app` x38
                                                               + x36
                                                                 * (x37 `unpair` \x39 x40 -> x40)
                                                                   `app` x38)) $ \x34 ->
                                                   pair (withWeight x33 $ x34 `unpair` \x35 x36 -> x35)
                                                        (lam $ \x35 ->
                                                         zero
                                                         + x33
                                                           * (x34 `unpair` \x36 x37 -> x37)
                                                             `app` x35)) $ \x33 ->
                                             pair (withWeight x32 $ x33 `unpair` \x34 x35 -> x34)
                                                  (lam $ \x34 ->
                                                   zero
                                                   + x32
                                                     * (x33 `unpair` \x35 x36 -> x36)
                                                       `app` x34)) $ \x12 ->
                                       pair (withWeight x11 $ x12 `unpair` \x13 x14 -> x13)
                                            (lam $ \x13 ->
                                             zero
                                             + x11
                                               * (x12 `unpair` \x14 x15 -> x15) `app` x13)) $ \x11 ->
                                 let_ one $ \x12 ->
                                 let_ (pair (reject sing) (lam $ \x13 -> zero)) $ \x13 ->
                                 pair (unsafeSuperpose [(x10, x11 `unpair` \x14 x15 -> x14),
                                                  (x12, x13 `unpair` \x14 x15 -> x14)])
                                      (lam $ \x14 ->
                                       zero + x10 * (x11 `unpair` \x15 x16 -> x16) `app` x14
                                       + x12 * (x13 `unpair` \x15 x16 -> x16) `app` x14)) $ \x10 ->
                           pair (withWeight x9 $ x10 `unpair` \x11 x12 -> x11)
                                (lam $ \x11 ->
                                 zero + x9 * (x10 `unpair` \x12 x13 -> x13) `app` x11)) $ \x9 ->
                     let_ one $ \x10 ->
                     let_ (pair (reject sing) (lam $ \x11 -> zero)) $ \x11 ->
                     pair (unsafeSuperpose [(x8, x9 `unpair` \x12 x13 -> x12),
                                      (x10, x11 `unpair` \x12 x13 -> x12)])
                          (lam $ \x12 ->
                           zero + x8 * (x9 `unpair` \x13 x14 -> x14) `app` x12
                           + x10 * (x11 `unpair` \x13 x14 -> x14) `app` x12)) $ \x8 ->
               pair (withWeight x7 $ x8 `unpair` \x9 x10 -> x9)
                    (lam $ \x9 ->
                     zero + x7 * (x8 `unpair` \x10 x11 -> x11) `app` x9)) $ \x7 ->
         pair (withWeight x6 $ x7 `unpair` \x8 x9 -> x8)
              (lam $ \x8 -> zero + x6 * (x7 `unpair` \x9 x10 -> x10) `app` x8))
        `app` x0
        `app` x1 `unpair` \x2 x3 ->
        x3 `app` (lam $ \x4 -> one)) $ \x1 ->
  lam $ \x2 ->
  (x2 `unpair` \x3 x4 ->
   unsafeSuperpose [(half,
               uniform (real_ 3) (real_ 8) >>= \x5 -> dirac (pair (unsafeProb x5) x4)),
              (half,
               uniform one (real_ 4) >>= \x5 ->
               dirac (pair x3 (unsafeProb x5)))]) >>= \x3 ->
  dirac (pair x3 (x1 `app` x3 / x1 `app` x2))


pairReject
    :: (ABT Term abt)
    => abt '[] (HPair ('HMeasure 'HReal) 'HReal)
pairReject =
    pair (reject (SMeasure SReal) >>= \_ -> dirac one)
         (real_ 2)

-- from a web question
-- these are mathematically equivalent, albeit at different types
chal1 :: (ABT Term abt) => abt '[]
    ('HProb ':-> 'HReal ':-> 'HReal ':-> 'HReal ':-> 'HMeasure HBool)
chal1 =
    lam $ \sigma ->
    lam $ \a     ->
    lam $ \b     ->
    lam $ \c     ->
    normal a sigma >>= \ya ->
    normal b sigma >>= \yb ->
    normal c sigma >>= \yc ->
    dirac (yb < ya && yc < ya)

chal2 :: (ABT Term abt) => abt '[]
    ('HProb ':-> 'HReal ':-> 'HReal ':-> 'HReal ':-> 'HMeasure 'HReal)
chal2 =
    lam $ \sigma ->
    lam $ \a     ->
    lam $ \b     ->
    lam $ \c     ->
    normal a sigma >>= \ya ->
    normal b sigma >>= \yb ->
    normal c sigma >>= \yc ->
    dirac (if_ (yb < ya && yc < ya) one zero)

chal3 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure 'HReal)
chal3 = lam $ \sigma -> app3 (app chal2 sigma) zero zero zero

--seismic :: (ABT Term abt) => abt '[]
--    (SE.HStation
--    ':-> HPair 'HReal (HPair 'HReal (HPair 'HProb 'HReal))
--    ':-> HPair 'HReal (HPair 'HReal (HPair 'HReal 'HProb))
--    ':-> 'HMeasure 'HProb)
--seismic = lam3 (\s e d -> dirac $ SE.densT s e d)

easyHMM :: (ABT Term abt) => abt '[]
    ('HMeasure (HPair (HPair 'HReal 'HReal) (HPair 'HProb 'HProb)))
easyHMM =
    gamma (prob_ 3)  one >>= \noiseT ->
    gamma_1_1 >>= \noiseE ->
    normal zero noiseT >>= \x1 ->
    normal x1 noiseE >>= \m1 ->
    normal x1 noiseT >>= \x2 ->
    normal x2 noiseE >>= \m2 ->
    dirac (pair (pair m1 m2) (pair noiseT noiseE))
