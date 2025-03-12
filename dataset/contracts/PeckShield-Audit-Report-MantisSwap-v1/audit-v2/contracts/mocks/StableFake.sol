//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract StableFake is ERC20PresetMinterPauser {

    uint8 private numDecimals;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 _numDecimals
    ) ERC20PresetMinterPauser(name, symbol) {
        mint(msg.sender, initialSupply);
        numDecimals = _numDecimals;
    }

    function decimals() public view virtual override returns (uint8) {
        return numDecimals;
    }

    function mint(uint amount) public {
        _mint(msg.sender, amount);
    }
}
