//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {OwnableStorage} from "@solidstate/contracts/access/ownable/OwnableStorage.sol";
import {LibClaimManager} from "./LibClaimManager.sol";

/**
 * @title LibReward
 * @notice This library allows to manage rewards for greenproof workers.
 * @author EnergyWeb Foundation
 */
library LibReward {
    /**
     * @notice RewardStorage - A structured storage for greenproof's rewards
     *
     * @custom:field rewardsEnabled - A boolean indicating if rewarding feature is enabled or disabled
     * @custom:field rewardAmount - An unsigned 256-bit integer representing the amount of reward for each payment
     * @custom:field rewardQueue - An array of payable addresses, representing the workers waiting for rewards
     */
    struct RewardStorage {
        bool rewardsEnabled;
        uint256 rewardAmount;
        address payable[] rewardQueue;
    }

    bytes32 private constant _REWARD_STORAGE_POSITION = keccak256("ewc.greenproof.rewardVoting.diamond.storage");

    /**
     * @notice Error message thrown when trying to pay rewards while rewards are disabled
     */
    error RewardsDisabled();

    /**
     * @notice Error message thrown when no funds are provided in the transaction
     * @dev This error is thrown when no funds are passed into the `msg.value` field while calling a payable function
     */
    error NoFundsProvided();

    /**
     * @notice Error message when the reward toggle state is the same as previous
     * @custom:param state : The new state of the reward toggle
     * @dev This error is thrown when the rewarding toggle state is in the same state as previous
     *
     */
    error RewardStateNotChanged(bool state);

    modifier onlyOwner() {
        LibClaimManager.checkOwnership();
        _;
    }

    /**
     * @notice initRewards - Sets the initial rewarding configuration into the rewardsStorage
     * @dev This function initializes the rewards with a given amount and enables/disables the rewarding feature
     * @param rewardAmount - The amount of reward for each payment
     * @param rewardsEnabled - The status of rewarding feature. If set to true, winning workers can receive rewards. Otherwise, no rewards are paid
     */
    function initRewards(uint256 rewardAmount, bool rewardsEnabled) internal {
        RewardStorage storage rs = getStorage();

        rs.rewardAmount = rewardAmount;
        rs.rewardsEnabled = rewardsEnabled;
    }

    /**
     * @notice setRewardsFeature - Enables/disables the rewards feature.
     * @dev Only the contract owner can call this function
     * @dev The transaction will revert if the function is called while the rewarding is already in the desired state intor the `rewardStorage`
     * @param isEnabled - The status of rewarding feature
     */
    function setRewardsFeature(bool isEnabled) internal onlyOwner {
        RewardStorage storage rs = getStorage();
        if (rs.rewardsEnabled == isEnabled) {
            revert RewardStateNotChanged(isEnabled);
        }
        rs.rewardsEnabled = isEnabled;
    }

    /**
     * @notice payReward - Sends rewards to the workers in the queue
     * @dev To prevent Denial of service, the number of possible rewards paid is limited
     * @dev The effective number of rewarded  workers is returned to allow event emiting for tracking and managing purposes
     * @param maxNumberOfPays - The max number of payments
     * @return rewardedAmount - The number of payments done
     */
    function payReward(uint256 maxNumberOfPays) internal returns (uint256 rewardedAmount) {
        RewardStorage storage rs = getStorage();

        uint256 rewardAmount = rs.rewardAmount;
        uint256 numberOfPays = rs.rewardQueue.length;
        if (numberOfPays > maxNumberOfPays) {
            numberOfPays = maxNumberOfPays;
        }
        if (numberOfPays > address(this).balance / rewardAmount) {
            numberOfPays = address(this).balance / rewardAmount;
        }

        for (uint256 i = 0; i < numberOfPays; i++) {
            address payable currentWorker = rs.rewardQueue[rs.rewardQueue.length - 1];
            rs.rewardQueue.pop();
            /// @dev `transfer` is safe, because worker is EOA
            currentWorker.transfer(rewardAmount);
        }
        rewardedAmount = numberOfPays;
    }

    function payRewardsToAll() internal returns (uint256 rewardedAmount) {
        uint256 numberOfPays = getStorage().rewardQueue.length;

        return payReward(numberOfPays);
    }

    /**
     * @dev isRewardEnabled - Checks if rewards are enabled
     * @return The status of rewarding feature
     */
    function isRewardEnabled() internal view returns (bool) {
        return getStorage().rewardsEnabled;
    }

    /**
     * @notice checkRewardEnabled - Checks if rewards are enabled
     * @dev The function throws the RewardsDisabled error if the rewarding feature is disabled
     */
    function checkRewardEnabled() internal view {
        if (!isRewardEnabled()) {
            revert RewardsDisabled();
        }
    }

    /**
     * @notice checkFunds - Checks if funds are sent to a transaction
     * @dev This function throws the ` NoFundsProvided` error if msg.value is 0 while calling a payable function
     */
    function checkFunds() internal view {
        if (msg.value == 0) {
            revert NoFundsProvided();
        }
    }

    /**
     * @dev Returns the storage
     * @return rs - A pointer to the rewardStorage slot position
     */
    function getStorage() internal pure returns (RewardStorage storage rs) {
        bytes32 position = _REWARD_STORAGE_POSITION;

        /* solhint-disable-next-line no-inline-assembly */
        assembly {
            rs.slot := position
        }
    }
}
