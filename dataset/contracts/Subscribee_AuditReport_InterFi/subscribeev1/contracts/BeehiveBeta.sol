// SPDX-License-Identifier: Business Source License 1.1
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./SubscribeeBeta.sol";

contract BeehiveBeta is Ownable {

  mapping(string => address) public slugs;
  mapping(address => bool) public verifiedSubscribeeContract;

  uint256 public adminFund;
  uint256 public slugFee;

  event NewContract(
    address contractAddress,
    string slug,
    uint256 time
  );

  event SlugChanged(
    address contractAddress,
    string oldSlug,
    string newSlug
  );

  event SlugFeesCollected(
    address toAddress,
    uint256 amount,
    uint256 time
  );

  constructor(uint256 slugfee){
    slugFee = slugfee;
  }

  function setSlugFee(uint256 newslugFee) external onlyOwner{
    slugFee = newslugFee;
  }

  function collectSlugFees(address toAddress) external onlyOwner{
    payable(toAddress).transfer(adminFund);
    emit SlugFeesCollected(toAddress, adminFund, block.timestamp);
    adminFund = 0;
  }


  function changeSlug(string memory oldslug, string memory newslug) external payable{
    SubscribeeBeta subscribeeContract = SubscribeeBeta(slugs[oldslug]);
    require(subscribeeContract.owner() == msg.sender, "Only the Owner of the contract can do this");
    require(slugs[newslug] == address(0), "Slug has been taken");
    require(msg.value == slugFee || msg.sender == owner(), "Please pay the appropiate amount...");

    adminFund += msg.value;
    slugs[newslug] = slugs[oldslug];
    emit SlugChanged(slugs[oldslug], oldslug, newslug);
    delete slugs[oldslug];
  }


  function deploySubscribeeContract(address operatorAddress, string memory title, string memory slug, string memory image) external{
    require(slugs[slug] == address(0), "Slug has been taken");

    SubscribeeBeta newContract = new SubscribeeBeta(operatorAddress, title, image);
    newContract.transferOwnership(msg.sender);

    address contractAddress = address(newContract);
    slugs[slug] = contractAddress;
    verifiedSubscribeeContract[contractAddress] = true;

    emit NewContract(contractAddress, slug, block.timestamp);
  }



}
