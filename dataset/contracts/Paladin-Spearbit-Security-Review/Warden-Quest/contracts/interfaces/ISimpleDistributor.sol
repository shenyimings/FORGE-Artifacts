// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface for Merkle Disitributor
 */
interface ISimpleDistributor {

    function claim(
        uint256 questID,
        uint256 period,
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external;
}
