// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./OwnableContract.sol";
import "./IBaseDoNFT.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract DoNFTFactory is OwnableContract{
    /**nftAddress => (gameKey => doNFT) */
    mapping(address => mapping(string => address)) virtualDoNftMap;
    mapping(address => mapping(string => address)) wrapDoNftMap;
    mapping(address => address) doNftToNft;
    address private virtualDoNftImplementation;
    address private wrapDoNftImplementation;

    constructor(){
        initOwnableContract();
    }

    function createVirtualDoNFT(address nftAddress,string calldata gameKey,string calldata name, string calldata symbol) external returns(address) {
        require(IERC165(nftAddress).supportsInterface(type(IERC721).interfaceId),"no 721");
        require(virtualDoNftMap[nftAddress][gameKey] == address(0),"already create");
        address clone = Clones.clone(virtualDoNftImplementation);
        IBaseDoNFT(clone).init(nftAddress,name, symbol);
        virtualDoNftMap[nftAddress][gameKey] = clone;
        doNftToNft[clone] = nftAddress;
        return clone;
    }

    function createWrapDoNFT(address nftAddress,string calldata gameKey,string calldata name, string calldata symbol) external returns(address) {
        require(IERC165(nftAddress).supportsInterface(type(IERC721).interfaceId),"no 721");
        require(wrapDoNftMap[nftAddress][gameKey] == address(0),"already create");
        address clone = Clones.clone(wrapDoNftImplementation);
        IBaseDoNFT(clone).init(nftAddress,name, symbol);
        wrapDoNftMap[nftAddress][gameKey] = clone;
        doNftToNft[clone] = nftAddress;
        return clone;
    }

    function setWrapDoNftImplementation(address imp) public onlyAdmin {
        wrapDoNftImplementation = imp;
    }

    function setVirtualDoNftImplementation(address imp) public onlyAdmin {
        virtualDoNftImplementation = imp;
    }

    function getWrapDoNftImplementation() public view returns(address){
        return wrapDoNftImplementation;
    }

    function getVirtualDoNftImplementation() public view returns(address) {
        return virtualDoNftImplementation;
    }

    function getWrapDoNftImplementation(address nftAddress,string calldata gameKey) public view returns(address){
        return wrapDoNftMap[nftAddress][gameKey];
    }

    function getVirtualDoNftImplementation(address nftAddress,string calldata gameKey) public view returns(address){
        return virtualDoNftMap[nftAddress][gameKey];
    }


}
