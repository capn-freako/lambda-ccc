{-# LANGUAGE TypeOperators, GADTs, KindSignatures, TypeSynonymInstances #-}
{-# LANGUAGE PatternGuards, ConstraintKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
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
  ( Ty(..),HasTy(..), tyEq', tyEq2'
  , HasTy2,HasTy3,HasTy4
  , HasTyJt(..), tyHasTy, tyHasTy2
  , pairTyHasTy, sumTyHasTy, funTyHasTy
  , splitFunTy, domTy, ranTy
  ) where

import Control.Applicative (liftA2)

import Data.IsTy
import Data.Proof.EQ

import LambdaCCC.Misc
import LambdaCCC.ShowUtils

infixr 1 :=>
infixl 6 :+
infixl 7 :*

-- | Typed type representation
data Ty :: * -> * where
  Unit  :: Ty Unit
  Int   :: Ty Int
  Bool  :: Ty Bool
  (:*)  :: Ty a -> Ty b -> Ty (a :*  b)
  (:+)  :: Ty a -> Ty b -> Ty (a :+  b)
  (:=>) :: Ty a -> Ty b -> Ty (a :=> b)

instance Show (Ty a) where
  showsPrec _ Unit      = showString "Unit"
  showsPrec _ Int       = showString "Int"
  showsPrec _ Bool      = showString "Bool"
  showsPrec p (a :*  b) = showsOp2' ":*"  (7,AssocLeft ) p a b
  showsPrec p (a :+  b) = showsOp2' ":+"  (6,AssocLeft ) p a b
  showsPrec p (a :=> b) = showsOp2' ":=>" (1,AssocRight) p a b

instance IsTy Ty where
  Unit      `tyEq` Unit        = Just Refl
  Int       `tyEq` Int         = Just Refl
  Bool      `tyEq` Bool        = Just Refl
  (a :*  b) `tyEq` (a' :*  b') = tyEqOp2 a b a' b'
  (a :+  b) `tyEq` (a' :+  b') = tyEqOp2 a b a' b'
  (a :=> b) `tyEq` (a' :=> b') = tyEqOp2 a b a' b'
  _         `tyEq` _           = Nothing

tyEqOp2 :: Ty a -> Ty b -> Ty a' -> Ty b' -> Maybe (op a b :=: op a' b')
tyEqOp2 a b a' b' = liftA2 liftEq2 (a `tyEq` a') (b `tyEq` b')

-- Inferred type:
-- 
--   (IsTyConstraint f1 a, IsTyConstraint f1 a', IsTyConstraint f2 b,
--    IsTyConstraint f2 b', IsTy f1, IsTy f2) =>
--   f1 a -> f1 a' -> f2 b -> f2 b' -> Maybe (f a b :=: f a' b')

-- | Variant of 'tyEq' from the 'ty' package. This one assumes 'HasTy'.
tyEq' :: forall a b f. (HasTy a, HasTy b, Eq (f a)) =>
         f a -> f b -> Maybe (a :=: b)
fa `tyEq'` fb
  | Just Refl <- (typ :: Ty a) `tyEq` (typ :: Ty b)
  , fa == fb  = Just Refl
  | otherwise = Nothing

-- | Variant of 'tyEq' from the 'ty' package. This one assumes 'HasTy'.
tyEq2' :: forall a b c d f. (HasTy a, HasTy b, HasTy c, HasTy d, Eq (f a b)) =>
          f a b -> f c d -> Maybe ((a,b) :=: (c,d))
fab `tyEq2'` fcd
  | Just Refl <- (typ :: Ty a) `tyEq` (typ :: Ty c)
  , Just Refl <- (typ :: Ty b) `tyEq` (typ :: Ty d)
  , fab == fcd = Just Refl
  | otherwise  = Nothing

{--------------------------------------------------------------------
    Type synthesis
--------------------------------------------------------------------}

-- TODO: Try out the singletons library

-- | Synthesize a type
class HasTy a where typ :: Ty a

type HasTy2 a b     = (HasTy  a, HasTy b)
type HasTy3 a b c   = (HasTy2 a b, HasTy c)
type HasTy4 a b c d = (HasTy3 a b c, HasTy d)

instance HasTy Unit where typ = Unit
instance HasTy Int  where typ = Int
instance HasTy Bool where typ = Bool
instance HasTy2 a b => HasTy (a :*  b) where typ = typ :*  typ
instance HasTy2 a b => HasTy (a :+  b) where typ = typ :+  typ
instance HasTy2 a b => HasTy (a :=> b) where typ = typ :=> typ

{--------------------------------------------------------------------
    Proofs
--------------------------------------------------------------------}

-- | Judgment (proof) that 'HasTy'
data HasTyJt :: * -> * where
  HasTy :: HasTy a => HasTyJt a

-- TODO: Consider a generic replacement for types like this one. Try the generic
-- Dict type from Edward K's "constraints" package. Replace HasTyJt a with
-- Dict (HasTy a).

-- | Proof of @'HasTy' a@ from @'Ty' a@
tyHasTy :: Ty a -> HasTyJt a
tyHasTy Unit = HasTy
tyHasTy Int  = HasTy
tyHasTy Bool = HasTy
tyHasTy (a :*  b) | (HasTy,HasTy) <- tyHasTy2 a b = HasTy
tyHasTy (a :+  b) | (HasTy,HasTy) <- tyHasTy2 a b = HasTy
tyHasTy (a :=> b) | (HasTy,HasTy) <- tyHasTy2 a b = HasTy

tyHasTy2 :: Ty a -> Ty b -> (HasTyJt a,HasTyJt b)
tyHasTy2 a b = (tyHasTy a,tyHasTy b)

pairTyHasTy :: Ty (a :* b) -> (HasTyJt a,HasTyJt b)
pairTyHasTy (a :* b) = tyHasTy2 a b

sumTyHasTy :: Ty (a :+ b) -> (HasTyJt a,HasTyJt b)
sumTyHasTy (a :+ b) = tyHasTy2 a b

funTyHasTy :: Ty (a :=> b) -> (HasTyJt a,HasTyJt b)
funTyHasTy (a :=> b) = tyHasTy2 a b


{--------------------------------------------------------------------
    Utilities
--------------------------------------------------------------------}

splitFunTy :: Ty (a -> b) -> (Ty a, Ty b)
splitFunTy (a :=> b) = (a,b)

domTy :: Ty (a -> b) -> Ty a
domTy = fst . splitFunTy

ranTy :: Ty (a -> b) -> Ty b
ranTy = snd . splitFunTy
