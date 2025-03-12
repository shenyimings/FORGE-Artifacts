//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IConsensusLayerDepositManagerV1 {
    event FundedValidatorKey(bytes publicKey);

    error NotEnoughFunds();
    error InconsistentPublicKeys();
    error InconsistentSignatures();
    error NoAvailableValidatorKeys();
    error InvalidPublicKeyCount();
    error InvalidSignatureCount();
    error InvalidWithdrawalCredentials();

    function getWithdrawalCredentials() external view returns (bytes32);
    function depositToConsensusLayer(uint256 _maxCount) external;
    function getDepositedValidatorCount() external view returns (uint256 depositedValidatorCount);
}
