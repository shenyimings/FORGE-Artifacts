// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol";

interface IStETH is IERC20Upgradeable, IERC20PermitUpgradeable {
    function getLidoLocator() external view returns (ILidoLocator);

    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);

    function submit(address _referral) external payable returns (uint256);
}

interface ILidoLocator {
    function accountingOracle() external view returns (address);

    function depositSecurityModule() external view returns (address);

    function elRewardsVault() external view returns (address);

    function legacyOracle() external view returns (address);

    function lido() external view returns (address);

    function oracleReportSanityChecker() external view returns (address);

    function burner() external view returns (address);

    function stakingRouter() external view returns (address);

    function treasury() external view returns (address);

    function validatorsExitBusOracle() external view returns (address);

    function withdrawalQueue() external view returns (address);

    function withdrawalVault() external view returns (address);

    function postTokenRebaseReceiver() external view returns (address);

    function oracleDaemonConfig() external view returns (address);

    function coreComponents()
        external
        view
        returns (
            address elRewardsVault,
            address oracleReportSanityChecker,
            address stakingRouter,
            address treasury,
            address withdrawalQueue,
            address withdrawalVault
        );

    function oracleReportComponentsForLido()
        external
        view
        returns (
            address accountingOracle,
            address elRewardsVault,
            address oracleReportSanityChecker,
            address burner,
            address withdrawalQueue,
            address withdrawalVault,
            address postTokenRebaseReceiver
        );
}

interface ILidoWithdrawalQueueERC721 {
    struct WithdrawalRequestStatus {
        /// @notice stETH token amount that was locked on withdrawal queue for this request
        uint256 amountOfStETH;
        /// @notice amount of stETH shares locked on withdrawal queue for this request
        uint256 amountOfShares;
        /// @notice address that can claim or transfer this request
        address owner;
        /// @notice timestamp of when the request was created, in seconds
        uint256 timestamp;
        /// @notice true, if request is finalized
        bool isFinalized;
        /// @notice true, if request is claimed. Request is claimable if (isFinalized && !isClaimed)
        bool isClaimed;
    }

    function requestWithdrawals(
        uint256[] calldata _amounts,
        address _owner
    ) external returns (uint256[] memory requestIds);

    function claimWithdrawal(uint256 _requestId) external;

    function claimWithdrawals(uint256[] calldata _requestIds, uint256[] calldata _hints) external;

    function claimWithdrawalsTo(uint256[] calldata _requestIds, uint256[] calldata _hints, address _recipient) external;

    function getWithdrawalRequests(address _owner) external view returns (uint256[] memory requestsIds);

    function getWithdrawalStatus(
        uint256[] calldata _requestIds
    ) external view returns (WithdrawalRequestStatus[] memory statuses);

    function getLastCheckpointIndex() external view returns (uint256);

    function findCheckpointHints(
        uint256[] calldata _requestIds,
        uint256 _firstIndex,
        uint256 _lastIndex
    ) external view returns (uint256[] memory hintIds);
}
