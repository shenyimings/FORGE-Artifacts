// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

/**
 * @dev Create a Pulsar ERC20 standard token
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20 {
    uint256 public constant MAX_SUPPLY = uint248(1e9 ether);

    constructor() ERC20("ERC20 Token", "ERCT") {
        _mint(msg.sender, MAX_SUPPLY);
    }
}
