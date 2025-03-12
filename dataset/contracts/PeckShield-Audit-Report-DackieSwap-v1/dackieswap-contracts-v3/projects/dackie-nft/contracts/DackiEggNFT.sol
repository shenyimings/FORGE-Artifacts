// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./utils/WhiteList.sol";


contract DackiEggNFT is ERC721, ERC721Enumerable, Ownable, Pausable, Whitelist {
    // Setup
    using Counters for Counters.Counter;
    Counters.Counter private _tokenSupply;

    // Private Properties
    string private _baseTokenURI;

    uint256 private _mintStartTime;

    // Events
    event Minted(address indexed _who, uint indexed _amount);

    // Treasury mint event
    event DevMinted(address indexed _to, uint256 indexed _amount);

    constructor(string memory _uri, uint256 mintStartTime) ERC721("DackieOnBase", "DACKIE") {
        _baseTokenURI = _uri;
        _mintStartTime = mintStartTime;
    }

    // mint
    function mint(uint256 _no)
    external
    payable
    whenNotPaused
    {
        require(block.timestamp >= _mintStartTime, "Minting not allowed yet");
        require(_isQualifiedWhitelist(msg.sender), "Not in whitelist");
        require(totalSupply() + _no <= 20000, "Exceeded collection limit");
        _mintBatch(msg.sender, _no);
    }

    // Treasury mint function
    function devMint(uint256 _no)
    external
    onlyOwner
    whenNotPaused
    {
        require(_no > 0, "Amount cannot be zero");
        require(totalSupply() + _no <= 20000, "Exceeded collection limit");
        _mintBatch(msg.sender, _no);
        emit DevMinted(msg.sender, _no);
    }

    // Support batch mint
    function _mintBatch(address _address, uint _no)
    internal
    {
        // Check max No. mint
        require(_no > 0, "Amount cannot be zero");

        // batch mint
        for (uint i = 0; i < _no; i++) {
            // mint token
            _tokenSupply.increment();
            _safeMint(_address, totalSupply());
        }

        // increase count nft per wallet
        emit Minted(msg.sender, _no);
    }

    function totalSupply() public view override(ERC721Enumerable)  returns (uint) {
        return _tokenSupply.current();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 _batchSize)
    internal
    override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, _batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Override to add .json extension
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, Strings.toString(tokenId), ".json")) : "";
    }

    // Withdraw contract balance to owner
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        // Using call to transfer funds
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");

        emit Withdrawn(owner(), balance);
    }

    function setMintStartTime(uint256 newStartTime) public onlyOwner {
        _mintStartTime = newStartTime;
    }

    function _isQualifiedWhitelist(address _user) internal view returns (bool) {
        return isWhitelisted(_user);
    }
}
