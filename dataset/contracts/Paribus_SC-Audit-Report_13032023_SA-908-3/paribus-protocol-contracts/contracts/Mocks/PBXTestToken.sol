// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PBXTestTokenMintable is Ownable, ERC20Burnable {
    string private constant _NAME = "Paribus Test";
    string private constant _SYMBOL = "PBX";

    constructor(uint256 initialSupply) public ERC20(_NAME, _SYMBOL) {
        _mint(owner(), initialSupply);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        ERC20._mint(_to, _amount);
        return true;
    }
}
