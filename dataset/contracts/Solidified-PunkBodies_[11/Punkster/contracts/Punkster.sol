// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

import "./PairedNFT.sol";

contract Punkster is PairedNFT, IERC721Receiver {
    using SafeMath for uint256;

    address immutable head;
    address immutable body;

    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    constructor(address _head, address _body, string memory _baseURI)  PairedNFT(_head, _body, "Punksters", "PNK", _baseURI) {
        head = _head;
        body = _body;
    }

    function onERC721Received(address, address from, uint256 tokenId, bytes calldata data) external override virtual returns (bytes4) {
        IERC721 otherToken;

        uint256 tokenId0;
        uint256 tokenId1;

        (uint256 otherTokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) = abi.decode(data, (uint256, uint256, uint8, bytes32, bytes32));

        if (IERC721(msg.sender) == token0) {
            otherToken = token1;
            tokenId0 = tokenId;
            tokenId1 = otherTokenId;
        } else if (IERC721(msg.sender) == token1) {
            otherToken = token0;
            tokenId1 = tokenId;
            tokenId0 = otherTokenId;
        } else {
            revert("PairedNFT: Unsupported token.");
        }

        require(IERC721(msg.sender).ownerOf(tokenId) == address(this), "PairedNFT: Token not transfered.");

        IERC721Permit(address(otherToken)).permit(from, address(this), otherTokenId, deadline, v, r, s);
        otherToken.transferFrom(from, address(this), otherTokenId);

        _mint(from, tokenId0, tokenId1);
        return _ERC721_RECEIVED;
    }
}
