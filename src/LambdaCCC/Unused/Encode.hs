{-# LANGUAGE TypeFamilies, TypeOperators #-}
{-# LANGUAGE FlexibleInstances, FlexibleContexts #-}
{-# LANGUAGE UndecidableInstances #-}   -- See below
{-# LANGUAGE CPP #-}

{-# OPTIONS_GHC -Wall #-}

-- {-# OPTIONS_GHC -fno-warn-unused-imports #-} -- TEMP
-- {-# OPTIONS_GHC -fno-warn-unused-binds   #-} -- TEMP

----------------------------------------------------------------------
-- |
-- Module      :  LambdaCCC.Encode
-- Copyright   :  (c) 2013 Tabula, Inc.
-- License     :  BSD3
-- 
-- Maintainer  :  conal@tabula.com
-- Stability   :  experimental
-- 
-- Statically typed lambda expressions
----------------------------------------------------------------------

-- #define VecsAndTrees

module LambdaCCC.Encode (Encodable(..),(-->),recode) where

import Control.Arrow ((+++)) -- ,(***)
import Data.Monoid (Any(..),All(..))

-- transformers
import Data.Functor.Identity

#ifdef VecsAndTrees
import TypeUnary.TyNat (Z,S)
import TypeUnary.Nat (Nat(..),IsNat(..))
import TypeUnary.Vec (Vec(..),unConsV)
import Circat.Pair (Pair(..),toP,fromP)
import Circat.RTree (Tree(..),toL,unL,toB,unB)
#endif

import LambdaCCC.Misc (Unit,(:+),(:*))

infixr 1 -->
-- | Add pre- and post processing
(-->) :: (a' -> a) -> (b -> b') -> ((a -> b) -> (a' -> b'))
(f --> h) g = h . g . f

-- (-->) :: Category k =>
--          (a' `k` a) -> (b `k` b') -> ((a `k` b) -> (a' `k` b'))

-- Slightly different from Arrow.***. No lazy pattern.
-- Makes neater code.
infixr 3 ***
(***) :: (a -> c) -> (b -> d) -> (a :* b -> c :* d)
(f *** g) (x,y) = (f x, g y)

-- Inlining!
#define INS {-# INLINE encode #-} ; {-# INLINE decode #-}

-- | Encoding and decoding. Must be inverses, and @'Encode' a@ must have a
-- standard type. A type is standard iff it is '()', 'Bool', 'Int' (for now), or
-- a binary product, sum, or function over standard types.
class Encodable a where
  type Encode a
  encode :: a -> Encode a
  decode :: Encode a -> a

#define EncTy(n,o) type Encode (n) = o ; INS

instance (Encodable a, Encodable b) => Encodable (a :* b) where
  -- EncTy(a :* b, Encode a :* Encode b)
  EncTy((a,b), (Encode a,Encode b))
  encode = encode *** encode
  decode = decode *** decode

instance (Encodable a, Encodable b) => Encodable (a :+ b) where
  EncTy(a :+ b, Encode a :+ Encode b)
  encode = encode +++ encode
  decode = decode +++ decode

instance (Encodable a, Encodable b) => Encodable (a -> b) where
  EncTy(a -> b, Encode a -> Encode b)
  encode = decode --> encode
  decode = encode --> decode

#define PrimEncode(t) \
 instance Encodable (t) where { EncTy(t,t) ; encode = id ; decode = id }

PrimEncode(Unit)
PrimEncode(Bool)
PrimEncode(Int)

-- instance Encodable Bool where
--   EncTy(Bool,() :+ ())
--   encode False = Left ()
--   encode True  = Right ()
--   decode (Left  ()) = False
--   decode (Right ()) = True

{--------------------------------------------------------------------
    Library types
--------------------------------------------------------------------}

#define EEncTy(n,o) EncTy(n,Encode(o))

#define RepEncode(n,o,unwrap,wrap) \
  instance Encodable (o) => Encodable (n) where \
    { EEncTy(n,o) ; encode = encode . (unwrap) ; decode = (wrap) . decode }

-- TODO: Can we get some help from the Newtype class?

#ifdef VecsAndTrees

RepEncode(Nat Z, (), \ Zero -> (), \ () -> Zero)
-- RepEncode(Nat (S n), Nat n, predN, Succ)

instance IsNat n => Encodable (Nat (S n)) where
  EEncTy (Nat (S n),())
  encode = const ()
  decode = const nat

-- instance (IsNat n, Encodable (Nat n)) => Encodable (Nat (S n)) where
--   EEncTy (Nat (S n),Nat n)
--   encode (Succ m) = encode m
--   decode x = Succ (decode x)

RepEncode(Pair a, a :* a, fromP, toP)

RepEncode(Vec Z a, (), \ ZVec -> (), \ () -> ZVec)
RepEncode(Vec (S n) a, a :* Vec n a, unConsV, (\ (a,b) -> a :< b))
-- RepEncode(Vec (S n) a, a :* Vec n a, unConsV, uncurry (:<))
-- The non-lazy pattern match gives tighter code than uncurry
RepEncode(Tree Z a, a, unL, toL)
RepEncode(Tree (S n) a, Pair (Tree n a), unB, toB)

#endif

-- Standard newtypes:
RepEncode(Any,Bool,getAny,Any)
RepEncode(All,Bool,getAll,All)
-- etc

--     Application is no smaller than the instance head
--       in the type family application: Encode Bool
--     (Use UndecidableInstances to permit this)
--     In the type instance declaration for ‘Encode’
--     In the instance declaration for ‘Encodable (Any)’

RepEncode(Identity a, a, runIdentity, Identity)

-- | Identity via 'encode' and decode.
recode :: Encodable a => a -> a
recode = decode . encode
