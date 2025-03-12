// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Cereal is ERC20 {
    constructor() ERC20("Cereal", "CRL") {
        _mint(msg.sender, 500000000 * (10**18));
    }
}
