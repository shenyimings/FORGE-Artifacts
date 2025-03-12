//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

contract User {
    receive() external payable {}
    fallback() external payable {}
}

contract UserFactory {
    uint256 internal counter;

    function _new(uint256 _salt) external returns (address user) {
        user = address(new User{salt: bytes32(keccak256(abi.encodePacked(_salt, counter)))}());
        ++counter;
    }
}
