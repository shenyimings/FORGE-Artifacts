pragma solidity 0.7.5;

interface IStakedTokenIncentivesController {
    function claimRewards(
        address[] calldata assets,
        uint256 amount,
        address to
    ) external;

    function getRewardsBalance(address[] calldata assets, address user) external view returns (uint256);

    function configureAssets(address[] calldata assets, uint256[] calldata emissionsPerSecond) external;

    function setDistributionEnd(uint256 distributionEnd) external;

    function initialize(address addressesProvider) external;
}
