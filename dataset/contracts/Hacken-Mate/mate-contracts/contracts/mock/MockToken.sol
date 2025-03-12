// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract MockToken is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("Mate", "MATE") {
        _mint(msg.sender, 1_000_000e18);
    }

    function faucet() external {
        _mint(msg.sender, 1_000e18);
    }
}
