// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MNT is ERC20 {
    constructor(address treasury) ERC20("MNT", "MNT") {
        require(treasury != address(0), "ZERO");
        uint supply = 500_000_000e18;
        _mint(treasury, supply);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
