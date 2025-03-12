// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC721/ERC721.sol";

/// @title MockERC721
/// @author info@lido.fi
/// @notice a mock NFT contract for tests
contract MockERC721 is ERC721 {
    constructor() ERC721("Mock ERC721", "M721") {
        _mint(msg.sender, 0);
    }
}
