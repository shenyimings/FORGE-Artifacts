// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

/**
 * @title Interface for IELVault
 * @notice Vault will manage methods for rewards, commissions, tax
 */
interface IELVault {
    struct RewardMetadata {
        uint256 value;
        uint256 height;
    }

    function rewards(uint256 tokenId) external view returns (uint256);

    function getLiquidStakingReward() external view returns (uint256);

    function rewardsHeight() external view returns (uint256);

    function rewardsAndHeights(uint256 amt) external view returns (RewardMetadata[] memory);

    function dao() external view returns (address);

    function liquidStaking() external view returns (address);

    function settle() external;

    function publicSettle() external;

    function claimRewardsOfLiquidStaking() external returns (uint256);

    function claimRewardsOfUser(uint256 tokenId) external returns (uint256);

    function setUserNft(uint256 tokenId, uint256 number) external;

    function setLiquidStakingGasHeight(uint256 _gasHeight) external;
}
