// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "../tokens/MintableBaseToken.sol";

contract esNAV is MintableBaseToken {
    constructor() MintableBaseToken("Escrowed NAV", "esNAV", 0) {}

    function id() external pure returns (string memory _name) {
        return "esNAV";
    }
}
