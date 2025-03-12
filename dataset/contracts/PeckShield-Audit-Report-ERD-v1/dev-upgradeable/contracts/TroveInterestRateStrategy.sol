// SPDX-License-Identifier: MITs
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./Interfaces/ITroveManager.sol";
import "./Interfaces/ICollateralManager.sol";
import "./Interfaces/ITroveDebt.sol";
import "./Interfaces/IActivePool.sol";
import "./Interfaces/IDefaultPool.sol";
import "./Interfaces/IStabilityPool.sol";
import "./Interfaces/ITroveInterestRateStrategy.sol";
import "./Interfaces/IPriceFeed.sol";
import "./Dependencies/WadRayMath.sol";
import "./DataTypes.sol";

contract TroveInterestRateStrategy is OwnableUpgradeable, ITroveInterestRateStrategy {
    using SafeMathUpgradeable for uint256;
    using WadRayMath for uint256;

    /**
     * @dev this represents the optimal collateral ratio
     * Expressed in ray
     **/
    uint256 public OCR;

    // Base borrow rate when TCR <= CCR. Expressed in ray
    uint256 internal baseBorrowRate;

    // Slope of the interest curve when TCR > CCR and <= OCR.rayToWad(). Expressed in ray
    uint256 internal rateSlope1;

    // Slope of the interest curve when TCR > OCR.rayToWad(). Expressed in ray
    uint256 internal rateSlope2;

    ITroveManager public troveManager;

    ICollateralManager public collateralManager;

    ITroveDebt public troveDebt;

    IActivePool public activePool;

    IDefaultPool public defaultPool;

    IStabilityPool public stabilityPool;

    IPriceFeed public priceFeed;

    function initialize(
        uint256 _OCR,
        uint256 _baseBorrowRate,
        uint256 _rateSlope1,
        uint256 _rateSlope2
    ) public initializer {
        __Ownable_init();
        OCR = _OCR;
        baseBorrowRate = _baseBorrowRate;
        rateSlope1 = _rateSlope1;
        rateSlope2 = _rateSlope2;
    }

    function setAddresses(
        address _troveManagerAddress,
        address _collateralManagerAddress,
        address _troveDebtAddress,
        address _activePoolAddress,
        address _defaultPoolAddress,
        address _stabilityPoolAddress,
        address _priceFeedAddress
    ) external onlyOwner {
        troveManager = ITroveManager(_troveManagerAddress);
        collateralManager = ICollateralManager(_collateralManagerAddress);
        troveDebt = ITroveDebt(_troveDebtAddress);
        activePool = IActivePool(_activePoolAddress);
        defaultPool = IDefaultPool(_defaultPoolAddress);
        stabilityPool = IStabilityPool(_stabilityPoolAddress);
        priceFeed = IPriceFeed(_priceFeedAddress);
    }

    function getRateSlope1() external view returns (uint256) {
        return rateSlope1;
    }

    function getRateSlope2() external view returns (uint256) {
        return rateSlope2;
    }

    function getBaseBorrowRate() external view override returns (uint256) {
        return baseBorrowRate;
    }

    function getMaxBorrowRate() external view override returns (uint256) {
        return baseBorrowRate.add(rateSlope1).add(rateSlope2);
    }

    function setRateSlope1(uint256 _slope1) external onlyOwner {
        rateSlope1 = _slope1;
    }

    function setRateSlope2(uint256 _slope2) external onlyOwner {
        rateSlope2 = _slope2;
    }

    function setBaseBorrowRate(uint256 _baseRate) external onlyOwner {
        baseBorrowRate = _baseRate;
    }

    struct CalcInterestRatesLocalVars {
        uint256 totalDebt;
        uint256 currentBorrowRate;
        uint256 currentLiquidityRate;
        uint256 utilizationRate;
        uint256 TCR;
    }

    /**
     * @dev Calculates the interest rates depending on the trove's state and configurations.
     * @return The liquidity rate, and the variable borrow rate
     **/
    function calculateInterestRates() public view override returns (uint256, uint256) {
        DataTypes.TroveData memory troveData = troveManager.getTroveData();

        uint256 tcr = troveManager.getTCR(priceFeed.fetchPrice_view());
        uint256 ccr = collateralManager.getCCR();
        CalcInterestRatesLocalVars memory vars;

        //calculates the total debt locally using the scaled borrow amount instead
        //of borrow amount(), as it's noticeably cheaper. Also, the index has been
        //updated by the previous TroveLogic.updateState() call
        vars.totalDebt = troveDebt.scaledTotalSupply().rayMul(troveData.borrowIndex);
        vars.currentBorrowRate = 0;
        vars.currentLiquidityRate = 0;

        vars.utilizationRate = vars.totalDebt == 0
            ? 0
            : ccr.wadDiv(tcr).wadToRay();
            
        uint256 optimalUtilizationRate = ccr.wadToRay().rayDiv(OCR);
        if (vars.utilizationRate >= WadRayMath.ray()) {
            vars.currentBorrowRate = baseBorrowRate;
        } else {
            if (vars.utilizationRate >= optimalUtilizationRate) {
                // vars.currentBorrowRate = baseBorrowRate.add(
                //     rateSlope1.rayMul((tcr - OCR).wadDiv(OCR - ccr).wadToRay())
                // );
                vars.currentBorrowRate = baseBorrowRate.add(
                    rateSlope1.rayMul((tcr.sub(ccr).wadToRay()).rayDiv(OCR.sub(ccr.wadToRay())))
                );
            } else {
                // uint256 remaindUtilizationRateRatio = tcr.wadToRay().rayDiv(
                //     OCR
                // ) - WadRayMath.ray();
                uint256 remaindUtilizationRateRatio = tcr.wadToRay().rayDiv(
                    OCR
                ) - WadRayMath.ray();

                vars.currentBorrowRate = baseBorrowRate.add(rateSlope1).add(
                    rateSlope2.rayMul(remaindUtilizationRateRatio)
                );
                
            }
        }
        
        uint256 coefficient = vars.utilizationRate >= WadRayMath.ray()
            ? WadRayMath.ray()
            : vars.utilizationRate;
        vars.currentLiquidityRate = _getOverallBorrowRate(
            vars.totalDebt,
            vars.currentBorrowRate
        ).rayMul(coefficient);

        return (vars.currentLiquidityRate, vars.currentBorrowRate);
    }

    /**
     * @dev Calculates the overall borrow rate as the weighted average between the total variable debt and total stable debt
     * @param totalDebt The total borrowed from the trove at a rate
     * @param currentBorrowRate The current borrow rate of the trove
     * @return The weighted averaged borrow rate
     **/
    function _getOverallBorrowRate(uint256 totalDebt, uint256 currentBorrowRate)
        internal
        pure
        returns (uint256)
    {
        if (totalDebt == 0) return 0;

        uint256 weightedRate = totalDebt.wadToRay().rayMul(currentBorrowRate);

        uint256 overallBorrowRate = weightedRate.rayDiv(totalDebt.wadToRay());

        return overallBorrowRate;
    }
}
