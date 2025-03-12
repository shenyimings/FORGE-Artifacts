// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "../TokenERC721.sol";
import "./LibShare.sol";

library LibERC721 {
    function deployERC721(string memory name, string memory symbol, LibShare.Share[] memory royalties)
        external
        returns (address)
    {
        TokenERC721 token = new TokenERC721(name, symbol);
        token.setRoyaltiesForCollection(royalties);
        token.transferOwnership(msg.sender);
        return address(token);
    }
}
