// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title MockToken
 * @dev An ERC20 standard contract that mints Metatime Token and distributes it to each pool based on Metatime Tokenomics.
 */
contract MockToken is ERC20, ERC20Burnable, Ownable2Step {
    /**
     * @dev Initializes the MTC contract with initial pools and total supply.
     * @param _totalSupply The total supply of the MTC token.
     */
    constructor(uint256 _totalSupply) ERC20("Metatime", "MTC") {
        _mint(_msgSender(), _totalSupply);
    }
}
