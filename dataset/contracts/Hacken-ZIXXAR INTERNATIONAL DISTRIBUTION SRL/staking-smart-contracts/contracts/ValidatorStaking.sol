// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract ValidatorStaking {
    struct Validator {
        address validatorNodeAddress;
        uint256 amount;
        string machineId;
        bytes signature;
    }

    mapping(address => uint256) internal stakes;
    mapping(address => Validator) internal validators;
    mapping(string => uint256) internal allowedMachineIds;
    uint256 internal totalEntries = 1;

    /// @notice Calculates a hash composed by nodeAddress and machine id
    /// @dev Make sure only the signer of this message can call the _removeStake method
    /// @param _validatorNodeAddress the node validator address
    /// @param _message license of the machine added in the whitelist
    /// @return bytes32 keccak256 hash signature
    function getMessageHash(
        address _validatorNodeAddress,
        string memory _message
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_validatorNodeAddress, _message));
    }

    /// @notice Add new machine id to the whitelist of allowed validators
    function _addNewMachineId(string memory machineId) internal {
        uint256 index = allowedMachineIds[machineId];
        require(index == 0, "The machine id is already assigned as validator!");
        allowedMachineIds[machineId] = totalEntries;
        totalEntries++;
    }

    /// @notice Set a node address to the list of staking validators
    function _setNewStake(
        address _validatorNodeAddress,
        uint256 _amount,
        string memory _machineId,
        bytes memory _signature
    ) internal {
        uint256 index = allowedMachineIds[_machineId];
        uint256 stakedAmount = stakes[msg.sender];

        require(
            _validatorNodeAddress != address(0),
            "Can not stake to Zero Address"
        );
        require(
            _validatorNodeAddress != msg.sender,
            "You can not set your self as staker"
        );
        require(index != 0, "This license is not whitelisted!");
        require(stakedAmount == 0, "This node node is already a validator ");

        stakes[msg.sender] += _amount;
        validators[msg.sender] = Validator({
            validatorNodeAddress: _validatorNodeAddress,
            amount: _amount,
            machineId: _machineId,
            signature: _signature
        });
    }

    /// @notice Remove a node address from the list of staking validators
    function _removeStake(
        address _validatorNodeAddress,
        string memory _machineId
    ) internal {
        uint256 stakedAmount = stakes[msg.sender];
        require(stakedAmount > 0, "You are not in the validators list");

        require(
            verify(
                msg.sender,
                _validatorNodeAddress,
                _machineId,
                validators[msg.sender].signature
            ),
            "invalid signature match"
        );

        stakes[msg.sender] = 0;
        delete validators[msg.sender];
    }

    /// @notice Extracts r, s, v from a signature
    /// @dev First 32 bytes stores the length of the signature
    /// @dev Skip first 32 bytes of signature add(sig, 32) = pointer of sig + 32
    /// @dev mload(p) loads next 32 bytes starting at the memory address p into memory
    /// @dev add(sig, 32) = pointer of sig + 3
    /// @dev add(sig, 32) = pointer of sig + 3
    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function verify(
        address _signer,
        address _validatorNodeAddress,
        string memory _message,
        bytes memory signature
    ) internal pure returns (bool) {
        bytes32 messageHash = getMessageHash(_validatorNodeAddress, _message);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    /// @dev Signature is produced by signing a keccak256 hash with the following format:
    /// @dev "\x19Ethereum Signed Message\n" + len(msg) + msg
    function getEthSignedMessageHash(bytes32 _messageHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }
}
