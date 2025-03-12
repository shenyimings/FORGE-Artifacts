// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../BEP20YAY.sol";

contract ERC20BurnableMock is BEP20YAY {
    constructor() public BEP20YAY() {}
}
