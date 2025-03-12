// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import './BaseStrategy.sol';

contract VoidStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    constructor(address initVault, address initAccessManager) public BaseStrategy(initVault, initAccessManager) {
        _giveAllowances();
    }

    /* ----- External Functions ----- */

    function withdraw(uint256 amount) external override nonReentrant {
        require(msg.sender == vault, 'VoidStrategy: NOT_VAULT');

        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        uint256 withdrawAmount = amount < wantBalance ? amount : wantBalance;

        uint256 fee = chargeWithdrawalFee(withdrawAmount);
        if (withdrawAmount > fee) {
            TransferHelper.safeTransfer(want, vault, withdrawAmount.sub(fee));
        }
    }

    function harvest() public override whenNotPaused {
        require(msg.sender == tx.origin || msg.sender == vault, 'VoidStrategy: EOA_OR_VAULT');
        deposit();
    }

    function deposit() public override whenNotPaused nonReentrant {}

    function balanceOfPool() public view override returns (uint256) {
        return 0;
    }

    /* ----- Private Functions ----- */

    function _giveAllowances() internal override {}

    function _removeAllowances() internal override {}

    function retireStrat() external override {
        require(msg.sender == vault, '!vault');
        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance > 0) {
            TransferHelper.safeTransfer(want, vault, wantBalance);
        }
    }

    function emergencyExit() external override onlyAdmin {
        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance > 0) {
            TransferHelper.safeTransfer(want, vault, wantBalance);
        }
    }
}
