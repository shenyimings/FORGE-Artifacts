// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

library UniERC20Upgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable private constant _ETH_ADDRESS = IERC20Upgradeable(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    IERC20Upgradeable private constant _MATIC_ADDRESS = IERC20Upgradeable(0x0000000000000000000000000000000000001010);
    IERC20Upgradeable private constant _ZERO_ADDRESS = IERC20Upgradeable(address(0));

    function isETH(IERC20Upgradeable token) internal pure returns (bool) {
        return (token == _ZERO_ADDRESS || token == _ETH_ADDRESS || token == _MATIC_ADDRESS);
    }

    function uniBalanceOf(IERC20Upgradeable token, address account) internal view returns (uint256) {
        if (isETH(token)) {
            return account.balance;
        } else {
            return token.balanceOf(account);
        }
    }

    function uniTransfer(IERC20Upgradeable token, address payable to, uint256 amount) internal {
        if (amount > 0) {
            if (isETH(token)) {
                to.transfer(amount);
            } else {
                token.safeTransfer(to, amount);
            }
        }
    }

    function uniApprove(IERC20Upgradeable token, address to, uint256 amount) internal {
        require(!isETH(token), "ce09");

        if (amount == 0) {
            token.safeApprove(to, 0);
        } else {
            uint256 allowance = token.allowance(address(this), to);
            if (allowance < amount) {
                token.safeIncreaseAllowance(to, amount - allowance);
            }
        }
    }
}
