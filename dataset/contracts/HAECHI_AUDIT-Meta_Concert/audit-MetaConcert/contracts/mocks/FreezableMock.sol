// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "../library/Freezable.sol";

contract FreezableMock is Freezable {

    constructor() Freezable() {}

    function whenNotFrozenMock(address target) whenNotFrozen(target) public {

    }
}
