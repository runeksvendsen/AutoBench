
{-# OPTIONS_GHC -Wall             #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE DeriveGeneric        #-}

-- |
--
-- Module      : AutoBench.Types
-- Description : Test input datatypes and instances ('Default'\/'NFData')
-- Copyright   : (c) 2018 Martin Handley
-- License     : BSD-style
-- Maintainer  : martin.handley@nottingham.ac.uk
-- Stability   : Experimental
-- Portability : GHC
--
-- This module defines test input datatypes:
--
-- * Test suites: 'TestSuite's;
-- * User-specified test data: 'UnaryTestData', 'BinaryTestData';
-- * Test data options: 'DataOpts';
-- * Statistical analysis options: 'AnalOpts'.
--
-- These are to be included in user input files to customise the functionality
-- of the system.
--
-- This module also defines datatypes used for statistical analysis:
--
-- * Regression models: 'LinearTypes';
-- * Fitting statistics: 'Stats'.
--
-- Users should be aware of these datatypes should they wish to provide
-- custom 'AnalOpts'. 
--

-------------------------------------------------------------------------------
-- <TO-DO>:
-------------------------------------------------------------------------------
-- + Move the default functions to AutoBench.Internal.Configuration? I'm 
--   reluctant because if they are left here then users can find all the info. 
--   they need in one place;
-- + Discover option for DataOpts;

module AutoBench.Types 
  (

  -- * User inputs
  -- ** Test suites
    TestSuite(..)                      -- Test suites are AutoBench's principle user input datatype.
  -- ** Test data options
  , UnaryTestData                      -- User-specified test data for unary test programs.
  , BinaryTestData                     -- User-specified test data for binary test programs.
  , DataOpts(..)                       -- Test data options.
  -- ** Statistical analysis options
  , AnalOpts(..)                       -- Statistical analysis options.
  -- * Statistical analysis
  , LinearType(..)                     -- Regression models used to approximate time complexity.
  , Stats(..)                          -- Fitting statistics used to compare regression models.

  ) where

import           Control.DeepSeq                  (NFData)
import qualified Criterion.Main                   as Criterion
import qualified Criterion.Types                  as Criterion
import           Data.Default                     (Default(..))
import           Data.List                        (genericLength)
import           GHC.Generics                     (Generic)
import           Numeric.MathFunctions.Comparison (relativeError)

import AutoBench.Internal.AbstractSyntax (Id)

-- Needed to 'rnf' 'TestSuite's.
instance NFData AnalOpts 
instance NFData Criterion.Config
instance NFData Criterion.Verbosity
instance NFData DataOpts 
instance NFData LinearType
instance NFData TestSuite

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
-- test conditions. Another advantage is that if one or more test suites in a 
-- user input file are erroneous, other, valid test suites in the same file can 
-- be executed nonetheless.
--
-- Test suites are constructed as follows:
--
-- * '_progs': the so-called \'progs\' list contains the names of the programs 
--   to be tested. Each program in the list must be defined in the same
--   file as the 'TestSuite'. All programs should have the same type, and that
--   type must be compatible with the remainder of the 'TestSuite's settings. 
--   For example, if @_nf = True@, then the result type of test programs must 
--   be a member of the 'NFData' type class. If @_dataOpts = Gen ...@, then 
--   the input type of test programs must be a member of the 'Arbitrary' type 
--   class. Users can specify an empty \'progs\' list, in which case all 
--   programs in the input file will be considered for testing: zero or more 
--   test suites will be generated with non-empty \'progs\' list satisfying the 
--   remainder of the 'TestSuite's settings. (The system effectively 'fills'
--   in the details on behalf of users.)
-- * '_dataOpts': the data options ('DataOpts') specify which test data to 
--   use. Users have two options: provide their own test data (@Manual "..."@) 
--   or have the system generate it (@Gen ...@). See 'DataOpts' for more 
--   information. Again, the types of the test programs must be compatible with 
--   this setting, for example, @Gen ...@ requires the input types of test 
--   programs be members of the 'Arbitrary' type class.
-- * '_analOpts': a large number of user options for statistical analysis. 
--   These options include: which types of functions to use as regression models 
--   when approximating the time complexity of each test program; functions to 
--   calculate improvement results, functions to filter and compare regression 
--   models based on fitting 'Stats' produced by the system. See 'AnalOpts' for 
--   more information.
-- * '_critCfg': Criterion's configuration. When benchmarks are executed by 
--   Criterion, this configuration is used. This allows users to configure
--   Criterion as if it was being used directly. Note: the default 
--   configuration works just fine and this option is mainly for users
--   who wish to generate Criterion reports as well AutoBench performance 
--   results.
-- * '_baseline': whether the system should produce baseline measurements.
--   These measure the time spent evaluating the /results/ of test programs
--   to normal form. This can be useful if the runtimes of test programs
--   look odd. For example, if the identity function is tested on lists of 
--   integers and test cases are evaluated to normal form, the system will 
--   approximate @id@ as linear. However, it clearly has constant time 
--   complexity. The linear factor comes from the time spent normalising each 
--   result list. This can be seen using baseline measurements. Note: the 
--   baseline setting can only be used in conjunction with the '_nf' setting.
-- * '_nf': whether test cases should be evaluated to normal form (@True@) or 
--   weak head normal form (@False@). Typically test cases should be evaluated
--   to normal form to ensure the full cost of applying each test program is 
--   reflected in runtime measurements.
-- * '_ghcFlags': any GHC compiler flags to use when compiling benchmarking 
--   files. One obvious use case is to compare the time performance of programs
--   subject to different levels of optimisation by specifying optimisation 
--   flags, e.g., -O0\/-O2\/O3.
--   Note: invalid flags are ignored but displayed to users as warnings.
--
-- All 'TestSuite' parameters are carefully validated. All errors are reported 
-- to users and invalid 'TestSuite's cannot be used by the system.
-- 
-- The system provides the following default 'TestSuite' (@def@):
--
-- @ TestSuite
--     { _progs    = []                                    -- All programs in the test file will be considered for test purposes.
--     , _dataOpts = def                                   -- See 'DataOpts'.
--     , _analOpts = def                                   -- See 'AnalOpts'.
--     , _critCfg  = Criterion.Main.Options.defaultConfig  -- See 'Criterion.Main.Options.defaultConfig'
--     , _baseline = False                                 -- No baseline measurements.
--     , _nf       = True                                  -- Evaluate test cases to normal form.
--     , _ghcFlags = []                                    -- No optimisation, i.e., -O0.
--     }
-- @
--
-- Important note: the most basic check that the system performs on every test
-- suite is to ensure that each of its record fields is initialised: please
-- ensure test suites are fully defined.
data TestSuite = 
  TestSuite
    { _progs    :: [Id]              -- ^ Names of programs in the input file to test. Note: all programs
                                     --   in the file will be considered if this list is empty.
    , _dataOpts :: DataOpts          -- ^ Test data options ('DataOpts').
    , _analOpts :: AnalOpts          -- ^ Statistical analysis options ('AnalOpts').
    , _critCfg  :: Criterion.Config  -- ^ Criterion's configuration ('Criterion.Types.Config').
    , _baseline :: Bool              -- ^ Whether baseline measurements should be taken.
    , _nf       :: Bool              -- ^ Whether test cases should be evaluated to nf (@True@) or whnf (@False@).
    , _ghcFlags :: [String]          -- ^ GHC compiler flags used when compiling benchmarking files.
    } deriving (Generic) 

instance Default TestSuite where
  def = TestSuite
          { _progs    = []                       -- All programs in the test file will be considered for test purposes.           
          , _dataOpts = def                      -- See 'DataOpts'. 
          , _analOpts = def                      -- See 'AnalOpts'.        
          , _critCfg  = Criterion.defaultConfig  -- See 'Criterion.Main.Options.defaultConfig'
          , _baseline = False                    -- No baseline measurements.
          , _nf       = True                     -- Evaluate test cases to normal form.
          , _ghcFlags = []                       -- No optimisation, i.e., -O0. 
          }

-- ** Test data options

-- | @type UnaryTestData a = [(Int, IO a)]@.
--
-- Due to certain benchmarking requirements, test data must be specified in 
-- the @IO@ monad. In addition, the system cannot determine the size of 
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
-- inputs: see 'minimumTestInputs'.
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
-- 'TestSuite's require a minimum number of distinctly sized test inputs: see 
-- 'minimumTestInputs'. In the case of 'BinaryTestData', /pairs/ of sizes must 
-- be distinct. For example, @(5, 4)@ and @(10, 9)@ above are two distinct 
-- pairs of sizes.
--
-- __**Incorrectly sized test data will lead to invalid performance results**__.
type BinaryTestData a b = [(Int, Int, IO a, IO b)]

-- | Test data can either be specified by users or generated automatically by 
-- the system. Note: the default setting for 'DataOpts' is @Gen 0 5 100@.
--
-- If users choose to specify their own inputs, then the 'Manual' data option 
-- simply tells the system the name of the test data in the user input file.
-- For example: 
--
-- @ 
-- module Input where 
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
-- See 'UnaryTestData' and 'BinaryTestData' for details regarding the types 
-- of user-specified test data. 
--
-- If test data should be generated by the system, users must specify the size 
-- of the data to be generated. This is achieved using @Gen l s u@, which 
-- specifies as a size range by a lower bound @l@, an upper bound @u@, and a 
-- step @s@. This is converted to a Haskell range @[l, (l + s) .. u]@ and a 
-- random test input is generated for each size in this list. 
-- For example: @Gen 0 5 100@ corresponds to the range @[0, 5, 10 .. 100]@. 
--
-- 'TestSuite's require a minimum number of /distinctly sized/ inputs: see 
-- 'minimumTestInputs'.
--
-- __**Incorrectly sized test data will lead to erroneous performance results**__.
data DataOpts = 
    Manual Id           -- ^ The system should search for user-specified test data
                        --   with the given name in the user input file.
  | Gen Int Int Int     -- ^ The system should generate random test data in the given size range.
 -- | Discover                                                                                      -- <TO-DO>: The system should discover compatible user-specified 
                                                                                                    -- data, or accept a suitable 'Gen' setting at a later time.
    deriving (Eq, Generic)

instance Default DataOpts where 
  def = Gen 0 5 100

-- ** Statistical analysis options   

-- | The system provides a number of user options for statistical analysis, 
-- including:
--
-- * '_linearModels': Which types of functions to use as regression models.
-- * '_cvIters': The number of iterations of cross-validation to perform.
-- * '_cvTrain': The percentage of test data to use as training data for 
--   cross-validation.
-- * '_topModels': The number of models to review when selecting the best 
--   fitting model from the results of regression analysis.
-- * '_statsFilt': A function to discard models that "do not" fit a given data 
--   set based on the fitting statistics produced by the system.
-- * '_statsSort': A function to rank models according to how they fit a given 
--   data set based on the fitting statistics ('Stats') produced by the system.
-- * '_improv': A function to calculate efficiency improvement results by 
--   comparing the runtimes of two test programs pointwise.
-- * '_graphFP': A PNG graph of runtime measurements with complexity estimates 
--   plotted as lines of best fit.
-- * '_reportFP': A TXT performance report.
-- * '_coordsFP': A CSV of (input size(s), runtime) coordinates for each test 
--   program.
--
-- The system provides the following default 'AnalOpts' (@def@):
--
-- @
-- AnalOpts
--   { _linearModels = 
--       [ Poly 0, Poly 1, Poly 2, Poly 3, Poly 4  
--       , Log 2 1, Log 2 2
--       , PolyLog 2 1
--       , Exp 2 
--       ]
--   , _cvIters   = 200
--   , _cvTrain   = 0.7
--   , _topModels = 3
--   , _statsFilt = defaultStatsFilt           -- See 'defaultStatsFilt'.                                                            
--   , _statsSort = defaultStatsSort           -- See 'defaultStatsSort'.                                 
--   , _improv    = defaultImprov              -- See 'defaultImprov'.                                                    
--   , _graphFP   = Just "./AutoBenched.png"   -- This is a .png.
--   , _reportFP  = Nothing                    -- This is a .txt.            
--   , _coordsFP  = Nothing                    -- This is a .csv.
--   }
-- @
--
-- Just as with test suites, these parameters are carefully validated. As such,
-- please ensure analysis options are fully defined. All errors will be reported 
-- to users.
data AnalOpts = 
  AnalOpts
    { _linearModels  :: [LinearType]                                     -- ^ Regression models.
    , _cvIters       :: Int                                              -- ^ Number of cross-validation iterations.
    , _cvTrain       :: Double                                           -- ^ Percentage of data set to use for cross-validation 
                                                                         --   training. The rest is used for validation.
    , _topModels     :: Int                                              -- ^ The top @n@ ranked models to review when selecting the best fitting model.
    , _statsFilt     :: Stats -> Bool                                    -- ^ Function to discard models that \"do not\" fit a given data set.
    , _statsSort     :: Stats -> Stats -> Ordering                       -- ^ Function to rank models according to how they fit a given data set.
    , _improv        :: [(Double, Double)] -> Maybe (Ordering, Double)   -- ^ Function to calculate improvement results by comparing the runtimes 
                                                                         --   of two test programs pointwise.
    , _graphFP       :: Maybe FilePath                                   -- ^ PNG graph of runtime results.
    , _reportFP      :: Maybe FilePath                                   -- ^ TXT report of results.
    , _coordsFP      :: Maybe FilePath                                   -- ^ CSV of (input size(s), runtime) coordinates.
    } deriving (Generic)

instance Default AnalOpts where
  def = AnalOpts
          { _linearModels = fmap Poly [0..4] ++ [Log 2 1, Log 2 2, PolyLog 2 1, Exp 2]
          , _cvIters      = 200
          , _cvTrain      = 0.7
          , _topModels    = 3
          , _statsFilt    = defaultStatsFilt                                                                   
          , _statsSort    = defaultStatsSort                                                                    
          , _improv       = defaultImprov                                                              
          , _graphFP      = Just "./AutoBenched.png"  
          , _reportFP     = Nothing                   
          , _coordsFP     = Nothing
          }

-- * Statistical analysis

-- | The system approximates the time complexity of test programs by 
-- measuring their runtimes on test data of increasing size. Input sizes 
-- and runtime measurements are then given as (x, y)-coordinates
-- (x = size, y = runtime). Regression analysis (ridge regression) is used to 
-- fit various models (i.e., different types of functions: constant, linear, 
-- quadratic etc.) to the (x, y)-coordinates. Models are then compared to 
-- determine which has the best fit. The equation of the best fitting model is 
-- used as an approximation of time complexity. 
--
-- The 'LinearType' datatype describes linear functions that are used as 
-- regression models. The system currently supports the following types of 
-- functions:
--
-- * Poly 0 (constant)   :=   a_0 
-- * Poly 1 (linear)     :=   a_0 + a_1 * x^2      
-- * Poly n              :=   a_0 + a_1 * x^1 + a_2 * x^2 + .. + a_n * x^n 
-- * Log  b n            :=   a_0 + a_1 * log_b^1(x) + a_2 * log_b^2(x) + .. + a_n * log_b^n(x)
-- * PolyLog b n         :=   a_0 + a_1 * x^1 * log_b^1(x) + a_2 * x^2 * log_b^2(x) + .. + a_n * x^n * log_b^n(x) 
-- * Exp n               :=   a_0 + n^x
data LinearType = 
    Poly    Int        -- ^ Polynomial functions (Poly 0 = constant, Poly 1 = linear).
  | Log     Int Int    -- ^ Logarithmic functions.
  | PolyLog Int Int    -- ^ Polylogarithmic functions.     
  | Exp     Int        -- ^ Exponential functions.
    deriving (Eq, Generic)

-- | The system provides a number of fitting statistics that can be used to 
-- compare models to decide which best fits a given data set. Users can provide 
-- their own functions in their 'AnalOpts' to filter and compare models 
-- according to these 'Stats': see '_statsFilt' and _statsSort'. The default 
-- sorting and comparison functions are 'defaultStatsFilt' and 
-- 'defaultStatsSort', respectively.
data Stats = 
  Stats 
   { _p_mse    :: Double   -- ^ Predicted mean squared error.
   , _p_mae    :: Double   -- ^ Predicated mean absolute error.
   , _ss_tot   :: Double   -- ^ Total sum of squares.
   , _p_ss_res :: Double   -- ^ Predicted residual sum of squares.
   , _r2       :: Double   -- ^ Coefficient of Determination.
   , _a_r2     :: Double   -- ^ Adjusted Coefficient of Determination.
   , _p_r2     :: Double   -- ^ Predicted Coefficient of Determination.
   , _bic      :: Double   -- ^ Bayesian Information Criterion.
   , _aic      :: Double   -- ^ Akaike’s Information Criterion.
   , _cp       :: Double   -- ^ Mallows' Cp Statistic.
   } deriving Eq

-- * Defaults

-- | The default method for discarding models that \"do not\" fit a given
-- data set. This is achieved by filtering according to a each model's 
-- corresponding fitting statistics ('Stats'). 
--
-- By default, no models are discarded.
--
-- > defaultStatsFilt = const True 
defaultStatsFilt :: Stats -> Bool                                                  
defaultStatsFilt  = const True 

-- | The default method for ranking models according to how they fit a given 
-- data set. This is achieved by comparing their predicted mean squared error 
-- fitting statistic ('_p_mse').
defaultStatsSort :: Stats -> Stats -> Ordering 
defaultStatsSort s1 s2 = compare (_p_mse s1) (_p_mse s2)

-- | The default way to generate improvement results by comparing the runtimes
-- of two test programs /pointwise/.
-- 
-- It works as follows:
--
-- * First, the relative error of each pair of runtimes is calculated,
--   if 95% or more pairs have relative error @<= 0.15@, then the system 
--   concludes the test programs are cost-equivalent (i.e., have approximately
--   the same time performance).
-- * If not, the system 'compare's each pair of runtimes (i.e., @\(d1, d2) -> 
--   d1 `compare` d2@). If 95% of pairs are @LT@ or 95% of pairs are @GT@, then 
--   that ordering is chosen. 
-- * If not, no improvement result is generated.
defaultImprov :: [(Double, Double)] -> Maybe (Ordering, Double)
defaultImprov ds 
  | eqsPct >= 0.95 = Just (EQ, eqsPct) -- 95% or more test cases have relative error @<= 0.15@?
  | ltsPct >= 0.95 = Just (LT, ltsPct) -- 95% or more test cases 'LT'?
  | gtsPct >= 0.95 = Just (GT, gtsPct) -- 95% or more test cases 'GT'?
  | otherwise      = Nothing           -- No improvement result.

  where 
    -- Calculate total for EQ.
    eqs = filter (<= 0.15) $ fmap (uncurry relativeError) ds
    -- For each pair of runtime measurements (d1, d2), calculate d1 `compare` d2.
    -- Then calculate total for LT and GT.
    (lts, gts) = foldr f (0, 0) $ fmap (uncurry compare) ds
  
    -- Totalling function for LT and GT.
    f :: Ordering -> (Int, Int) -> (Int, Int)
    f EQ tot = tot
    f LT (lt, gt) = (lt + 1, gt)
    f GT (lt, gt) = (lt    , gt + 1)

    -- Percentages for EQ, LT, GT.
    eqsPct = (genericLength eqs / genericLength ds) :: Double
    ltsPct = (fromIntegral lts  / genericLength ds) :: Double 
    gtsPct = (fromIntegral gts  / genericLength ds) :: Double