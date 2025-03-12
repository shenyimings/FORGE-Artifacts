// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '../interfaces/IOpenSkyMoneyMarket.sol';
import '../misc/ape-staking/IApeCoinStaking.sol';
import '../libraries/helpers/Errors.sol';
import '../libraries/math/WadRayMath.sol';
import 'hardhat/console.sol';

contract ApeCoinStakingMoneyMarket is IOpenSkyMoneyMarket {
    using SafeERC20 for IERC20;
    using WadRayMath for uint256;

    address private immutable original;

    IApeCoinStaking public immutable apeCoinStaking;

    constructor(IApeCoinStaking apeCoinStaking_) {
        apeCoinStaking = apeCoinStaking_;
        original = address(this);
    }

    function _requireDelegateCall() private view {
        require(address(this) != original, Errors.MONEY_MARKET_REQUIRE_DELEGATE_CALL);
    }

    modifier requireDelegateCall() {
        _requireDelegateCall();
        _;
    }

    function depositCall(address asset, uint256 amount) external override requireDelegateCall {
        require(amount > 0, Errors.MONEY_MARKET_DEPOSIT_AMOUNT_NOT_ALLOWED);

        IApeCoinStaking.DashboardStake memory dashboardStake = apeCoinStaking.getApeCoinStake(address(this));
        if (dashboardStake.deposited > 0) {
            apeCoinStaking.withdrawApeCoin(dashboardStake.deposited, address(this));
        }

        uint256 depositAmount = IERC20(asset).balanceOf(address(this));
        _approveToken(asset, depositAmount);
        apeCoinStaking.depositApeCoin(depositAmount, address(this));
    }

    function _approveToken(address asset, uint256 amount) internal virtual {
        require(IERC20(asset).approve(address(apeCoinStaking), amount), Errors.MONEY_MARKET_APPROVAL_FAILED);
    }

    function withdrawCall(address asset, uint256 amount, address to) external override requireDelegateCall {
        require(amount > 0, Errors.MONEY_MARKET_WITHDRAW_AMOUNT_NOT_ALLOWED);

        IApeCoinStaking.DashboardStake memory dashboardStake = apeCoinStaking.getApeCoinStake(address(this));
        apeCoinStaking.withdrawApeCoin(dashboardStake.deposited, address(this));

        uint256 balance = IERC20(asset).balanceOf(address(this));
        if (balance > amount) {
            uint256 depositAmount = balance - amount;
            _approveToken(asset, depositAmount);
            apeCoinStaking.depositApeCoin(depositAmount, address(this));
        }

        IERC20(asset).safeTransfer(to, amount);
    }

    function getMoneyMarketToken(address asset) public view virtual override returns (address) {
        return address(0);
    }

    function getBalance(address asset, address account) external view override returns (uint256) {
        IApeCoinStaking.DashboardStake memory dashboardStake = apeCoinStaking.getApeCoinStake(account);
        return dashboardStake.deposited + dashboardStake.unclaimed;
    }

    function getSupplyRate(address asset) external view override returns (uint256) {
        (IApeCoinStaking.PoolUI memory apeCoinPoolUI, , , ) = apeCoinStaking.getPoolsUI();
        return (apeCoinPoolUI.currentTimeRange.rewardsPerHour * 24 * 365).rayDiv(apeCoinPoolUI.stakedAmount);
    }

    receive() external payable {
        revert('RECEIVE_NOT_ALLOWED');
    }

    fallback() external payable {
        revert('FALLBACK_NOT_ALLOWED');
    }
}
