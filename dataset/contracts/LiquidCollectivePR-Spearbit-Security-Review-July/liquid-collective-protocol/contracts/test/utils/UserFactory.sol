//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

contract User {
    receive() external payable {}
    fallback() external payable {}
}

contract UserFactory {
    uint256 internal counter;

    function _new(uint256 _salt) public returns (address user) {
        user = address(new User{salt: bytes32(keccak256(abi.encodePacked(_salt, counter)))}());
        ++counter;
    }

    function _newMulti(uint256 _salt, uint256 _count) external returns (address[] memory users) {
        users = new address[](_count);
        for (uint256 i; i < _count; i++) {
            users[i] = _new(_salt);
        }
    }
}
