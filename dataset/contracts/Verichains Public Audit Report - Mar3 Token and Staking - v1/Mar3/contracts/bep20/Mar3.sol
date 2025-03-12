// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Mar3 is ERC20 {
    constructor() ERC20("MAR3 TOKEN", "MAR3") {
        _mint(0xE9110d067AD7Bcf4d758DcBFfFd664F197DAc7d2, 2000000000 ether);
    }
}
