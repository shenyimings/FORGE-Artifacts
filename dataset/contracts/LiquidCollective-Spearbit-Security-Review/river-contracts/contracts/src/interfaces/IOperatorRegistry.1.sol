//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../state/operatorsRegistry/Operators.sol";

interface IOperatorsRegistryV1 {
    error OperatorAlreadyExists(string name);
    error InactiveOperator(uint256 index);
    error InvalidFundedKeyDeletionAttempt();
    error InvalidUnsortedIndexes();
    error InvalidArrayLengths();
    error InvalidEmptyArray();
    error InvalidKeyCount();
    error InvalidPublicKeysLength();
    error InvalidSignatureLength();
    error InvalidIndexOutOfBounds();
    error OperatorLimitTooHigh(uint256 limit, uint256 keyCount);

    event AddedOperator(uint256 indexed index, string name, address operatorAddress, address feeRecipientAddress);
    event SetOperatorStatus(uint256 indexed index, bool active);
    event SetOperatorLimit(uint256 indexed index, uint256 newLimit);
    event SetOperatorStoppedValidatorCount(uint256 indexed index, uint256 newStoppedValidatorCount);
    event SetOperatorFeeRecipientAddress(uint256 indexed index, address newOperatorAddress);
    event SetOperatorAddress(uint256 indexed index, address newOperatorAddress);
    event SetOperatorName(uint256 indexed name, string newName);
    event AddedValidatorKeys(uint256 indexed index, bytes publicKeys);
    event RemovedValidatorKey(uint256 indexed index, bytes publicKey);

    function initOperatorsRegistryV1(address _admin, address _river) external;
    function listActiveOperators() external view returns (Operators.Operator[] memory);
    function getRiver() external view returns (address);
    function setRiver(address _newRiver) external;
    function getOperatorDetails(string calldata _name)
        external
        view
        returns (int256 _index, address _operatorAddress);
    function addOperator(string calldata _name, address _operator, address _feeRecipient) external;
    function setOperatorAddress(uint256 _index, address _newOperatorAddress) external;
    function setOperatorFeeRecipientAddress(uint256 _index, address _newOperatorFeeRecipientAddress) external;
    function setOperatorName(uint256 _index, string calldata _newName) external;
    function setOperatorStatus(uint256 _index, bool _newStatus) external;
    function setOperatorStoppedValidatorCount(uint256 _index, uint256 _newStoppedValidatorCount) external;
    function setOperatorLimits(uint256[] calldata _operatorIndexes, uint256[] calldata _newLimits) external;
    function addValidators(uint256 _index, uint256 _keyCount, bytes calldata _publicKeys, bytes calldata _signatures)
        external;
    function removeValidators(uint256 _index, uint256[] calldata _indexes) external;
    function getOperator(uint256 _index) external view returns (Operators.Operator memory);
    function getOperatorCount() external view returns (uint256);
    function getValidator(uint256 _operatorIndex, uint256 _validatorIndex)
        external
        view
        returns (bytes memory publicKey, bytes memory signature, bool funded);
    function pickNextValidators(uint256 _requestedAmount)
        external
        returns (bytes[] memory publicKeys, bytes[] memory signatures);
}
