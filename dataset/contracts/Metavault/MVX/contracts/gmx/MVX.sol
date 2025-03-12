// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../tokens/MintableBaseToken.sol";

contract MVX is MintableBaseToken {
    constructor() public MintableBaseToken("Metavault Trade", "MVX", 0) {}

    function id() external pure returns (string memory _name) {
        return "MVX";
    }
}
