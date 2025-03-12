// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "../../JetStakingTesting.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract JetStakingV1ChangeFunctionSignature is JetStakingTesting {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function batchStakeOnBehalfOfOtherUsers(
        address[] memory accounts,
        uint256[] memory amounts,
        uint256 batchAmount,
        bool checkLength
    ) external onlyRole(AIRDROP_ROLE) {
        _before();
        require(accounts.length == amounts.length, "INVALID_ARRAY_LENGTH");
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
            _stake(accounts[i], amounts[i]);
        }
        require(totalAmount == batchAmount, "INVALID_BATCH_AMOUNT");
        IERC20Upgradeable(auroraToken).safeTransferFrom(
            msg.sender,
            address(treasury),
            batchAmount
        );
    }
}
