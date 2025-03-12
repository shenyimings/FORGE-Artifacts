// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../tokens/MintableBaseToken.sol";

contract AVT is MintableBaseToken {
    constructor() public MintableBaseToken("AVT", "AVT", 0) {
    }

    function id() external pure returns (string memory _name) {
        return "AVT";
    }
}
