// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./PoolToken.sol";

abstract contract PoolStorage {
    using SafeMath for uint256;
    string public name;
    address public stableCoin;
    uint256 public minDeposit;
    PoolToken public lpToken;

    uint256 public totalDeposited;
    uint256 public totalBorrowed;  

    struct LoanStruct {
        uint256 borrowedAmount;
        address nftFactory;
    }

    mapping(address => uint256) public balances;
    mapping(uint256 => LoanStruct) public loans;
    mapping(address => uint256) public lockedTokens;

    modifier isAvailable(uint256 amount) {
        require(this.totalAvailable() >= amount, "Not enough tokens available");
        _;
    }

    function totalAvailable() external view returns (uint256) {
        return totalDeposited.sub(totalBorrowed);
    }
}

abstract contract Structured {
    string public structureType;

    function isStructured(string memory structure)
        internal
        pure
        returns (bool)
    {
        return
            keccak256(bytes(structure)) == keccak256(bytes("factoring")) ||
            keccak256(bytes(structure)) == keccak256(bytes("discounting"));
    }
}