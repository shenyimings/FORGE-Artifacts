// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./IManager.sol";
contract PokeERC20 is Ownable, ERC20 {
    using SafeMath for uint256;

    IManager public manager;
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        
    }

    modifier onlyFarmOwners() {
        require(manager.farmOwners(_msgSender()), "caller is not the farmer");
        _;
    }

    modifier onlyEvolver() {
        require(manager.evolvers(_msgSender()), "caller is not the evolver");
        _;
    }

    function setManager(address _manager) external onlyOwner {
        manager = IManager(_manager);
    }
}