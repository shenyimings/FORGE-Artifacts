// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


import "@openzeppelin/contracts/access/Ownable.sol";
import "./MCSCollection.sol";

contract CollectionFactory is Ownable {
    address public defaultCollectionAddress;
    mapping(address => address[]) userToCollections;

    event CreateCollection(address collectionOwner, address collectionAddress);

    constructor(address defaultCollection) {
        defaultCollectionAddress = defaultCollection;
        emit CreateCollection(MCSCollection(defaultCollection).owner(), defaultCollection);
    }

    function createCollection(string memory collectionName, string memory contractURI) public returns (address) {
        // user will be owner AND admin, factory will be admin
        MCSCollection newCollection = new MCSCollection(collectionName, contractURI); // this contract will be owner and admin
        newCollection.setAdmin(msg.sender, true); // set the user as another admin
        newCollection.transferOwnership(msg.sender); // then set user as admin

        userToCollections[msg.sender].push(address(newCollection));

        emit CreateCollection(msg.sender, address(newCollection));

        return address(newCollection);
    }

    //TODO: mint functions
    function mint(address collection, address recipient, uint amount, string memory uri) public {
        require(collection == defaultCollectionAddress || MCSCollection(collection).isAdmin(msg.sender), 'caller is not admin');

        MCSCollection(collection).mint(recipient, amount, uri, "");
    }

    function mintToNewCollection(string memory collectionName, string memory contractURI, address recipient, uint amount, string memory uri) public {
        address collection = createCollection(collectionName, contractURI);
        mint(collection, recipient, amount, uri);
    }

    // getter functions
    function getCollections(address user) public view returns (address[] memory) {
        return userToCollections[user];
    }

    function changeDefaultCollection(address collectionAddress) public onlyOwner {
        defaultCollectionAddress = collectionAddress;
    }
}