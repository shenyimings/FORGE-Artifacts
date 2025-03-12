// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract MahaToken is ERC20PresetMinterPauser {
    address public upgradedAddress;
    bool public deprecated;
    string public contactInformation = "contact@mahadao.com";
    string public reason;
    string public link = "https://mahadao.com";
    string public url = "https://mahadao.com";
    string public website = "https://mahadao.io";

    constructor() public ERC20PresetMinterPauser("MahaDAO", "MAHA") {}
}