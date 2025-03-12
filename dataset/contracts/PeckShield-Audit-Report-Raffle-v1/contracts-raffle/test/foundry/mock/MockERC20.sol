// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20("LooksRare Token", "LOOKS") {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
