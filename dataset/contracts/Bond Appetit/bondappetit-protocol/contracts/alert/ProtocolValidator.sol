// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../utils/OwnablePausable.sol";
import "./IValidator.sol";

contract ProtocolValidator is Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The number of validators in agregate.
    uint256 public maxSize;

    /// @dev Protocol contracts list.
    EnumerableSet.AddressSet internal protocolContracts;

    /// @notice Validator and controlled contract (zero address for all protocol contracts).
    mapping(address => address) public validators;

    /// @dev Validators list.
    EnumerableSet.AddressSet internal validatorsIndex;

    /// @notice An event thats emitted when protocol contract added.
    event ProtocolContractAdded(address newContract);

    /// @notice An event thats emitted when protocol contract removed.
    event ProtocolContractRemoved(address removedContract);

    /// @notice An event thats emitted when validator added.
    event ValidatorAdded(address validator, address controlledContract);

    /// @notice An event thats emitted when validator removed.
    event ValidatorRemoved(address validator);

    /// @notice An event thats emitted when state invalid.
    event InvalidState(address validator, address controlledContract);

    /**
     * @param _maxSize Maximal count of protocol contracts and validators.
     */
    constructor(uint256 _maxSize) public {
        maxSize = _maxSize;
    }

    /**
     * @return Validators count of agregate.
     */
    function size() public view returns (uint256) {
        return validatorsIndex.length().add(protocolContracts.length());
    }

    /**
     * @param _contract Protocol contract address.
     */
    function addProtocolContract(address _contract) external onlyOwner {
        require(_contract != address(0), "ProtocolValidator::addProtocolContract: invalid contract address");
        require(protocolContracts.contains(_contract) || size() < maxSize, "ProtocolValidator::addProtocolContract: too many protocol contracts");

        protocolContracts.add(_contract);
        emit ProtocolContractAdded(_contract);
    }

    /**
     * @param _contract Protocol contract address.
     */
    function removeProtocolContract(address _contract) external onlyOwner {
        require(_contract != address(0), "ProtocolValidator::removeProtocolContract: invalid contract address");

        protocolContracts.remove(_contract);
        emit ProtocolContractRemoved(_contract);
    }

    /**
     * @return Addresses of all protocol contracts.
     */
    function protocolContractsList() external view returns (address[] memory) {
        address[] memory result = new address[](protocolContracts.length());

        for (uint256 i = 0; i < protocolContracts.length(); i++) {
            result[i] = protocolContracts.at(i);
        }

        return result;
    }

    /**
     * @param validator Validator address.
     * @param controlledContract Pausable contract address (zero address for all protocol contracts).
     */
    function addValidator(address validator, address controlledContract) external onlyOwner {
        require(validator != address(0), "ProtocolValidator::addValidator: invalid validator address");
        require(validatorsIndex.contains(validator) || size() < maxSize, "ProtocolValidator::addValidator: too many validators");

        validators[validator] = controlledContract;
        validatorsIndex.add(validator);
        emit ValidatorAdded(validator, controlledContract);
    }

    /**
     * @param validator Validator address.
     */
    function removeValidator(address validator) external onlyOwner {
        require(validator != address(0), "ProtocolValidator::removeValidator: invalid validator address");

        validators[validator] = address(0);
        validatorsIndex.remove(validator);
        emit ValidatorRemoved(validator);
    }

    /**
     * @return Validators addresses list.
     */
    function validatorsList() external view returns (address[] memory) {
        address[] memory result = new address[](validatorsIndex.length());

        for (uint256 i = 0; i < validatorsIndex.length(); i++) {
            result[i] = validatorsIndex.at(i);
        }

        return result;
    }

    /**
     * @dev Pause contract or all protocol contracts.
     * @param controlledContract Paused contract (zero address for all protocol contracts).
     */
    function _pause(address controlledContract) internal {
        if (controlledContract == address(0)) {
            for (uint256 i = 0; i < protocolContracts.length(); i++) {
                _pause(protocolContracts.at(i));
            }
        } else {
            OwnablePausable target = OwnablePausable(controlledContract);
            address pauser = target.pauser();
            require(pauser == address(this), "ProtocolValidator::_pause: target contract not control");
            bool paused = target.paused();

            if (!paused) {
                target.pause();
            }
        }
    }

    /**
     * @notice Validate protocol state and pause controlled contract if state invalid.
     * @param validator Target validator.
     * @return Is state valid.
     */
    function validate(address validator) external returns (bool) {
        require(validatorsIndex.contains(validator), "ProtocolValidator::validate: validator not found");

        bool isValid = IValidator(validator).validate();
        if (!isValid) {
            _pause(validators[validator]);
            emit InvalidState(validator, validators[validator]);
        }

        return isValid;
    }
}
