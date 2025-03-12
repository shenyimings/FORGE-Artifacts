// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract FreeMoneyProvider is ContextUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function giveMeMoney(uint256 amount, IERC20Upgradeable token) public {
        token.safeTransfer(_msgSender(), amount);
    }
}
