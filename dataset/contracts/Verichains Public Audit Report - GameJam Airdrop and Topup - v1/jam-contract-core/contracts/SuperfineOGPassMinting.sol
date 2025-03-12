/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./tokens/ERC721/SuperfineOGPass.sol";
import "./tokens/ERC721/SuperfineSuperHappyFrens.sol";

contract SuperfineOGPassMinting is Ownable {
    SuperfineOGPass public sfOGPassContract;
    SuperfineSuperHappyFrens public sfSuperHappyFrensContract;
    uint256 public mintFee;
    uint256 public jamSuperHappyFrensPrice;
    uint256 public jamSuperHappyFrensDiscountPrice;
    uint256 public mintLimit;
    uint256 public purchaseLimit;

    constructor(
        address jamOGPass,
        address jamSuperHappyFrens,
        uint256 mintFee_,
        uint256 jamSuperHappyFrensPrice_,
        uint256 jamSuperHappyFrensDiscountPrice_,
        uint256 mintLimit_,
        uint256 purchaseLimit_
    ) {
        require(
            jamSuperHappyFrensPrice_ > jamSuperHappyFrensDiscountPrice_,
            "SuperfineOGPassMinting: normal price must be greater than discount price"
        );
        require(
            mintLimit_ > 0,
            "SuperfineOGPassMinting: mint limit must be greater than 0"
        );
        require(
            purchaseLimit_ > 0,
            "SuperfineOGPassMinting: purchase limit must be greater than 0"
        );
        sfOGPassContract = SuperfineOGPass(jamOGPass);
        sfSuperHappyFrensContract = SuperfineSuperHappyFrens(
            jamSuperHappyFrens
        );
        mintFee = mintFee_;
        jamSuperHappyFrensPrice = jamSuperHappyFrensPrice_;
        jamSuperHappyFrensDiscountPrice = jamSuperHappyFrensDiscountPrice_;
        mintLimit = mintLimit_;
        purchaseLimit = purchaseLimit_;
    }

    function setMintFee(uint256 newFee) external onlyOwner {
        mintFee = newFee;
    }

    function setSuperHappyFrensPrice(uint256 newPrice) external onlyOwner {
        require(
            newPrice > jamSuperHappyFrensDiscountPrice,
            "SuperfineOGPassMinting: normal price must be greater than discount price"
        );
        jamSuperHappyFrensPrice = newPrice;
    }

    function setSuperHappyFrensDiscountPrice(
        uint256 newPrice
    ) external onlyOwner {
        require(
            newPrice < jamSuperHappyFrensPrice,
            "SuperfineOGPassMinting: normal price must be greater than discount price"
        );
        jamSuperHappyFrensDiscountPrice = newPrice;
    }

    function setMintLimit(uint256 newLimit) external onlyOwner {
        require(
            newLimit > 0,
            "SuperfineOGPassMinting: mint limit must be greater than 0"
        );
        mintLimit = newLimit;
    }

    function setPurchaseLimit(uint256 newLimit) external onlyOwner {
        require(
            newLimit > 0,
            "SuperfineOGPassMinting: purchase limit must be greater than 0"
        );
        purchaseLimit = newLimit;
    }

    function mintOGPass(uint256 quantity) external payable {
        require(
            quantity > 0,
            "SuperfineOGPassMinting: cannot mint zero OGPass"
        );
        require(
            quantity <= mintLimit,
            "SuperfineOGPassMinting: quantity exceeds limit"
        );
        require(
            msg.value >= mintFee * quantity,
            "SuperfineOGPassMinting: not enough fee to mint"
        );
        for (uint256 i = 0; i < quantity; i++)
            sfOGPassContract.mintTo(msg.sender);
        (bool success, ) = payable(msg.sender).call{
            value: msg.value - mintFee * quantity
        }("");
        require(success, "SuperfineOGPassMinting: return fee failed");
    }

    function purchaseSuperHappyFrens(uint256 quantity) external payable {
        require(
            quantity > 0,
            "SuperfineOGPassMinting: cannot purchase zero NFT"
        );
        require(
            quantity <= purchaseLimit,
            "SuperfineOGPassMinting: quantity exceeds limit"
        );
        uint256 price = jamSuperHappyFrensPrice;
        if (sfOGPassContract.balanceOf(msg.sender) > 0)
            price = jamSuperHappyFrensDiscountPrice;
        require(
            msg.value >= price * quantity,
            "SuperfineOGPassMinting: not enough money"
        );
        for (uint256 i = 0; i < quantity; i++)
            sfSuperHappyFrensContract.mintTo(msg.sender);
        (bool success, ) = payable(msg.sender).call{
            value: msg.value - price * quantity
        }("");
        require(success, "SuperfineOGPassMinting: return money failed");
    }

    function reclaimEther(address payable recipient) external onlyOwner {
        require(
            recipient != address(0),
            "SuperfineOGPassMinting: cannot reclaim to zero address"
        );
        (bool success, ) = recipient.call{value: address(this).balance}("");
        require(success, "SuperfineOGPassMinting: reclaim failed");
    }
}
