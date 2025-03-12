// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./Factory.sol";

/**
 * @title CloneFactory
 * @dev Inherit from this contract to allow creation of Clones of a specific contract.
 * @author malteish
 */

abstract contract CloneFactory is Factory {
    event NewClone(address clone);

    constructor(address _implementation) Factory(_implementation) {}

    /**
     * @notice Predicts the address of a clone that will be created
     * @param salt The salt used to deterministically generate the clone address
     * @return The address of the clone that will be created
     * @dev This function does not check if the clone has already been created
     */
    function predictCloneAddress(bytes32 salt) public view returns (address) {
        return Clones.predictDeterministicAddress(implementation, salt);
    }
}
