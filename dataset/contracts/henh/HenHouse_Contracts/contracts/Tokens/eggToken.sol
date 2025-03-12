// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.7;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import "@openzeppelin/contracts/access/Ownable.sol";

contract EggToken is ERC20, Ownable {

    address public henHouseAddress;
    address public stakingAddress;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }

    modifier onlyHenHouse() {
        require(henHouseAddress == _msgSender(), "caller is not the farmer");
        _;
    }

    function setHenHouseAddress(address _hh) public onlyOwner {
        henHouseAddress = _hh;
    }

    function mintTokens(address _depositAddress, uint256 _amount) public onlyHenHouse {
        _mint(_depositAddress, _amount);
    }

    function burn(uint256 amount) public onlyHenHouse {
        _burn(_msgSender(), amount);
    }    
}