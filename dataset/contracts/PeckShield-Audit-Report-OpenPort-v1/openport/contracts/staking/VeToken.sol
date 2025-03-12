// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "../erc20/ERC20.sol";
import "../utils/Owned.sol";

contract VEToken is ERC20, Owned {

    event Mint(address sender, address account, uint amount);
    event Burn(address sender, address account, uint amount);

    constructor(string memory _symbol) ERC20(_symbol, _symbol) Owned(msg.sender) public {
    }

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
        emit Mint(msg.sender, account, amount);
    }

    function burn(address account, uint256 value) public onlyOwner {
        _burn(account, value);
        emit Burn(msg.sender, account, value);
    }
}

contract VETokenFactory {
    function genVEToken(string memory _symbol) public returns(address) {
        return address(new VEToken(_symbol));
    }
}