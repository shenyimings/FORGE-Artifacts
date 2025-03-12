// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {IRewardsManager} from "src/interfaces/IRewardsManager.sol";

contract RewardsManagerMock is IRewardsManager {
    error RewardsControllerCall();

    address public immutable POOL;
    address public immutable MORPHO;

    constructor(address morpho) {
        MORPHO = morpho;
        POOL = IMorpho(morpho).pool();
    }

    function REWARDS_CONTROLLER() external pure returns (address) {
        revert RewardsControllerCall();
    }

    function getRewardData(address asset, address reward)
        external
        view
        returns (uint256 startingIndex, uint256 index, uint256 lastUpdateTimestamp)
    {}

    function getUserData(address asset, address reward, address user)
        external
        view
        returns (uint256 index, uint256 accrued)
    {}

    function getAllUserRewards(address[] calldata assets, address user)
        external
        view
        returns (address[] memory rewardsList, uint256[] memory unclaimedAmounts)
    {}
    function getUserRewards(address[] calldata assets, address user, address reward) external view returns (uint256) {}

    function getUserAccruedRewards(address[] calldata assets, address user, address reward)
        external
        view
        returns (uint256 totalAccrued)
    {}

    function getUserAssetIndex(address user, address asset, address reward) external view returns (uint256) {}
    function getAssetIndex(address asset, address reward) external view returns (uint256 assetIndex) {}

    function claimRewards(address[] calldata assets, address user)
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        for (uint256 i; i < assets.length; i++) {
            emit Accrued(assets[i], address(0), user, 0, 0);
        }
        // Just silencing a compiler warning
        rewardsList = rewardsList;
        claimedAmounts = claimedAmounts;
    }

    function updateUserRewards(address user, address asset, uint256 userBalance) external {}
}
