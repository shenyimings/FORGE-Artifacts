// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MonNFT is ERC721URIStorage, Ownable{
    uint256 public MULTIPLIER = 1000;

    //Mapping tokenId to fee copyright
    uint256 private _maxFeeCopyright;
    //Mapping tokenId to author
    mapping(uint256 => address) internal _authors;
    //Mapping tokenId to fee copyright
    mapping(uint256 => uint256) internal _tokenFeeCopyrights;

    constructor() ERC721("MON", "MONNFTS"){
        _maxFeeCopyright = 5000; // 5%
    }

    function mintToken(uint tokenId, string memory metadataURI) public returns(bool){
        _safeMint(_msgSender(), tokenId);
        _setTokenURI(tokenId, metadataURI);
        _authors[tokenId] = _msgSender();
        _tokenFeeCopyrights[tokenId] = 0;
        return true;
    }

    function getTokenAuthor(uint tokenId) public view returns(address){
        return _authors[tokenId];
    }

    function setFeeCopyright(uint tokenId, uint fee) public returns(uint){
        require(_authors[tokenId] == _msgSender(), "Forbidden to set fee copyright");
        require(fee <= _maxFeeCopyright, "Fee must be smaller max fee!");

        _tokenFeeCopyrights[tokenId] = fee;

        emit SetFeeCoppyRight(tokenId, fee);

        return fee;
    }

    function getFeeCopyright(uint tokenId) public view returns(uint){
        return _tokenFeeCopyrights[tokenId];
    }

    function setMaxFreeCopyright(uint maxFee) public onlyOwner{
        _maxFeeCopyright = maxFee;
    }

    function getMaxFreeCopyright() public view returns(uint){
        return _maxFeeCopyright;
    }

    event SetFeeCoppyRight(uint256 indexed tokenId, uint256 feePercent);
}