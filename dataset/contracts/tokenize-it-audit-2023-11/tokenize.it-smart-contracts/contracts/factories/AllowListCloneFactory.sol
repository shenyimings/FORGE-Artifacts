// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.23;

import "../AllowList.sol";
import "./CloneFactory.sol";

/**
 * @title AllowListCloneFactory
 * @author malteish
 * @notice Create clones of an AllowList contract with deterministic addresses
 */
contract AllowListCloneFactory is CloneFactory {
    constructor(address _implementation) CloneFactory(_implementation) {}

    /**
     * Create a clone
     * @param _rawSalt this value influences the address of the clone, but not the initialization
     * @param _trustedForwarder the trusted forwarder (ERC2771) can not be changed, but is checked for security
     * @param _owner address that will own the new clone
     * @return address of the new clone
     */
    function createAllowListClone(
        bytes32 _rawSalt,
        address _trustedForwarder,
        address _owner
    ) external returns (address) {
        bytes32 salt = _generateSalt(_rawSalt, _trustedForwarder, _owner);
        address clone = Clones.cloneDeterministic(implementation, salt);
        AllowList cloneAllowList = AllowList(clone);
        require(
            cloneAllowList.isTrustedForwarder(_trustedForwarder),
            "AllowListCloneFactory: Unexpected trustedForwarder"
        );
        cloneAllowList.initialize(_owner);
        emit NewClone(clone);
        return clone;
    }

    /**
     * Return the address a clone would have if it was created with these parameters.
     * @param _rawSalt this value influences the address of the clone, but not the initialization
     * @param _trustedForwarder the trusted forwarder (ERC2771) can not be changed, but is checked for security
     * @param _owner address that will own the new clone
     * @return address of the new clone
     */
    function predictCloneAddress(
        bytes32 _rawSalt,
        address _trustedForwarder,
        address _owner
    ) external view returns (address) {
        bytes32 salt = _generateSalt(_rawSalt, _trustedForwarder, _owner);
        return Clones.predictDeterministicAddress(implementation, salt);
    }

    /**
     * Generate a single salt from all input parameters
     * @param _rawSalt this value influences the address of the clone, but not the initialization
     * @param _trustedForwarder the trusted forwarder (ERC2771) can not be changed, but is checked for security
     * @param _owner address that will own the new clone
     * @return salt
     */
    function _generateSalt(
        bytes32 _rawSalt,
        address _trustedForwarder,
        address _owner
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_rawSalt, _trustedForwarder, _owner));
    }
}
