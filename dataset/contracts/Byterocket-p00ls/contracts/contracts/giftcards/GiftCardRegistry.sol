// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@amxx/hre/contracts/ENSReverseRegistration.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC4906.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "./implementations/ERC6551Account.sol";
import "./interfaces/IAccountProxy.sol";
import "./interfaces/IERC6551Registry.sol";

contract GiftCardRegistry is
    Ownable,
    ERC721,
    Multicall,
    IERC4906
{
    event MintFeeUpdate(uint256 newFee);
    event BeneficiaryUpdate(address newBeneficiary);

    IERC6551Registry public constant registry = IERC6551Registry(0x000000006551c19487814612e58FE06813775758);
    address          public constant proxy    = 0x55266d75D1a14E4572138116aF39863Ed6596E7F;
    address          public constant account  = 0x41C8f39463A868d3A88af00cd0fe7102F30E44eC;

    uint256 public  mintFee;
    address public  beneficiary;
    uint256 public  newTokenId;
    string  private _uriPrefix;

    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {
        beneficiary = msg.sender;
    }

    function mint(address to) public payable returns (address) {
        uint256 fee = mintFee; // cache value
        require(msg.value >= fee, "Invalid payment");

        // Mint token
        uint256 tokenId = newTokenId++;
        _safeMint(to, tokenId);

        address instance = deployAccountFor(tokenId);

        // Move funds: fee to the beneficiary, extra to the account
        Address.sendValue(payable(beneficiary), fee);
        if (msg.value > fee) {
            Address.sendValue(payable(instance), msg.value - fee);
        }

        return instance;
    }

    function getAccountForToken(uint256 tokenId) public view returns (address) {
        return registry.account(proxy, bytes32(0), block.chainid, address(this), tokenId);
    }

    function deployAccountFor(uint256 tokenId) public returns (address) {
        address tba = registry.account(proxy, 0, block.chainid, address(this), tokenId);
        if (tba.code.length == 0) {
            registry.createAccount(proxy, 0, block.chainid, address(this), tokenId);
            IAccountProxy(tba).initialize(account);
        }
        return tba;
    }

    function _baseURI() internal view override returns (string memory) {
        return _uriPrefix;
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner() {
        emit BatchMetadataUpdate(0, type(uint256).max);
        _uriPrefix = newBaseURI;
    }

    function setBeneficiary(address newBeneficiary) external onlyOwner() {
        emit BeneficiaryUpdate(newBeneficiary);
        beneficiary = newBeneficiary;
    }

    function setMintFee(uint256 newFee) external onlyOwner() {
        emit MintFeeUpdate(newFee);
        mintFee = newFee;
    }

    function setName(address ensregistry, string calldata ensname) external onlyOwner() {
        ENSReverseRegistration.setName(ensregistry, ensname);
    }
}
