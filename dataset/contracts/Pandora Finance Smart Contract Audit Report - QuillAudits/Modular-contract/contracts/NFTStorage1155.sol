// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "./Libraries/LibMeta1155.sol";
import "./Libraries/LibBid1155.sol";
import "./Libraries/LibCollection1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract NFTV1Storage1155 is Initializable{

    mapping(uint256 => LibMeta1155.TokenMeta) public _tokenMeta;
    mapping(uint256 => LibBid1155.BidOrder[]) public Bids;
    mapping(uint256 => LibCollection1155.CollectionMeta) public collections;
    mapping(address => uint256[]) public ownerToCollections;
    mapping(address => address) public collectionToOwner;
    Counters.Counter public collectionIdTracker;
    Counters.Counter internal _tokenIdTracker;
    address internal PNDC1155Address;
    address internal feeAddress;
}