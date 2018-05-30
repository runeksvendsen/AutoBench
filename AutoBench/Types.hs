
{-# LANGUAGE DeriveGeneric        #-}
{-# OPTIONS_GHC -Wall             #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

{-|

  Module      : AutoBench.Types
  Description : User datatypes and associated helper functions\/defaults.
  Copyright   : (c) 2018 Martin Handley
  License     : BSD-style
  Maintainer  : martin.handley@nottingham.ac.uk
  Stability   : Experimental
  Portability : GHC

  This module defines datatypes to be used in user input files.

-}

{-
   ----------------------------------------------------------------------------
   <TO-DO>:
   ----------------------------------------------------------------------------
   - 
-}

module AutoBench.Types 
  (

  -- * User inputs
  -- ** Test suites
    TestSuite(..)          -- Test suites are AutoBench's principle user input datatype.
  -- ** Test data options
  , UnaryTestData          -- User-specified test data for unary test programs.
  , BinaryTestData         -- User-specified test data for binary test programs.
  , DataOpts(..)           -- Test data options.
  -- ** Statistical analysis options
  , AnalOpts(..)           -- Statistical analysis options.
  -- * Benchmarking
  -- * Statistical analysis
  , LinearType(..)                                                                                      -- <TO-DO>
  , Stats(..)                                                                                           -- <TO-DO>

  ) where

import           Control.DeepSeq                  (NFData)
import qualified Criterion.Types                  as Criterion
import qualified Criterion.Main                   as Criterion
import           Data.Default                     (Default(..))
import           Data.List                        (genericLength)
import           GHC.Generics                     (Generic)
import           Numeric.MathFunctions.Comparison (relativeError)

import AutoBench.Internal.AbstractSyntax (Id)
import AutoBench.Internal.Utils          (subNum, superNum)


-- To be able to DeepSeq CR.Config add NFData instances:
instance NFData Criterion.Verbosity
instance NFData Criterion.Config

-- * User inputs

-- ** Test suites

-- | Test suites are AutoBench's principle user input datatype, and are used to 
-- structure performance tests into logical units that can be checked, 
-- validated, and executed independently. 
--
-- An advantage of this approach is that users can group multiple test 
-- suites in the same file according to some testing context, whether it be 
-- analysing the performance of the same programs subject to different levels 
-- of optimisation, or comparing different implementations under the same
-- test conditions. Another advantage is that if one or more test suites in an 
-- input file are erroneous, other, valid test suites in the same file can be 
-- executed nonetheless.
--
-- Test suites contain a significant number of user options and settings. As 
-- such, the system provides the following defaults,
--
-- @ TestSuite
--     { _progs    = []                                     -- All programs in the test file will be considered for test purposes.
--     , _dataOpts = def                                    -- See 'DataOpts'.
--     , _analOpts = def                                    -- See 'AnalOpts'.
--     , _critCfg  = Criterion.Main.Options.defaultConfig   -- See 'Criterion.Main.Options.defaultConfig'
--     , _baseline = False                                  -- No baseline measurements.
--     , _nf       = True                                   -- Evaluate test cases to normal form.
--     , _ghcFlags = []                                     --/No optimisation, i.e., -O0.
--     }
-- @
--
-- that users can override.
--
-- Important note: the most basic check that the system performs on every test
-- suite is to ensure that each of its record fields are initialised: please
-- ensure test suites are fully defined.
data TestSuite = 
  TestSuite
    {  
      _progs    :: [Id]              -- ^ Identifiers of programs in the input file to test: note all programs
                                     --   in the file will be considered if this list is empty.
    , _dataOpts :: DataOpts          -- ^ Test data options ('DataOpts').
    , _analOpts :: AnalOpts          -- ^ Statistical analysis options ('AnalOpts').
    , _critCfg  :: Criterion.Config  -- ^ Criterion's configuration ('Criterion.Types.Config').
    , _baseline :: Bool              -- ^ Whether the graphs of runtime results should include baseline measurements.
    , _nf       :: Bool              -- ^ Whether test cases should be evaluated to nf (@True@) or whnf (@False@).
    , _ghcFlags :: [String]          -- ^ GHC compiler flags used when compiling files compiling benchmarks.
    } deriving (Generic)

instance Default TestSuite where 
  def = TestSuite
          { 
            _progs    = []                         -- All programs in the test file will be considered for test purposes.           
          , _dataOpts = def                        -- See 'DataOpts'. 
          , _analOpts = def                        -- See 'AnalOpts'.        
          , _critCfg  = Criterion.defaultConfig    -- See 'Criterion.Main.Options.defaultConfig'
          , _baseline = False                      -- No baseline measurements.
          , _nf       = True                       -- Evaluate test cases to normal form.
          , _ghcFlags = []                         -- No optimisation, i.e., -O0. 
          }
  
instance NFData TestSuite 

-- ** Test data options

-- | @type UnaryTestData a = [(Int, IO a)]@.
--
-- Due to certain benchmarking requirements, test data must be specified in 
-- the IO monad. In addition, the system cannot determine the size of 
-- user-specified test data automatically. As such, for a test program 
-- @p :: a -> b@ , user-specified test data is of type @[(Int, IO a)]@, where 
-- the first element of each tuple is the size of the test input, and the second 
-- element is the input itself. 
--
-- Concrete example: test program @p :: [Int] -> [Int]@, user-specified test 
-- data @tDat@.
--
-- @ tDat :: UnaryTestData [Int]
-- tDat = 
--   [ ( 5
--     , return [1,2,3,4,5] 
--     )
--   , ( 10 
--     , return [1,2,3,4,5,6,7,8,9,10] 
--     )
--   ... ]@
-- 
-- Here the size of each @[Int]@ is determined by its number of elements 
-- (@5@ and @10@, respectively).
--
-- Note: test suites require a minimum number of /distinctly sized/ test 
-- inputs: see 'minInputs'.
-- 
-- __**Incorrectly sized test data will lead to erroneous performance results**__.
type UnaryTestData a = [(Int, IO a)]  

-- | @type BinaryTestData a b = [(Int, Int, IO a, IO b)]@
--
-- See 'UnaryTestData' for a discussion on user-specified test data and a
-- relevant example for unary test programs. This example generalises to
-- user-specified test data for binary test programs in the obvious way:
-- 
-- @tDat :: BinaryTestData [Char] [Int]
-- tDat = 
--   [ ( 5
--     , 4
--     , return [/'a/', /'b/', /'c/', /'d/', /'e/']
--     , return [0, 1, 2, 3] )
--   , ( 10 
--     , 9
--     , return [/'a/', /'b/', /'c/', /'d/', /'e/', /'f/', /'g/', /'h/', /'i/', /'j/'] )
--     , return [0, 1, 2, 3, 4, 5, 6, 7, 8]
--   ... ]@
--
-- 'TestSuite's require a minimum number of /distinctly sized/ test datums: see 
-- 'minInputs'. In the case of 'BinaryTestData', /pairs/ of sizes must be 
-- distinct. For example, @(5, 4)@ and @(10, 9)@ above are two distinct pairs of 
-- sizes.
--
-- __**Incorrectly sized test data will lead to invalid performance results**__.
type BinaryTestData a b = [(Int, Int, IO a, IO b)]

-- | Test data can either be specified by users or generated automatically by 
-- the system. Note: the default setting for 'DataOpts' is @Gen 5 5 100@.
--
-- If users choose to specify their own inputs, then the 'Manual' data option 
-- simply tells the system the name of the test data in the user input file.
-- For example: 
--
-- @ module UserInput where 
--
-- tProg :: [Int] -> [Int]
-- tProg  = ...
--
-- tDat :: UnaryTestData [Int]
-- tDat  = ...
--
-- ts :: TestSuite 
-- ts  = def { _progs = ["tProg"], _dataOpts = Manual "tDat" }
-- @
--
-- See 'UnaryTestData' and 'BinaryTestData' for details regarding the /types/ 
-- of user-specified test data. 
--
-- If test data should be generated by the system, users must specify the size 
-- of the data to be generated. This is achieved using @Gen l s u@, 
-- which specifies as a size /range/ by a lower bound @l@, an upper bound 
-- @u@, and a step @s@. This is converted to a Haskell range 
-- @[l, (l + s) .. u]@ and a test input is generated for each size in this
-- list. 
-- For example: @Gen 5 5 100@ corresponds to the range @[5, 10, 15 .. 100]@. 
--
-- 'TestSuite's require a minimum number of /distinctly sized/ inputs: see 
-- 'minInputs'.
--
-- __**Incorrectly sized test data will lead to erroneous performance results**__.
data DataOpts = 
    Manual Id           -- ^ The system should search for user-specified test data
                        --   with the given name in the user input file.
  | Gen Int Int Int     -- ^ The system should generate random test data in the given size range.
 -- | Discover          -- ^ <TO-DO>: The system should discover compatible user-specified 
                        -- data, or accept a suitable 'Gen' setting at a later time.
    deriving (Eq, Generic)

instance NFData DataOpts 

instance Show DataOpts where 
  show (Manual idt) = "Manual " ++ "\"" ++ idt ++ "\""
  show (Gen l s u)  = "Gen " ++ show l ++ " " ++ show s  ++ " " ++ show u

instance Default DataOpts where 
  def = Gen 5 5 100

-- | User options for statistical analysis.                                                                  -- ** NEEDS COMMENTS ** 
data AnalOpts = 
  AnalOpts
    { 
    -- Models to fit:
      _linearModels  :: [LinearType]                                     -- ^ Models for linear regression analysis.

    -- Cross-validation:
    , _cvIters       :: Int                                              -- ^ Number of cross-validation iterations.
    , _cvTrain       :: Double                                           -- ^ Percentage of data set to use for cross-validation 
                                                                         --   training; the rest is used for validation.
    -- Model comparison:
    , _topModels     :: Int                                              -- ^ The top @n@ models to review.
    , _statsFilt     :: Stats -> Bool                                    -- ^ Function to discard models that \"do not\" fit a given data set.
    , _statsSort     :: Stats -> Stats -> Ordering                       -- ^ Function rank models according to how they fit a given data set.
    -- Calculating efficiency results:
    , _improv        :: [(Double, Double)] -> Maybe (Ordering, Double)   -- ^ Function to calculate improvement results by comparing runtimes pointwise.
    -- Results generated by the system:
    , _graphFP       :: Maybe FilePath                                   -- ^ Graph of runtime results.
    , _reportFP      :: Maybe FilePath                                   -- ^ Report of results.
    , _coordsFP      :: Maybe FilePath                                   -- ^ CSV of (input size(s), runtime) coordinates.
    } deriving (Generic)

instance NFData AnalOpts 

instance Default AnalOpts where
  def = AnalOpts
          {
            _linearModels = fmap Poly [0..4] ++ [ Log 2 1, Log 2 2, PolyLog 2 1, Exp 2 ]
          , _cvIters      = 100
          , _cvTrain      = 0.7
          , _topModels    = 1
          , _statsFilt    = const True                                                                           --  <TO-DO>
          , _statsSort    = (\_ _ -> EQ)                                                                         --  <TO-DO>
          , _improv       = defaultImprov                                                              
          , _graphFP      = Just "./AutoBenched.png"  
          , _reportFP     = Nothing                   
          , _coordsFP     = Nothing
          }

-- | Default way to generate improvement results by comparing the runtimes                              -- ** NEEDS COMMENTING **
-- of two test programs pointwise.
defaultImprov :: [(Double, Double)] -> Maybe (Ordering, Double)
defaultImprov ds 
  | eqsPct >= 0.95 = Just (EQ, eqsPct)
  | ltsPct >= 0.95 = Just (LT, ltsPct)
  | gtsPct >= 0.95 = Just (GT, gtsPct)
  | otherwise      = Nothing

  where 
    eqs = filter (<= 0.15) $ fmap (uncurry relativeError) ds
    (lts, gts) = foldr f (0, 0) $ fmap (uncurry compare) ds
    
    eqsPct = genericLength eqs / genericLength ds
    ltsPct = (fromIntegral lts / genericLength ds) :: Double 
    gtsPct = (fromIntegral gts / genericLength ds) :: Double
    
    f :: Ordering -> (Int, Int) -> (Int, Int)
    f EQ (lt, gt) = (lt    , gt)
    f LT (lt, gt) = (lt + 1, gt)
    f GT (lt, gt) = (lt    , gt + 1)





-- * Benchmarking

-- * Statistical analysis

-- | The system approximates the time complexity of test programs by 
-- measuring their runtimes on test data of increasing size. Runtime 
-- measurements and input sizes are then given as (x, y)-coordinates
-- (x = size, y = runtime). Regression analysis (ridge regression) is used to 
-- fit various models (i.e., different types of functions: constant, linear, 
-- quadratic etc.) to the (x, y)-coordinates. Models are then compared to 
-- determine which has the best fit. The equation of the best fitting model is 
-- used as an approximation of time complexity. 
--
-- The 'LinearType' datatype describes which linear functions can be used as 
-- models. The system currently supports the following types of functions:
--
-- * Poly 0 (constant)     := a_0 
-- * Poly 1 (linear)       := a_0 + a_1 * x^2      
-- * Poly n                := a_0 + a_1 * x^1 + a_2 * x^2 + .. + a_n * x^n 
-- * Log  b n              := a_0 + a_1 * log_b^1(x) + a_2 * log_b^2(x) + .. + a_n * log_b^n(x)
-- * PolyLog b n           := a_0 + a_1 * x^1 * log_b^1(x) + a_2 * x^2 * log_b^2(x) + .. + a_n * x^n * log_b^n(x) 
-- * Exp n                 := a_0 + n^x
data LinearType = 
    Poly    Int        -- ^ Polynomial functions (Poly 0 = constant, Poly 1 = linear).
  | Log     Int Int    -- ^ Logarithmic functions.
  | PolyLog Int Int    -- ^ Polylogarithmic functions.     
  | Exp     Int        -- ^ Exponential function.
    deriving (Eq, Generic)

instance NFData LinearType

instance Show LinearType where 
  show (Poly      0) = "constant"
  show (Poly      1) = "linear"
  show (Poly      2) = "quadratic"
  show (Poly      3) = "cubic"
  show (Poly      4) = "quartic"
  show (Poly      5) = "quintic"
  show (Poly      6) = "sextic"
  show (Poly      7) = "septic"
  show (Poly      8) = "octic"
  show (Poly      9) = "nonic"
  show (Poly      n) = "n" ++ superNum n
  show (Log     b n) = "log" ++ subNum b ++ superNum n ++ "n"
  show (PolyLog b n) = "n" ++ superNum n ++ "log" ++ subNum b ++ superNum n ++ "n"
  show (Exp       n) = show n ++ "\x207F"

data Stats = Stats {} 