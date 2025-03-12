// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../../contracts/interfaces/IFrensStorage.sol";


interface IMaliciousProxyInterface {
  function setBool(bytes32 _key, bool _value) external;
  
}

contract BoolGetter {
  IFrensStorage frensStorage;
  constructor(IFrensStorage frensStorage_) {}
  function getBoolFromStorage(bytes32 key) public view returns(bool) {
    return frensStorage.getBool(key);
  }
}

contract NftReceiver is IERC721Receiver {

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public pure returns (bytes4){
        //all this stupid shit to make the error go away
        if(operator == from)return IERC721Receiver.onERC721Received.selector;
        if(tokenId == 1) return IERC721Receiver.onERC721Received.selector;
        if(keccak256(data) == keccak256("0")) return IERC721Receiver.onERC721Received.selector;
        return IERC721Receiver.onERC721Received.selector;
    }
}


