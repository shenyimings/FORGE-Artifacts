// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "../marketplace/NftMarketplace.sol";

contract NftMarketplaceV2 is NftMarketplace {
    string private constant testVariable = "hello";

    function getVariable() public pure returns (string memory) {
        return testVariable;
    }

    function testFunction() public pure returns (uint256) {
        return 12345;
    }
}
