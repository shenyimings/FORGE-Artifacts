// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "../../src/interfaces/ISmartVaultManager.sol";

contract MockSmartVaultBalance is ISmartVaultBalance {
    function test_mock() external pure {}

    function getUserSVTBalance(address smartVault, address user) external view returns (uint256) {
        return IERC20(smartVault).balanceOf(user);
    }

    function getSVTTotalSupply(address smartVault) external view returns (uint256) {
        return IERC20(smartVault).totalSupply();
    }
}
