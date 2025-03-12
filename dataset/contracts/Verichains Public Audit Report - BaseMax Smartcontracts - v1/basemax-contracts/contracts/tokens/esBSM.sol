// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "../tokens/MintableBaseToken.sol";

contract esBSM is MintableBaseToken {
    constructor() MintableBaseToken("Escrowed BSM", "esBSM", 0) {}

    function id() external pure returns (string memory _name) {
        return "esBSM";
    }
}
