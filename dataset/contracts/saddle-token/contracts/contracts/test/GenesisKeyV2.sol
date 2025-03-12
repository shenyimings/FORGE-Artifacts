// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "../genesisKey/GenesisKey.sol";

contract GenesisKeyV2 is GenesisKey {
    string private constant testVariable = "hello";

    function getVariable() public pure returns (string memory) {
        return testVariable;
    }

    function testFunction() public pure returns (uint256) {
        return 12345;
    }
}
