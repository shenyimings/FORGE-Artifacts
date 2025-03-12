// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IStabilityPool} from "../interfaces/liquity/IStabilityPool.sol";
import {IPriceFeed} from "../interfaces/chainlink/IPriceFeed.sol";
import {sc4626} from "../sc4626.sol";

contract scLiquity is sc4626 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    error StrategyETHSwapFailed();
    error StrategyLQTYSwapFailed();

    event DepositedIntoStrategy(uint256 amount);

    uint256 public totalInvested;
    uint256 public totalProfit;

    IStabilityPool public stabilityPool = IStabilityPool(0x66017D22b0f8556afDd19FC67041899Eb65a21bb);
    IPriceFeed public lusd2eth = IPriceFeed(0x60c0b047133f696334a2b7f68af0b49d2F3D4F72);
    ERC20 public lqty = ERC20(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D);

    // 0x swap router
    address xrouter = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    constructor(address _admin, address _keeper, ERC20 _lusd)
        sc4626(_admin, _keeper, _lusd, "Sandclock LUSD Vault", "scLUSD")
    {
        asset.safeApprove(address(stabilityPool), type(uint256).max);
    }

    // need to be able to receive eth rewards
    receive() external payable {
        require(msg.sender == address(stabilityPool));
    }

    function totalAssets() public view override returns (uint256 assets) {
        uint256 ethBalance = address(this).balance + stabilityPool.getDepositorETHGain(address(this));

        // add eth balance in lusd terms using chainlink oracle
        assets = ethBalance.mulWadDown(uint256(lusd2eth.latestAnswer()));

        // add float
        assets += asset.balanceOf(address(this));

        // add invested amount
        assets += stabilityPool.getCompoundedLUSDDeposit(address(this));
    }

    function afterDeposit(uint256, uint256) internal override {
        // float is not allowed to be greater than 25% of the total
        // invested since liquidation rewards can be dilluted by savy
        // just-in-time depositors
        uint256 float = asset.balanceOf(address(this));
        if (float > (totalInvested / 4)) {
            _depositIntoStrategy();
        }
    }

    function beforeWithdraw(uint256 assets, uint256) internal override {
        uint256 float = asset.balanceOf(address(this));

        if (assets <= float) return;

        uint256 missing = (totalAssets() - assets).mulWadDown(floatPercentage);
        uint256 withdrawAmount = assets - float + missing;

        // needed otherwise counted as loss during harvest
        totalInvested -= withdrawAmount;

        stabilityPool.withdrawFromSP(withdrawAmount);
    }

    // @dev: access control not needed, this is only separate to save
    // gas for users depositing, ultimately controlled by float %
    function depositIntoStrategy() external {
        _depositIntoStrategy();
    }

    function _depositIntoStrategy() internal {
        uint256 float = asset.balanceOf(address(this));
        uint256 targetFloat = totalAssets().mulWadDown(floatPercentage);

        if (float <= targetFloat) return; // nothing to invest

        uint256 depositAmount = float - targetFloat;

        // needed otherwise counted as profit during harvest
        totalInvested += depositAmount;

        stabilityPool.provideToSP(depositAmount, address(0));

        emit DepositedIntoStrategy(depositAmount);
    }

    function harvest(uint256 _lqtyAmount, bytes calldata _lqtySwapData, uint256 _ethAmount, bytes calldata _ethSwapData)
        external
    {
        _onlyKeeper();

        // store the old total
        uint256 oldTotalInvested = totalInvested;

        // harvest any unclaimed rewards
        stabilityPool.withdrawFromSP(0);

        // swap LQTY -> LUSD
        if (_lqtyAmount > 0) {
            lqty.safeApprove(xrouter, _lqtyAmount);
            (bool success,) = xrouter.call{value: 0}(_lqtySwapData);
            if (!success) revert StrategyLQTYSwapFailed();
        }

        // swap ETH -> LUSD
        if (_ethAmount > 0) {
            (bool success,) = xrouter.call{value: _ethAmount}(_ethSwapData);
            if (!success) revert StrategyETHSwapFailed();
        }

        // reinvest
        _depositIntoStrategy();

        totalInvested = stabilityPool.getCompoundedLUSDDeposit(address(this));

        // profit since last harvest, zero if there was a loss
        uint256 profit = totalInvested > oldTotalInvested ? totalInvested - oldTotalInvested : 0;

        if (profit > 0) {
            totalProfit += profit;

            uint256 fee = profit.mulWadDown(performanceFee);

            // mint equivalent amount of tokens to the performance fee beneficiary ie the treasury
            _mint(treasury, convertToShares(fee));
        }
    }
}
