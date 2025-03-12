//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./DarkMatter.sol";
import "./GenerationManager.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Market is OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {

    event StackSale(
        address seller,
        address buyer,
        uint256 generationId,
        uint256 tokenId,
        uint256 price
    );

    event StackListing(
        address seller,
        uint256 generationId,
        uint256 tokenId,
        uint256 price
    );

    event DarkMatterSale(
        address seller,
        address buyer,
        uint256 tokenId,
        uint256 price
    );

    event DarkMatterListing(
        address seller,
        uint256 tokenId,
        uint256 price
    );

    DarkMatter private darkMatter;
    GenerationManager private generations;

    address private daoAddress;
    address private royaltyAddress;

    uint256 private constant HUNDRED_PERCENT = 10000;

    uint256 public daoFee; 
    uint256 public royaltyFee; 

    struct StackLot {
        uint256 price;
        uint256 generationId;
        uint256 tokenId;
        address seller;
    }

    struct DarkMatterLot {
        uint256 price;
        uint256 tokenId;
        address seller;
    }

    mapping(uint256 => mapping(uint256 => StackLot)) public stackToLot;
    mapping(uint256 => DarkMatterLot) public darkMatterToLot;

    function initialize(
        GenerationManager _generations,
        DarkMatter _darkMatter,
        address _daoAddress,
        address _royaltyAddress,
        uint256 _daoFee,
        uint256 _royaltyFee
    ) initializer public {
        generations = _generations;
        darkMatter = _darkMatter;
        daoAddress = _daoAddress;
        royaltyAddress = _royaltyAddress;
        daoFee = _daoFee;
        royaltyFee = _royaltyFee;
        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /*
     * @title Set dao fee taken of each sell.
     * @param Fee basis points.
     * @dev Could only be called by the contract owner.
     */
    function setDaoFee(uint256 _percent) public onlyOwner {
        require(_percent <= HUNDRED_PERCENT, "invalid fee basis points");
        daoFee = _percent;
    }

    /*
     * @title Set fee percent to send to royalty distribution contract taken of each sell.
     * @param Fee basis points.
     * @dev Could only be called by the contract owner.
     */
    function setRoyaltyFee(uint256 _percent) public onlyOwner {
        require(_percent <= HUNDRED_PERCENT, "invalid fee basis points");
        royaltyFee = _percent;
    }

    /*
     * @title List DarkMatterNFT for selling
     * @param Token id
     * @param Price
     */
    function listDarkMatterNFT(
        uint256 tokenId,
        uint256 price 
    ) public nonReentrant {
        DarkMatterLot storage lot = darkMatterToLot[tokenId];
        require(lot.seller == address(0), "Already listed");
        require(darkMatter.ownerOf(tokenId) == msg.sender, "Not token owner");

        lot.price = price;
        lot.seller = msg.sender;
        lot.tokenId = tokenId;

        emit DarkMatterListing(msg.sender, tokenId, price);
    }

    /*
     * @title List StackNFT for selling
     * @param StackNFT generation id
     * @param Token id
     * @param Price
     */
    function listStackNFT(
        uint256 generationId,
        uint256 tokenId,
        uint256 price
    ) public nonReentrant {
        require(generationId < generations.count(), "Generation doesn't exist");
        require(generations.get(generationId).ownerOf(tokenId) == msg.sender, "Not token owner");

        StackLot storage lot = stackToLot[generationId][tokenId];
        require(lot.seller == address(0), "Already listed");

        lot.price = price;
        lot.seller = msg.sender;
        lot.generationId = generationId;
        lot.tokenId = tokenId;

        emit StackListing(msg.sender, generationId, tokenId, price);
    }

    /*
     * @title Delist DarkMatterNFT from selling
     * @param Token id
     */
    function deListDarkMatterNFT(
        uint256 tokenId
    ) public nonReentrant {
        bool isApproved = darkMatter
            .isApprovedForAll(darkMatterToLot[tokenId].seller, address(this));
        require(darkMatterToLot[tokenId].seller == msg.sender || !isApproved, 'Not an owner');
        require(darkMatterToLot[tokenId].seller != address(0), 'Not a listing');
        delete darkMatterToLot[tokenId];
    }

    /*
     * @title Delist StackNFT from selling
     * @param StackNFT generation id
     * @param Token id
     */
    function deListStackNFT(
        uint256 generationId,
        uint256 tokenId
    ) public nonReentrant {
        bool isApproved = generations.get(generationId)
            .isApprovedForAll(stackToLot[generationId][tokenId].seller, address(this));
        require(stackToLot[generationId][tokenId].seller == msg.sender || !isApproved, 'Not an owner');
        require(stackToLot[generationId][tokenId].seller != address(0), 'Not a listing');
        delete stackToLot[generationId][tokenId];
    }

    /*
     * @title Buy listed StackNFT
     * @param StackNFT generation id
     * @param Token id
     * @dev Market contract must be whitelisted in StackNFT contract to transfer tokens.
     */
    function buyStack(
        uint256 generationId,
        uint256 tokenId
    ) public payable nonReentrant {
        require(generationId < generations.count(), "Generation doesn't exist");

        StackLot storage lot = stackToLot[generationId][tokenId];
        require(lot.seller != address(0), "Not listed");
        require(lot.price <= msg.value, "Not enough MATIC");

        uint256 daoPart = lot.price * daoFee / HUNDRED_PERCENT;
        uint256 royaltyPart = lot.price * royaltyFee / HUNDRED_PERCENT;
        uint256 sellerPart = lot.price - daoPart - royaltyPart;

        daoAddress.call{value: daoPart}("");
        royaltyAddress.call{value: royaltyPart}("");
        payable(lot.seller).call{value: sellerPart}("");

        generations.get(generationId).transferFrom(lot.seller, msg.sender, tokenId);

        emit StackSale(lot.seller, msg.sender, generationId, tokenId, lot.price);

        delete stackToLot[generationId][tokenId];
    }

    /*
     * @title Buy listed DarkMatter NFT
     * @param Token id
     * @dev Market contract must be whitelisted in StackNFT contract to transfer tokens.
     */
    function buyDarkMatter(
        uint256 tokenId
    ) public payable nonReentrant {
        DarkMatterLot storage lot = darkMatterToLot[tokenId];
        require(lot.seller != address(0), "Not listed");
        require(lot.price <= msg.value, "Not enough MATIC");

        uint256 daoPart = lot.price * daoFee / HUNDRED_PERCENT;
        uint256 royaltyPart = lot.price * royaltyFee / HUNDRED_PERCENT;
        uint256 sellerPart = lot.price - daoPart - royaltyPart;

        daoAddress.call{value: daoPart}("");
        royaltyAddress.call{value: royaltyPart}("");
        payable(lot.seller).call{value: sellerPart}("");

        darkMatter.transferFrom(lot.seller, msg.sender, tokenId);

        emit DarkMatterSale(lot.seller, msg.sender, tokenId, lot.price);

        delete darkMatterToLot[tokenId];
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner{}
}
