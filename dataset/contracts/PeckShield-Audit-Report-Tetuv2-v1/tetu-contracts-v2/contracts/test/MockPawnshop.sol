// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../interfaces/IERC721.sol";
import "../interfaces/IVeTetu.sol";
import "../interfaces/IERC721Receiver.sol";

contract MockPawnshop is IERC721Receiver{

  function transfer(address nft, address from, address to, uint id) external {
    IERC721(nft).safeTransferFrom(from, to, id);
  }

  function transferAndGetBalance(address nft, address from, address to, uint id) external returns (uint){
    IERC721(nft).safeTransferFrom(from, to, id);
    return IVeTetu(nft).balanceOfNFT(id);
  }

  function doubleTransfer(address nft, address from, address to, uint id) external {
    IERC721(nft).safeTransferFrom(from, to, id);
    IERC721(nft).safeTransferFrom(to, from, id);
    IERC721(nft).safeTransferFrom(from, to, id);
  }

  function veFlashTransfer(address ve, uint tokenId) external {
    IERC721(ve).safeTransferFrom(msg.sender, address(this), tokenId);
    require(IVeTetu(ve).balanceOfNFT(tokenId) == 0, "not zero balance");
    IVeTetu(ve).totalSupplyAt(block.number);
    IVeTetu(ve).checkpoint();
    IVeTetu(ve).checkpoint();
    IVeTetu(ve).checkpoint();
    IVeTetu(ve).checkpoint();
    IVeTetu(ve).totalSupplyAt(block.number);
    IVeTetu(ve).totalSupplyAt(block.number - 1);
    IERC721(ve).safeTransferFrom(address(this), msg.sender, tokenId);
  }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes memory
  ) public virtual override returns (bytes4) {
    return this.onERC721Received.selector;
  }

}
