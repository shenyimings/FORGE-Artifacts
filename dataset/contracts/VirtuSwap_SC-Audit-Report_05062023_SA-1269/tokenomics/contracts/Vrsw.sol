// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Vrsw is ERC20 {
    constructor(address _minter) ERC20("Virtuswap", "VRSW") {
        _mint(_minter, 1000000000 * 10 ** decimals());
    }
}
