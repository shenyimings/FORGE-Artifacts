// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.23;

import "../Vesting.sol";
import "./CloneFactory.sol";

/**
 * @title VestingCloneFactory
 * @author malteish
 * @notice Create clones of a Vesting contract with deterministic addresses
 */
contract VestingCloneFactory is CloneFactory {
    constructor(address _implementation) CloneFactory(_implementation) {}

    /**
     * Create and initialize a clone
     * @param _rawSalt value that influences the address of the clone, but not the initialization
     * @param _trustedForwarder the trusted forwarder (ERC2771) can not be changed, but is checked for security
     * @param _owner address that will own the new clone
     * @param _token address of the token to be vested
     * @return address of the clone that was created
     */
    function createVestingClone(
        bytes32 _rawSalt,
        address _trustedForwarder,
        address _owner,
        address _token
    ) external returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(_rawSalt, _trustedForwarder, _owner, _token));
        address clone = Clones.cloneDeterministic(implementation, salt);
        Vesting vesting = Vesting(clone);
        require(vesting.isTrustedForwarder(_trustedForwarder), "VestingCloneFactory: Unexpected trustedForwarder");
        vesting.initialize(_owner, _token);
        emit NewClone(clone);
        return clone;
    }

    /**
     * Calculate the address a clone will have using the given parameters
     * @param _rawSalt value that influences the address of the clone, but not the initialization
     * @param _trustedForwarder the trusted forwarder (ERC2771) can not be changed, but is checked for security
     * @param _owner owner of the clone
     * @param _token token to vest
     */
    function predictCloneAddress(
        bytes32 _rawSalt,
        address _trustedForwarder,
        address _owner,
        address _token
    ) external view returns (address) {
        require(
            Vesting(implementation).isTrustedForwarder(_trustedForwarder),
            "VestingCloneFactory: Unexpected trustedForwarder"
        );
        bytes32 salt = keccak256(abi.encodePacked(_rawSalt, _trustedForwarder, _owner, _token));
        return Clones.predictDeterministicAddress(implementation, salt);
    }
}
