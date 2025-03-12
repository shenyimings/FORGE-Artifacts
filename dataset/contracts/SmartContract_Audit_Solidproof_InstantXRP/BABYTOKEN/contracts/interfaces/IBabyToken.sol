// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IBabyToken {
    function initialize(
        address[4] memory addrs, // [0] = owner, [1] = rewardToken, [2] = router, [3] = marketing wallet
        address dividendTrackerImplementation,
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        uint256 tokenRewardsFee_,
        uint256 liquidityFee_,
        uint256 marketingFee_,
        uint256 minimumTokenBalanceForDividends_
    ) external;
}
