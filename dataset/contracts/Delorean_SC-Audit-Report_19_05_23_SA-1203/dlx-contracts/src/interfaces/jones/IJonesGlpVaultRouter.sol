// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { IJonesGlpCompoundRewards } from "./IJonesGlpCompoundRewards.sol";
import { IJonesGlpRewardTracker } from "./IJonesGlpRewardTracker.sol";

abstract contract IJonesGlpVaultRouter {
    mapping(address => IJonesGlpRewardTracker) public rewardTrackers;
    mapping(address => IJonesGlpCompoundRewards) public rewardCompounder;

    IJonesGlpRewardTracker public glpRewardTracker;

    function depositGlp(uint256 _assets, address _sender, bool _compound) external virtual returns (uint256);
    function depositStable(uint256 _assets, bool _compound, address _user) external virtual returns (uint256);
    function redeemGlpAdapter(uint256 _shares, bool _compound, address _token, address _user, bool _native)
        external
        virtual
        returns (uint256);

    function unCompoundGlpRewards(uint256 _shares, address _user) external virtual returns (uint256);
    function compoundGlpRewards(uint256 _shares) external virtual returns (uint256);
    function claimRewards() external virtual returns (uint256, uint256, uint256);
}
