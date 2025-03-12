// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "./EmergencyOperator.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract VerifierV2 is Ownable, Pausable {
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);

    uint8 public constant VALIDATOR_LIMIT = 50;

    EmergencyOperator public emergencyOperator;
    address[] public validators;
    mapping(address => uint8) private validatorIndexes;

    constructor(address _emergencyOperator) {
        emergencyOperator = EmergencyOperator(_emergencyOperator);
    }

    function pause() external {
        require(emergencyOperator.isEmergencyOperator(msg.sender), "no permission");
        _pause();
    }

    function unpause() external {
        require(emergencyOperator.isEmergencyOperator(msg.sender), "no permission");
        _unpause();
    }

    function size() public view returns (uint256) {
        return validators.length;
    }

    function get(uint256 offset, uint8 limit) public view returns (uint256 count_, address[] memory validators_) {
        count_ = validators.length;
        validators_ = new address[](limit);
        for (uint256 i = 0; i < limit; i++) {
            if (offset + i >= validators.length) {
                break;
            }
            validators_[i] = validators[offset + i];
        }
    }

    function addAll(address[] memory _validators) public onlyOwner {
        require(validators.length + _validators.length < VALIDATOR_LIMIT, "hit max validator limit");
        address validator;
        for (uint256 i = 0; i < _validators.length; i++) {
            validator = _validators[i];
            require(validator != address(0), "invalid validator");
            if (validatorIndexes[validator] != 0) {
                continue;
            }
            validators.push(validator);
            validatorIndexes[validator] = uint8(validators.length);
            emit ValidatorAdded(validator);
        }
    }

    function removeAll(address[] memory _validators) public onlyOwner {
        address validator;
        address last;
        uint8 index;
        for (uint256 i = 0; i < _validators.length; i++) {
            validator = _validators[i];
            index = validatorIndexes[validator];
            if (index == 0) {
                continue;
            }
            last = validators[validators.length - 1];
            validators[index - 1] = last;
            validatorIndexes[last] = index;
            validators.pop();
            delete validatorIndexes[validator];
            emit ValidatorRemoved(validator);
        }
    }

    function verify(bytes32 _key, bytes memory _signatures)
        public
        view 
        whenNotPaused
        returns (bool isValid_, address[] memory validators_)
    {
        uint256 numOfSignatures = _signatures.length / 65;
        bool[VALIDATOR_LIMIT] memory seen;
        address validator;
        uint8 index;
        validators_ = new address[](numOfSignatures);
        for (uint256 i = 0; i < numOfSignatures; i++) {
            validator = recover(_key, _signatures, i * 65);
            index = validatorIndexes[validator];
            require(index != 0, "invalid validator");
            require(!seen[index], "duplicate validator");
            seen[index] = true;
            validators_[i] = validator;
        }
        isValid_ = validators_.length * 3 > validators.length * 2;
    }

    function recover(
        bytes32 hash,
        bytes memory signature,
        uint256 offset
    ) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        // Divide the signature in r, s and v variables with inline assembly.

        // solium-disable-next-line security/no-inline-assembly
        assembly {
            r := mload(add(signature, add(offset, 0x20)))
            s := mload(add(signature, add(offset, 0x40)))
            v := byte(0, mload(add(signature, add(offset, 0x60))))
        }

        // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
        if (v < 27) {
            v += 27;
        }

        // If the version is correct return the signer address
        if (v != 27 && v != 28) {
            return (address(0));
        }
        // solium-disable-next-line arg-overflow
        return ecrecover(hash, v, r, s);
    }
}
