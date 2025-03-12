// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../Utils/SafeMath.sol";


/**
 * @title A vault to hold and distribute tokens efficiently.
 */
contract MuteVault {
    using SafeMath for uint256;

    address public token;
    address public geyser;
    uint256 public rewarded;
    address public owner;

    constructor(address _token, address _geyser) public {
        token = _token;
        geyser = _geyser;
        IMute(token).approve(geyser, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        owner = msg.sender;
    }

    function balance() public view returns (uint256) {
        return IMute(token).balanceOf(address(this));
    }

    function reward() external returns (bool) {
        require(balance() > 0, 'MuteVault::reward: Cannot reward 0 balance');
        require(msg.sender == token || msg.sender == owner, "MuteVault::reward: Can only be called by the token contract");

        rewarded = rewarded.add(balance());

        ITokenGeyser(geyser).addTokens(balance());
        return true;
    }
}

interface IMute {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface ITokenGeyser {
    function addTokens(uint256 amount) external;
}
