// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract DackieNFT is ERC721, ERC721Enumerable, Ownable, Pausable {
    // Setup
    using Counters for Counters.Counter;
    Counters.Counter private _tokenSupply;

    // Private Properties
    string private _baseTokenURI;

    uint256 private _mintStartTime;

    // Treasury mint limit
    uint256 private constant TREASURY_MINT_LIMIT = 1000;

    // Treasury minted count
    uint256 private _treasuryMintedCount;

    // Events
    event Minted(address indexed _who, uint indexed _amount);

    // Treasury mint event
    event TreasuryMinted(address indexed _to, uint256 indexed _amount);

    uint256 private constant PRICE_PER_NFT = 0.00777 ether;

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
        require(totalSupply() + _no <= 20000, "Exceeded collection limit");
        require(msg.value == _no * PRICE_PER_NFT, "Incorrect ether value");
        _mintBatch(msg.sender, _no);
    }

    // Treasury mint function
    function treasuryMint(uint256 _no)
    external
    onlyOwner
    whenNotPaused
    {
        require(_treasuryMintedCount + _no <= TREASURY_MINT_LIMIT, "Exceeded treasury mint limit");

        _mintBatch(msg.sender, _no);

        // Update treasury minted count
        _treasuryMintedCount += _no;
        emit TreasuryMinted(msg.sender, _no);
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
        payable(owner()).transfer(balance);
    }

    function setMintStartTime(uint256 newStartTime) public onlyOwner {
        _mintStartTime = newStartTime;
    }
}
