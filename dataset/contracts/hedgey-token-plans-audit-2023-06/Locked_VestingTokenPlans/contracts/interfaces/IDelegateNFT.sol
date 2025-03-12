// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IDelegateNFT {
 
 function delegateTokens(address delegate, uint256[] memory tokenIds) external;

 function delegateAllNFTs(address delegate) external;

  function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

  function tokenByIndex(uint256 index) external view returns (uint256);

  function balanceOfDelegate(address delegate) external view returns (uint256);

  function delegatedTo(uint256 tokenId) external view returns (address);

  function tokenOfDelegateByIndex(address delegate, uint256 index) external view returns (uint256);

  function lockedBalances(address holder, address token) external view returns (uint256);

  function delegatedBalances(address delegate, address token) external view returns (uint256);
}