// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IRewardDistributor {
    // External View Functions
    function getTotalDlpLocked() external view returns (uint256);

    function claimableDlpRewards()
        external
        view
        returns (address[] memory rewardTokens, uint256[] memory amounts);

    function claimableAndPendingRDNT(
        address[] calldata tokens
    )
        external
        view
        returns (uint256 claimable, uint256[] memory pendings, uint256 vesting, uint256 vested);

    function rdntRewardEligibility()
        external
        view
        returns (
            bool isEligibleForRDNT,
            uint256 lockedDLPUSD,
            uint256 totalCollateralUSD,
            uint256 requiredDLPUSD,
            uint256 requiredDLPUSDWithTolerance
        );

    function sendRewards(address asset, address rewardToken, uint256 amount) external;

    function enqueueRDNT(
        address[] memory _poolTokenList,
        uint256 _lastSeenClaimableRDNT,
        uint256 _updatedClamable
    ) external;

    function getCalculatedStreamingFeePercentage(address _receiptToken) external view returns(uint256);

    function calculateStreamingFeeInflation(
        address _receiptToken,
        uint256 _feePercentage
    )
    external
    view
    returns (uint256);

    function updatelastStreamingLastFeeTimestamp(
        address _receiptToken,
        uint256 _updatedLastStreamingTime
    ) external;

    function streamingFeePercentage(address _receiptToken) external view returns (uint256);

    function enqueueEntitledRDNT(address _receipt, uint256 _amount) external;
}
