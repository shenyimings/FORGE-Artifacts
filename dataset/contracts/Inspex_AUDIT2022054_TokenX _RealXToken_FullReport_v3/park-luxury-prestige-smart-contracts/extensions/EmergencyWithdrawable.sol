// SPDX-License-Identifier: GPL-2.0-or-later
// TokenX Contracts v1.0.1 (extensions/EmergencyWithdrawable.sol)
pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev Contract module which allows children to implement an emergency withdraw
 * mechanism that can be called by an authorized account.
 *
 * This module is used through inheritance.
 */
abstract contract EmergencyWithdrawable {
    using SafeERC20 for IERC20;

    /**
     * @dev Emitted when emergeny withdraw ether has called.
     */
    event EmergencyWithdrawEther(address indexed beneficiary, uint256 amount);

    /**
     * @dev Emitted when emergeny withdraw token has called.
     */
    event EmergencyWithdrawToken(address indexed token, address indexed beneficiary, uint256 amount);

    /**
     * @dev Withdraw ether from (this) contract to `beneficiary`.
     */
    function _emergencyWithdrawEther(address payable beneficiary) internal virtual {
        uint256 balance = address(this).balance;
        require(balance > 0, "EmergencyWithdrawable: out of balance");

        (bool succeed,) = beneficiary.call{value: balance}("");
        require(succeed, "EmergencyWithdrawable: failed to withdraw Ether");

        emit EmergencyWithdrawEther(beneficiary, balance);
    }

    /**
     * @dev Withdraw token from (this) contract to `beneficiary`.
     */
    function _emergencyWithdrawToken(address beneficiary, address token) internal virtual {
        uint256 balance = IERC20(token).balanceOf(address(this));

        IERC20(token).safeTransfer(beneficiary, balance);

        emit EmergencyWithdrawToken(token, beneficiary, balance);
    }
}