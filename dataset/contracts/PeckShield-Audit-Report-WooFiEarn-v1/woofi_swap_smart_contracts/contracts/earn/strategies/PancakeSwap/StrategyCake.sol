// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '../../../interfaces/PancakeSwap/IMasterChef.sol';
import '../BaseStrategy.sol';

contract StrategyCake is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /* ----- Constant Variables ----- */

    address public constant masterChef = address(0x73feaa1eE314F8c655E354234017bE2193C9E24E);

    constructor(address initVault, address initAccessManager) public BaseStrategy(initVault, initAccessManager) {
        _giveAllowances();
    }

    /* ----- External Functions ----- */

    function withdraw(uint256 amount) external override nonReentrant {
        require(msg.sender == address(vault), 'StrategyCake: NOT_VAULT');

        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance < amount) {
            IMasterChef(masterChef).leaveStaking(amount.sub(wantBalance));
            wantBalance = IERC20(want).balanceOf(address(this));
        }

        // just in case the decimal precision for the very left staking amount
        uint256 withdrawAmount = amount < wantBalance ? amount : wantBalance;

        uint256 fee = chargeWithdrawalFee(withdrawAmount);
        if (withdrawAmount > fee) {
            TransferHelper.safeTransfer(want, vault, withdrawAmount.sub(fee));
        }
    }

    function harvest() public override whenNotPaused {
        require(msg.sender == tx.origin || msg.sender == address(vault), 'StrategyCake: EOA_or_vault');

        uint256 balanceBefore = IERC20(want).balanceOf(address(this));
        IMasterChef(masterChef).leaveStaking(0);
        uint256 balanceAfter = IERC20(want).balanceOf(address(this));

        uint256 perfAmount = balanceAfter.sub(balanceBefore);
        chargePerformanceFee(perfAmount);
        deposit();
    }

    function deposit() public override whenNotPaused nonReentrant {
        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance > 0) {
            IMasterChef(masterChef).enterStaking(wantBalance);
        }
    }

    function balanceOfPool() public view override returns (uint256) {
        (uint256 amount, ) = IMasterChef(masterChef).userInfo(0, address(this));
        return amount;
    }

    function _giveAllowances() internal override {
        TransferHelper.safeApprove(want, masterChef, 0);
        TransferHelper.safeApprove(want, masterChef, uint256(-1));
    }

    function _removeAllowances() internal override {
        TransferHelper.safeApprove(want, masterChef, 0);
    }

    /* ----- Admin Functions ----- */

    function retireStrat() external override {
        require(msg.sender == vault, '!vault');
        IMasterChef(masterChef).emergencyWithdraw(0);
        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance > 0) {
            TransferHelper.safeTransfer(want, vault, wantBalance);
        }
    }

    function emergencyExit() external override onlyAdmin {
        IMasterChef(masterChef).emergencyWithdraw(0);
        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance > 0) {
            TransferHelper.safeTransfer(want, vault, wantBalance);
        }
    }
}
