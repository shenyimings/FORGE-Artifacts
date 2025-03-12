// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract WrapCoinMintable is ERC20PresetMinterPauser {
    constructor(string memory name_, string memory symbol_)
        ERC20PresetMinterPauser(name_, symbol_)
    {}
}
