// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Pausable.sol";

    error NonExistentTokenURI();

contract DOGAMI_MetaTxs is ERC2771Context, ERC721Enumerable, Ownable, Pausable {
    string public baseURI;
    string public v_contractURI;
    uint256 public currentTokenId = 0;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        string memory _contractURI,
        address _owner,
        address trustedForwarder
    )
    ERC721(_name, _symbol)
    ERC2771Context(trustedForwarder)
    Ownable(_owner)
    {
        baseURI = _baseURI;
        v_contractURI = _contractURI;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721, IERC721) whenNotPaused {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override(ERC721, IERC721) whenNotPaused {
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    function mintTo(address recipient) public onlyOwner returns (uint256) {
        uint256 newTokenId = ++currentTokenId;
        _safeMint(recipient, newTokenId);
        return newTokenId;
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    function setContractURI(string memory _contractURI) public onlyOwner {
        v_contractURI = _contractURI;
    }

    function contractURI() public view returns (string memory) {
        return v_contractURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory){
        if (ownerOf(tokenId) == address(0)) {revert NonExistentTokenURI();}
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, Strings.toString(tokenId))) : "";
    }

    function _contextSuffixLength() internal view virtual override(Context, ERC2771Context) returns (uint256) {
        return 20;
    }

}
