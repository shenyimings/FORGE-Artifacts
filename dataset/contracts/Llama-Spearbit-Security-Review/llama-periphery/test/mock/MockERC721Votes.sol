// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {EIP712} from "lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {ERC721Votes} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Votes.sol";

contract MockERC721Votes is ERC721, EIP712, ERC721Votes {
  constructor() ERC721("MyToken", "MTK") EIP712("MyToken", "1") {}

  function mint(address to, uint256 tokenId) public {
    _mint(to, tokenId);
  }

  function CLOCK_MODE() public pure override returns (string memory) {
    return "mode=timestamp";
  }

  function clock() public view override returns (uint48) {
    return uint48(block.timestamp);
  }

  // The following functions are overrides required by Solidity.

  function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Votes) returns (address) {
    delegate(to);
    return super._update(to, tokenId, auth);
  }

  function _increaseBalance(address account, uint128 amount) internal override(ERC721, ERC721Votes) {
    super._increaseBalance(account, amount);
  }
}
