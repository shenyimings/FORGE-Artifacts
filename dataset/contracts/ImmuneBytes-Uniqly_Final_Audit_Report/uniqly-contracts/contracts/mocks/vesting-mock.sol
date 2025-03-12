// SPDX-License-Identifier: Ulicense
pragma solidity ^0.8.6;

contract VestingMock {
    // user is eligible to receive bonus NFT tokens (default=0)
    mapping(address => uint256) internal _bonus;

    /// it will be used by future contract
    function bonus(address user) external view returns (uint256) {
        return _bonus[user];
    }

    function registerBonus(address user, uint256 amt) external {
        _bonus[user] = amt;
    }
}
