// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRadpieStakingReader {

    struct RadiantStakingPool {
        address asset; // asset on Radiant
        address rToken;
        address vdToken;
        address rewarder;
        address helper;
        address receiptToken;
        uint256 maxCap;             // max receipt token amount
        uint256 lastActionHandled; // timestamp of ActionHandled trigged on Radiant ChefIncentive
        bool isNative;
        bool isActive;
    }

    function lastSeenClaimableTime() external view returns(uint256);

    function pools(address) external view returns (
        address asset,
        address rToken,
        address vdToken,
        address rewarder,
        address receiptToken,
        uint256 maxCap,
        uint256 lastActionHandled,
        bool isNative,
        bool isActive        
    );

    function assetPerShare(address _asset) external view returns (uint256);

    function rdntRewardEligibility() external view returns(bool isEligibleForRDNT, uint256 lockedDLPUSD, uint256 totalCollateralUSD, 
        uint256 requiredDLPUSD, uint256 requiredDLPUSDWithTolerance);

    function claimableAndPendingRDNT(address[] calldata _tokens) external view
        returns (uint256 claimmable, uint256[] memory pendings, uint256 vesting, uint256 vested);

    function rdntVestManager() external view returns(address);

    function systemHealthFactor() external view returns(uint256);

    function minHealthFactor() external view returns(uint256);

    function totalEarnedRDNT() external view returns(uint256);

    function assetLoopHelper() external view returns(address);
}