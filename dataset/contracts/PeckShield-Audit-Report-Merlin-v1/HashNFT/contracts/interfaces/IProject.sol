// contracts/Project.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct NftInfo {
    address nft;
    uint256 tokenId;
}

struct SettleInfo {
    address splitter;
    uint256 depositClaimed;
    uint256 punish;
}

interface IProject {

    function bind(address nft, uint256 tokenId, uint256 amount, string calldata _note) external;
    
    function paymentToken() external view returns(address);

    function getPrice() external view returns(uint256);

}
