{-# LANGUAGE DeriveDataTypeable
           , DataKinds
           , RankNTypes
           , GADTs
           , PolyKinds
           , FlexibleContexts #-}
{-# OPTIONS_GHC -Wall -fwarn-tabs #-}
module Tests.TestTools where

import Language.Hakaru.Types.Sing
import Language.Hakaru.Parser.Parser (parseHakaru)
import Language.Hakaru.Parser.SymbolResolve (resolveAST)
import Language.Hakaru.Command (parseAndInfer, splitLines)
import Language.Hakaru.Syntax.ABT
import Language.Hakaru.Syntax.AST
import Language.Hakaru.Syntax.AST.Transforms(normalizeLiterals)
import Language.Hakaru.Syntax.TypeCheck
import Language.Hakaru.Syntax.AST.Eq (alphaEq)
import Language.Hakaru.Syntax.IClasses (TypeEq(..), jmEq1)
import Language.Hakaru.Pretty.Concrete
import Language.Hakaru.Simplify
import Language.Hakaru.Syntax.AST.Eq()
import Text.PrettyPrint (Doc)

import Data.Maybe (isJust)
import Data.List
import qualified Data.Text    as T
import qualified Data.Text.IO as IO
import Data.Typeable (Typeable)
import Control.Exception
import Control.Monad

import Test.HUnit

data TestException = TestSimplifyException String SomeException
    deriving Typeable
instance Exception TestException
instance Show TestException where
    show (TestSimplifyException prettyHakaru e) =
        show e ++ "\nwhile simplifying Hakaru:\n" ++ prettyHakaru

-- assert that we get a result and that no error is thrown
assertResult :: [a] -> Assertion
assertResult s = assertBool "no result" $ not $ null s

assertJust :: Maybe a -> Assertion
assertJust = assertBool "expected Just but got Nothing" . isJust

handleException :: String -> SomeException -> IO a
handleException t e = throw (TestSimplifyException t e)

testS
    :: (ABT Term abt)
    => String
    -> abt '[] a
    -> Assertion
testS p x = do
    _ <- simplify x `catch` handleException (p ++ ": simplify failed")
    return ()

testStriv 
    :: TrivialABT Term '[] a
    -> Assertion
testStriv = testS ""

-- Assert that all the given Hakaru programs simplify to the given one
testSS 
    :: (ABT Term abt)
    => String
    -> [(abt '[] a)] 
    -> abt '[] a 
    -> Assertion
testSS nm ts t' = 
     mapM_ (\t -> do p <- simplify t 
                     assertAlphaEq nm p t')
           (t':ts)

testSStriv 
    :: [(TrivialABT Term '[] a)] 
    -> TrivialABT Term '[] a 
    -> Assertion
testSStriv = testSS ""

assertAlphaEq ::
    (ABT Term abt) 
    => String
    -> abt '[] a
    -> abt '[] a
    -> Assertion
assertAlphaEq preface a' b' =
  let [a,b] = map normalizeLiterals [a',b'] in 
   unless (alphaEq a b) (assertFailure $ mismatchMessage pretty preface a b)

mismatchMessage :: forall (k :: q -> *) . (forall a . k a -> Doc) -> String -> forall a b . k a -> k b -> String 
mismatchMessage k preface a b = msg 
 where msg = concat [ p
                    , "expected:\n"
                    , show (k b)
                    , "\nbut got:\n"
                    , show (k a)
                    ]
       p = if null preface then "" else preface ++ "\n"

testWithConcrete ::
    (ABT Term abt)
    => T.Text
    -> TypeCheckMode
    -> (forall a. Sing a -> abt '[] a -> Assertion)
    -> Assertion
testWithConcrete s mode k =
    case parseHakaru s of
      Left  err  -> assertFailure (show err)
      Right past ->
          let m = inferType (resolveAST past) in
          case runTCM m (splitLines s) mode of
            Left err                 -> assertFailure (show err)
            Right (TypedAST typ ast) -> k typ ast


testWithConcrete'
    :: T.Text
    -> TypeCheckMode
    -> (forall a. Sing a -> TrivialABT Term '[] a -> Assertion)
    -> Assertion
testWithConcrete' = testWithConcrete

-- Function: testConcreteFiles
-- This function accepts two files; it simplifies the first and then 
-- compares the result to the second file. If the files are
-- alpha equivalent, the test is successful.
testConcreteFiles
    :: FilePath
    -> FilePath
    -> Assertion
testConcreteFiles f1 f2 = do
  t1 <- IO.readFile f1
  t2 <- IO.readFile f2
  case (parseAndInfer t1, parseAndInfer t2) of
    (Left err, _) -> assertFailure $ T.unpack err
    (_, Left err) -> assertFailure $ T.unpack err
    (Right (TypedAST typ1 ast1), Right (TypedAST typ2 ast2)) -> do
      case jmEq1 typ1 typ2 of
        Just Refl -> do
          ast1' <- simplify ast1
          assertAlphaEq "" ast1' ast2
        Nothing   -> assertFailure ("files don't have same type (File1 = " ++ (show typ1) ++ ", File2 = " ++ (show typ2))

ignore :: a -> Assertion
ignore _ = assertFailure "ignored"  -- ignoring a test reports as a failure

-- Runs a single test from a list of tests given its index
runTestI :: Test -> Int -> IO Counts
runTestI (TestList ts) i = runTestTT $ ts !! i
runTestI (TestCase _) _ = error "expecting a TestList, but got a TestCase"
runTestI (TestLabel _ _) _ = error "expecting a TestList, but got a TestLabel"

hasLab :: String -> Test -> Bool
hasLab l (TestLabel lab _) = lab == l
hasLab _ _ = False

-- Runs a single test from a TestList given its label
runTestN :: Test -> String -> IO Counts
runTestN (TestList ts) l =
  case find (hasLab l) ts of
    Just t -> runTestTT t
    Nothing -> error $ "no test with label " ++ l
runTestN (TestCase _) _ = error "expecting a TestList, but got a TestCase"
runTestN (TestLabel _ _) _ = error "expecting a TestList, but got a TestLabel"
