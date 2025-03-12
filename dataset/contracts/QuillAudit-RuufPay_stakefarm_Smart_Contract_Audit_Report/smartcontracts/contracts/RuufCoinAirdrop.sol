// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract RuufCoinAirdrop {

    address immutable private token;
    address immutable private owner;

    constructor(address _token) {
        token = _token;
        owner = msg.sender;
    }

    function airdrop(address[] calldata _users, uint256[] calldata _balances) external {
        require(msg.sender == owner, "OnlyOwner");
        require(_users.length == _balances.length, "BadLengths");
        
        for (uint256 i=0; i<_users.length; i++) {
            IERC20(token).transfer(_users[i], _balances[i]);
        }
    }

    function withdraw() external {
        require(msg.sender == owner, "OnlyOwner");

        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner, balance);
    }
}
