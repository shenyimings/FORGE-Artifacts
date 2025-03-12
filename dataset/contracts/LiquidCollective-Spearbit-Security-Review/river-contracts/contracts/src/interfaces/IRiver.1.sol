//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./components/IConsensusLayerDepositManager.1.sol";
import "./components/IOracleManager.1.sol";
import "./components/ISharesManager.1.sol";
import "./components/IUserDepositManager.1.sol";

interface IRiverV1 is IConsensusLayerDepositManagerV1, IUserDepositManagerV1, ISharesManagerV1, IOracleManagerV1 {
    error ZeroMintedShares();

    event PulledELFees(uint256 amount);

    function initRiverV1(
        address _depositContractAddress,
        address _elFeeRecipientAddress,
        bytes32 _withdrawalCredentials,
        address _oracleAddress,
        address _systemAdministratorAddress,
        address _allowlistAddress,
        address _operatorRegistryAddress,
        address _treasuryAddress,
        uint256 _globalFee,
        uint256 _operatorRewardsShare
    )
        external;

    function setGlobalFee(uint256 newFee) external;
    function getGlobalFee() external view returns (uint256);
    function setOperatorRewardsShare(uint256 newOperatorRewardsShare) external;
    function getOperatorRewardsShare() external view returns (uint256);
    function setAllowlist(address _newAllowlist) external;
    function getAllowlist() external view returns (address);
    function setTreasury(address _newTreasury) external;
    function getTreasury() external view returns (address);
    function transferOwnership(address _newAdmin) external;
    function acceptOwnership() external;
    function getAdministrator() external view returns (address);
    function getPendingAdministrator() external view returns (address);
    function setELFeeRecipient(address _newELFeeRecipient) external;
    function getELFeeRecipient() external view returns (address);
    function sendELFees() external payable;
}
