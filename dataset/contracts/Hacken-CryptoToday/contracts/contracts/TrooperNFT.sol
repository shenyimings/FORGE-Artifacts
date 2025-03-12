//SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Signature.sol";

contract TrooperNFT is ERC1155, Ownable, Signature {
  mapping(address => bool) public claimed;

  constructor() ERC1155("https://ipfs.io/hash/{id}.json") {}

  function claimTrooper(bytes calldata signature) external {
    require(verifyNFT(owner(), msg.sender, signature), "Invalid signature");
    require(!claimed[msg.sender], "Already claimed");

    claimed[msg.sender] = true;

    _mint(msg.sender, 0, 1, ""); // The trooper nft will be under id 0
  }

  function airdrop(address receiver, uint256 id) external onlyOwner {
    _mint(receiver, id, 1, "");
  }
}
