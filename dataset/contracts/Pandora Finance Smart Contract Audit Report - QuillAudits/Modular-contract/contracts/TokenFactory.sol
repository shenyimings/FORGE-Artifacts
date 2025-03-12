// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "./Auction/Bid.sol";
import "./Libraries/LibERC721.sol";
import "./Libraries/LibCollection.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TokenFactory is UUPSUpgradeable, NFTBid {

    using Counters for Counters.Counter;

    event ERC721Deployed(address indexed _from, address _tokenAddress);

    function initialize(address _address, address _feeAddress) initializer public {
        require(_address != address(0));
        require(_feeAddress != address(0));
        PNDCAddress = _address;
        __UUPSUpgradeable_init();
        feeAddress = _feeAddress;
        OwnableUpgradeable.__Ownable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        ERC721HolderUpgradeable.__ERC721Holder_init();
    }

    function deployERC721(
        string memory name, 
        string memory symbol, 
        string memory description, 
        LibShare.Share[] memory royalties) 
        external 
        nonReentrant{

        collectionIdTracker.increment();

        address collectionAddress = LibERC721.deployERC721(name, symbol, royalties);

        LibCollection.CollectionMeta memory meta = LibCollection.CollectionMeta(
            name,
            symbol,
            collectionAddress,
            msg.sender,
            description
        );

        collections[collectionIdTracker.current()] = meta;
        

        ownerToCollections[msg.sender].push(collectionIdTracker.current());
        collectionToOwner[collectionAddress] = msg.sender;

        emit ERC721Deployed(msg.sender, collectionAddress);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

}
