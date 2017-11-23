{-# LANGUAGE OverloadedStrings
           , DataKinds
           , GADTs
           , KindSignatures #-}

module Tests.Hakaru where

import qualified Language.Hakaru.Parser.AST as U
import Language.Hakaru.Parser.Parser (parseHakaru)
import Language.Hakaru.Parser.SymbolResolve (resolveAST)


import qualified Language.Hakaru.Syntax.AST as T
import Language.Hakaru.Syntax.IClasses
import Language.Hakaru.Types.HClasses
import Data.Number.Nat
import Language.Hakaru.Syntax.ABT
import Language.Hakaru.Types.Sing
import Language.Hakaru.Types.DataKind

import Language.Hakaru.Syntax.TypeCheck
import Language.Hakaru.Syntax.Value
import Language.Hakaru.Pretty.Concrete
import Language.Hakaru.Sample
import Language.Hakaru.Disintegrate
import Language.Hakaru.Expect
import Language.Hakaru.Syntax.Prelude (prob_, fromProb, real_)
import Language.Hakaru.Simplify

import Prelude hiding (unlines)
import Data.Text hiding (head)
import Text.PrettyPrint

import qualified System.Random.MWC as MWC

five, normal01, normalb, uniform01 :: Text

five      = "2 + 3"
uniform01 = "uniform(-0.0,1.0)"
normal01  = "normal(-0.0,1.0)"
normalb   = unlines
    [ "x <~ normal(-2.0,1.0)"
    , "y <~ normal(x, 1.0)"
    , "return y"
    ]

x :: TrivialABT T.Term '[] 'HReal
x = var (Variable "x" 0 SReal)

                    
inferType' :: U.AST -> TypeCheckMonad (TypedAST (TrivialABT T.Term))
inferType' = inferType

checkType' :: Sing a
           -> U.AST
           -> TypeCheckMonad (TrivialABT T.Term '[] a)
checkType' = checkType

illustrate :: Sing a -> MWC.GenIO -> Value a -> IO String
illustrate SNat  g x = return (show x)
illustrate SInt  g x = return (show x)
illustrate SProb g x = return (show x)
illustrate SReal g x = return (show x)
illustrate (SData _ _) g d = return (show d)
illustrate (SMeasure s) g (VMeasure m) = do
    Just (samp,_) <- m (VProb 1) g
    illustrate s g samp
illustrate s _ _ = return ("<" ++ show s ++ ">")


testHakaru :: Text -> TypeCheckMode -> MWC.GenIO -> IO String
testHakaru a mode g =
    case parseHakaru a of
    Left err -> return (show err)
    Right past ->
        let m = inferType' (resolveAST past) in
        case runTCM m mode of
        Left err                 -> return err
        Right (TypedAST typ ast) -> do
            putStr   "Type: "
            putStrLn . show $ prettyType 0 typ
            putStrLn ""
            putStrLn "AST:"
            putStrLn . show $ pretty ast
            putStrLn ""
            case typ of
                SMeasure _ -> do
                    ast' <- simplify ast
                    putStrLn "AST + Simplify:"
                    putStrLn . show $ pretty ast'
                    putStrLn ""
                    putStrLn "Expectation wrt 1 as ast:"
                    putStrLn . show . pretty $ total ast
                    putStrLn ""
                    case typ of
                      SMeasure SReal -> do 
                          putStrLn $ "Observe to be " ++ (show $ pretty x) ++ ":"
                          putStrLn . show . pretty . head $ observe ast x
                      _ -> return ()
                _ -> return ()
            illustrate typ g $ run ast
    where
    run :: TrivialABT T.Term '[] a -> Value a
    run = runEvaluate

checkHakaru :: Text
            -> Sing (a :: Hakaru)
            -> TypeCheckMode
            -> MWC.GenIO
            -> IO ()
checkHakaru a typ mode g =
    case parseHakaru a of
    Left err -> putStrLn (show err)
    Right past ->
        let m = checkType' typ (resolveAST past) in
        case runTCM m mode of
        Left  err -> putStrLn err
        Right ast -> do
            putStr   "Type: "
            putStrLn . show $ prettyType 0 typ
            putStrLn ""
            putStrLn "AST:"
            putStrLn . show $ pretty ast
            putStrLn ""
