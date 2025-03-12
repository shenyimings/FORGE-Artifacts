// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IOracle.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Interface of gamejam .
 */
contract SuperfineOracle is IOracle, Ownable, ReentrancyGuard {
    mapping(address => uint256) private tokenRate; // rate token(with decimals)/USDT (with decimal 6)

    constructor() {}

    function setRate(
        address[] memory tokenAddrs,
        uint256[] memory rate
    ) external override onlyOwner nonReentrant {
        require(
            tokenAddrs.length == rate.length,
            "SuperfineOracle: addrs and amount does not same length"
        );
        for (uint256 i = 0; i < tokenAddrs.length; i++) {
            tokenRate[tokenAddrs[i]] = rate[i];
        }
    }

    function GetRate(
        address tokenAddress
    ) external view override returns (uint256) {
        return tokenRate[tokenAddress];
    }
}
