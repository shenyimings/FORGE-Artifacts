// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "../../JetStakingTesting.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract JetStakingV1ExtraFunctionality is JetStakingTesting {
    function dummy() public view returns (uint256) {
        return 1;
    }
}
