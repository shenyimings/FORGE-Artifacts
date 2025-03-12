// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

contract TestimonyDAO {
    event Testimony(address indexed validator, bytes32 indexed key, bytes testimony);

    function addTestimony(bytes32 key, bytes calldata value) public {
        emit Testimony(msg.sender, key, value);
    }
}
