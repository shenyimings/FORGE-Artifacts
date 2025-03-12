// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../tokens/MintableBaseToken.sol";

contract ALP is MintableBaseToken {
    constructor() public MintableBaseToken("AVT LP", "ALP", 0) {
    }

    function id() external pure returns (string memory _name) {
        return "ALP";
    }
}
