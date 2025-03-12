// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../Dependencies/ERDMath.sol";
import "../Interfaces/IEUSDToken.sol";
import "../Interfaces/IStabilityPool.sol";
import "../Interfaces/IPriceFeed.sol";
import "./BorrowerOperationsScript.sol";
import "./ETHTransferScript.sol";

contract BorrowerWrappersScript is BorrowerOperationsScript, ETHTransferScript {
    using SafeMathUpgradeable for uint256;

    bytes32 public constant NAME = "BorrowerWrappersScript";

    ITroveManager immutable troveManager;
    ICollateralManager immutable collateralManager;
    IStabilityPool immutable stabilityPool;
    IPriceFeed immutable priceFeed;
    IERC20Upgradeable immutable eusdToken;

    constructor(
        address _borrowerOperationsAddress,
        address _troveManagerAddress,
        address _eusdTokenAddress,
        address _collateralManagerAddress
    )
        BorrowerOperationsScript(
            IBorrowerOperations(_borrowerOperationsAddress)
        )
    {
        ITroveManager troveManagerCached = ITroveManager(_troveManagerAddress);
        troveManager = troveManagerCached;

        ICollateralManager collateralManagerCached = ICollateralManager(_collateralManagerAddress);
        collateralManager = collateralManagerCached;

        IStabilityPool stabilityPoolCached = troveManagerCached.stabilityPool();
        stabilityPool = stabilityPoolCached;

        IPriceFeed priceFeedCached = troveManagerCached.priceFeed();
        priceFeed = priceFeedCached;

        IEUSDToken eusdTokenCached = IEUSDToken(_eusdTokenAddress);
        eusdToken = IERC20Upgradeable(eusdTokenCached);
    }

    struct LocalVariables_troveParams {
        uint maxFee;
        uint EUSDAmount;
        address upperHint;
        address lowerHint;
        address[] colls;
        uint[] balancesBefore;
        uint[] balancesAfter;
        uint[] amountsIn;
    }

    function claimCollateralAndOpenTrove(uint _maxFee, uint _EUSDAmount, address _upperHint, address _lowerHint) external payable {
        LocalVariables_troveParams memory vars;
        vars.maxFee = _maxFee;
        vars.EUSDAmount = _EUSDAmount;
        vars.lowerHint = _lowerHint;
        vars.upperHint = _upperHint;
        address[] memory collaterals = troveManager.getCollateralSupport();
        uint collLen = collaterals.length;
        vars.colls = new address[](collLen - 1);
        vars.balancesBefore = new uint[](collLen - 1);
        vars.balancesAfter = new uint[](collLen - 1);
        for (uint i = 1; i < collLen; i++) {
            vars.colls[i - 1] = collaterals[i];
            vars.balancesBefore[i - 1] = IERC20Upgradeable(collaterals[i]).balanceOf(address(this));
        }
        uint balanceBefore = address(this).balance;

        // Claim collateral
        borrowerOperations.claimCollateral();

        for (uint i = 1; i < collLen; i++) {
            vars.balancesAfter[i - 1] = IERC20Upgradeable(collaterals[i]).balanceOf(address(this));
        }
        uint balanceAfter = address(this).balance;

        vars.amountsIn = ERDMath._subArray(vars.balancesAfter, vars.balancesBefore);

        // already checked in CollSurplusPool
        // assert(balanceAfter > balanceBefore);

        uint totalCollateral = balanceAfter.sub(balanceBefore).add(msg.value);

        // Open trove with obtained collateral, plus collateral sent by user
        borrowerOperations.openTrove{ value: totalCollateral }(vars.colls, vars.amountsIn, vars.maxFee, vars.EUSDAmount, vars.upperHint, vars.lowerHint);
    }

    function claimSPRewardsAndRecycle(uint _maxFee, address _upperHint, address _lowerHint) external {
        LocalVariables_troveParams memory vars;
        vars.maxFee = _maxFee;
        vars.lowerHint = _lowerHint;
        vars.upperHint = _upperHint;
        address[] memory collaterals = troveManager.getCollateralSupport();
        uint collLen = collaterals.length;
        vars.colls = new address[](collLen - 1);
        vars.balancesBefore = new uint[](collLen - 1);
        vars.balancesAfter = new uint[](collLen - 1);
        for (uint i = 1; i < collLen; i++) {
            vars.colls[i - 1] = collaterals[i];
            vars.balancesBefore[i - 1] = IERC20Upgradeable(collaterals[i]).balanceOf(address(this));
        }
        uint collBalanceBefore = address(this).balance;

        // Claim rewards
        stabilityPool.withdrawFromSP(0);

        for (uint i = 1; i < collLen; i++) {
            vars.balancesAfter[i - 1] = IERC20Upgradeable(collaterals[i]).balanceOf(address(this));
        }
        uint collBalanceAfter = address(this).balance;
        uint claimedCollateral = collBalanceAfter.sub(collBalanceBefore);

        vars.amountsIn = ERDMath._subArray(vars.balancesAfter, vars.balancesBefore);

        // Add claimed ETH to trove, get more EUSD and stake it into the Stability Pool
        if (claimedCollateral != 0 || ERDMath._arrayIsNonzero(vars.amountsIn)) {
            _requireUserHasTrove(address(this));

            uint EUSDAmount = _getNetEUSDAmount(claimedCollateral, vars.colls, vars.amountsIn);
            borrowerOperations.addColl{ value: claimedCollateral }(vars.colls, vars.amountsIn, vars.upperHint, vars.lowerHint);
            // Provide withdrawn EUSD to Stability Pool
            if (EUSDAmount != 0) {
                borrowerOperations.withdrawEUSD(vars.EUSDAmount, vars.upperHint, vars.lowerHint, vars.maxFee);
                stabilityPool.provideToSP(EUSDAmount, address(0));
            }
        }
    }

    function _getNetEUSDAmount(uint _ETH, address[] memory _colls, uint[] memory _amounts) internal returns (uint) {
        uint price = priceFeed.fetchPrice();
        uint ICR = troveManager.getCurrentICR(address(this), price);
        (uint value, ) = collateralManager.getValue(_colls, _amounts, price);
        uint collateralValue = value.add(_ETH.mul(price));

        uint EUSDAmount = collateralValue.div(ICR);
        uint borrowingRate = troveManager.getBorrowingRateWithDecay();
        uint netDebt = EUSDAmount.mul(ERDMath.DECIMAL_PRECISION).div(ERDMath.DECIMAL_PRECISION.add(borrowingRate));

        return netDebt;
    }

    function _requireUserHasTrove(address _depositor) internal view {
        require(
            troveManager.getTroveStatus(_depositor) == 1,
            "BorrowerWrappersScript: caller must have an active trove"
        );
    }
}
