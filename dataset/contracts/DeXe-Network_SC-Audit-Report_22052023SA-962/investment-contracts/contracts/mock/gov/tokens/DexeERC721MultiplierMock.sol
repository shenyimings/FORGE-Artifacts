// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../gov/ERC721/multipliers/DexeERC721Multiplier.sol";

contract DexeERC721MultiplierMock is DexeERC721Multiplier {
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }
}
