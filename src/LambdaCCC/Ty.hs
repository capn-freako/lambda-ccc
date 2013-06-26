{-# LANGUAGE TypeOperators, GADTs, KindSignatures, TypeSynonymInstances #-}
{-# LANGUAGE ConstraintKinds #-}
{-# OPTIONS_GHC -Wall #-}

-- {-# OPTIONS_GHC -fno-warn-unused-imports #-} -- TEMP
-- {-# OPTIONS_GHC -fno-warn-unused-binds   #-} -- TEMP

----------------------------------------------------------------------
-- |
-- Module      :  LambdaCCC.Ty
-- Copyright   :  (c) 2013 Tabula, Inc.
-- License     :  BSD3
-- 
-- Maintainer  :  conal@tabula.com
-- Stability   :  experimental
-- 
-- Typed types
----------------------------------------------------------------------

module LambdaCCC.Ty
  ( Ty(..),HasTy(..)
  , HasTy2,HasTy3,HasTy4
  , HasTyJt(..), tyHasTy, tyHasTy2
  ) where

import Control.Applicative (liftA2)

import Data.IsTy
import Data.Proof.EQ

import LambdaCCC.Misc
import LambdaCCC.ShowUtils

-- TODO: Try out the singletons library

-- | Typed type representation
data Ty :: * -> * where
  UnitT :: Ty Unit
  IntT  :: Ty Int
  BoolT :: Ty Bool
  (:*)  :: Ty a -> Ty b -> Ty (a :*  b)
  (:+)  :: Ty a -> Ty b -> Ty (a :+  b)
  (:=>) :: Ty a -> Ty b -> Ty (a :=> b)

instance Show (Ty a) where
  showsPrec _ UnitT     = showString "Unit"
  showsPrec _ IntT      = showString "Int"
  showsPrec _ BoolT     = showString "Bool"
  showsPrec p (a :*  b) = showsOp2' ":*"  (7,AssocLeft ) p a b
  showsPrec p (a :+  b) = showsOp2' ":+"  (6,AssocLeft ) p a b
  showsPrec p (a :=> b) = showsOp2' ":=>" (1,AssocRight) p a b

instance IsTy Ty where
  UnitT     `tyEq` UnitT       = Just Refl
  IntT      `tyEq` IntT        = Just Refl
  BoolT     `tyEq` BoolT       = Just Refl
  (a :*  b) `tyEq` (a' :*  b') = liftA2 liftEq2 (tyEq a a') (tyEq b b')
  (a :+  b) `tyEq` (a' :+  b') = liftA2 liftEq2 (tyEq a a') (tyEq b b')
  (a :=> b) `tyEq` (a' :=> b') = liftA2 liftEq2 (tyEq a a') (tyEq b b')
  _         `tyEq` _           = Nothing

-- | Synthesize a type
class HasTy a where typ :: Ty a

type HasTy2 a b     = (HasTy a, HasTy b)
type HasTy3 a b c   = (HasTy2 a b, HasTy c)
type HasTy4 a b c d = (HasTy2 a b, HasTy2 c d)

instance HasTy Unit where typ = UnitT
instance HasTy Int  where typ = IntT
instance HasTy Bool where typ = BoolT
instance HasTy2 a b => HasTy (a :*  b) where typ = typ :*  typ
instance HasTy2 a b => HasTy (a :+  b) where typ = typ :+  typ
instance HasTy2 a b => HasTy (a :=> b) where typ = typ :=> typ

-- | Judgment (proof) that 'HasTy'
data HasTyJt :: * -> * where
  HasTy :: HasTy a => HasTyJt a

-- | Proof of @'HasTy' a@ from @'Ty' a@
tyHasTy :: Ty a -> HasTyJt a
tyHasTy UnitT = HasTy
tyHasTy IntT  = HasTy
tyHasTy BoolT = HasTy
tyHasTy (a :*  b) | (HasTy,HasTy) <- tyHasTy2 a b = HasTy
tyHasTy (a :+  b) | (HasTy,HasTy) <- tyHasTy2 a b = HasTy
tyHasTy (a :=> b) | (HasTy,HasTy) <- tyHasTy2 a b = HasTy

tyHasTy2 :: Ty a -> Ty b -> (HasTyJt a,HasTyJt b)
tyHasTy2 a b = (tyHasTy a,tyHasTy b)
