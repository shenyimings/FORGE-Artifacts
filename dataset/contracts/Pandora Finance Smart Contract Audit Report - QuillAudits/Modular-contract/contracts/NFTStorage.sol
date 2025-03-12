// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "./Libraries/LibMeta.sol";
import "./Libraries/LibBid.sol";
import "./Libraries/LibCollection.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract NFTV1Storage is Initializable{

    mapping(uint256 => LibMeta.TokenMeta) public _tokenMeta;
    mapping(uint256 => LibBid.BidOrder[]) public Bids;
    mapping(uint256 => LibCollection.CollectionMeta) public collections;
    mapping(address => uint256[]) public ownerToCollections;
    mapping(address => address) public collectionToOwner;
    Counters.Counter public collectionIdTracker;
    Counters.Counter internal _tokenIdTracker;
    address internal PNDCAddress;
    address internal feeAddress;
}

