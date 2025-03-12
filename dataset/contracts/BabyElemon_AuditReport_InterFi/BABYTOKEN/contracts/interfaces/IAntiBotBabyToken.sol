// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IAntiBotBabyToken {
    function initialize(
        address[5] memory addrs, // [0] = owner, [1] = rewardToken, [2] = router, [3] = marketing wallet, [4] = anti bot
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
