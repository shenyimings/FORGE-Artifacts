// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReflectionManager {
    function initialize(address _rewardToken) external;
    function setShare(address shareholder, uint256 amount) external;
    function update_deposit(uint256 amount) external;
    function process(uint256 gas) external returns (uint256 currentIndex, uint256 iterations, uint256 claims, bool dismission_completed);
    function claimDividend(address shareholder) external;
    function dismissReflectionManager() external;
    function getUnpaidEarnings(address shareholder) external view returns (uint256);
    function setReflectionEnabledContract(address _contractAddress, bool _enableDisable) external;
    function setReflectionDisabledWallet(address _walletAddress, bool _disableEnable) external;
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution, uint256 _eligibilityThresholdShares) external;
    function setAutoDistributionExcludeFlag(address _shareholder, bool _exclude) external;
    function isDismission() external view returns (bool dismission_is_started, bool dismission_is_completed);
    function getAccountInfo(address shareholder) external view returns (
        uint256 index,
        uint256 currentShares,
        int256 iterationsUntilProcessed,
        uint256 withdrawableDividends,
        uint256 totalRealisedDividends,
        uint256 totalExcludedDividends,
        uint256 lastClaimTime,
        uint256 nextClaimTime,
        bool shouldAutoDistribute,
        bool excludedAutoDistribution,
        bool enabled );
    function getReflectionManagerInfo() external view returns (
        uint256 n_shareholders,
        uint256 current_index,
        uint256 manager_balance,
        uint256 total_shares,
        uint256 total_dividends,
        uint256 total_distributed,
        uint256 dividends_per_share,
        uint256 eligibility_threshold_shares,
        uint256 min_period,
        uint256 min_distribution,
        uint8 dismission );
    function getShareholderAtIndex(uint256 index) external view returns (address);

    event Initialized(address indexed caller, address _rewardToken);
    event Claim(address indexed shareholder, uint256 amount, bool indexed automatic);
    event setDistributionCriteriaUpdate(uint256 minPeriod, uint256 minDistribution, uint256 eligibilityThresholdShares);
    event setReflectionEnabledContractUpdate(address indexed _contractAddress, bool indexed _enableDisable);
    event setReflectionDisabledWalletUpdate(address indexed _walletAddress, bool indexed _disableEnable);
    event setAutoDistributionExcludeFlagUpdate(address indexed _shareholder, bool indexed _exclude);

}