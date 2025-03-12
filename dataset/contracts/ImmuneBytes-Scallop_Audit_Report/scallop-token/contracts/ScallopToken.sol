// contracts/MyNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract ScallopToken is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("ScallopX", "SCLP") {}
}
