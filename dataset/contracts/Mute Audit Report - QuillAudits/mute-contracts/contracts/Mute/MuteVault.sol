// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../Utils/SafeMath.sol";


/**
 * @title A vault to hold and distribute tokens to uniswap pairs.
 */
contract MuteVault {
    using SafeMath for uint256;

    address public token;
    address public pair;
    uint256 public rewarded;
    address public owner;


    constructor(address _token) public {
        token = _token;
        owner = msg.sender;
    }

    function setPair(address _pair) external {
        require(msg.sender == owner, "MuteVault::setPair: Can only be called by the owner");
        pair = _pair;
    }

    function balance() public view returns (uint256) {
        return IMute(token).balanceOf(address(this));
    }

    function reward() external returns (bool) {
        require(balance() > 0, 'MuteVault::reward: Cannot reward 0 balance');
        require(msg.sender == token || msg.sender == owner, "MuteVault::reward: Can only be called by the token contract");

        rewarded = rewarded.add(balance());

        IMute(token).transfer(pair, balance());
        return true;
    }
}

interface IMute {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}
