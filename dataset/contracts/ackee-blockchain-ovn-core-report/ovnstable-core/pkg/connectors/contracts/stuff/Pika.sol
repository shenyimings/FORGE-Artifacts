// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface VaultFeeReward {

    function claimReward() external returns(uint256 rewardToSend);

}

interface VaultTokenReward {
    function getReward() external;

}

interface PikaPerpV3 {

    struct Stake {
        // 32 bytes
        address owner; // 20 bytes
        uint96 amount; // 12 bytes
        // 32 bytes
        uint128 shares; // 16 bytes
        uint128 timestamp; // 16 bytes
    }

    struct Vault {
        // 32 bytes
        uint128 cap; // Maximum capacity. 16 bytes
        uint128 balance; // 16 bytes
        // 32 bytes
        uint96 staked; // Total staked by users. 12 bytes
        uint96 shares; // Total ownership shares. 12 bytes
        uint64 stakingPeriod; // Time required to lock stake (seconds). 8 bytes
    }


    function redeem(
        address user,
        uint256 shares,
        address receiver
    ) external;


    function getShare(address stakeOwner) external view returns(uint256);

    function getTotalShare() external view returns(uint256);

    function getStake(address stakeOwner) external view returns(Stake memory);
    function getVault() external view returns(Vault memory);

    function stake(uint256 amount, address user) external;
}

