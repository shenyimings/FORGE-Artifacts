pragma solidity ^0.6.12;

/**
* Logic: Permitetd addresses can write to this contract types of converted tokens
*
* Motivation:
* Due fact tokens can be different like Uniswap/Bancor pool, Synthetix, Compound ect
* we need a certain method for convert a certain token.
* so we flag type for new token once after success convert
*/

import "../../zeppelin-solidity/contracts/access/Ownable.sol";

contract TokensTypeStorage is Ownable {
  // check if token alredy registred
  mapping(address => bool) public isRegistred;
  // tokens types
  mapping(address => bytes32) public getType;
  // return true if input type alredy exist
  mapping(bytes32 => bool) public isTypeRegistred;
  // addresses which can write to this contract
  mapping(address => bool) public isPermittedAddress;

  // all available types
  bytes32[] public allTypes;

  modifier onlyPermitted() {
    require(isPermittedAddress[msg.sender], "Not permition for edit Tokens Type");
    _;
  }

  // allow add new token type from trade portals
  function addNewTokenType(address _token, string calldata _type) external onlyPermitted {
    // Don't flag this token if this token alredy registred
    if(isRegistred[_token])
      return;

    // convert string to bytes32
    bytes32 typeToBytes = stringToBytes32(_type);

    // flag new token
    getType[_token] = typeToBytes;
    isRegistred[_token] = true;

    // Add new type
    if(!isTypeRegistred[typeToBytes]){
      isTypeRegistred[typeToBytes] = true;
      allTypes.push(typeToBytes);
    }
  }


  // allow update token type from owner wallet
  function setTokenTypeAsOwner(address _token, string calldata _type) external onlyOwner{
    // convert string to bytes32
    bytes32 typeToBytes = stringToBytes32(_type);

    // flag token with new type
    getType[_token] = typeToBytes;
    isRegistred[_token] = true;

    // if new type unique add it to the list
    if(!isTypeRegistred[typeToBytes]){
      isTypeRegistred[typeToBytes] = true;
      allTypes.push(typeToBytes);
    }
  }



  function addNewPermittedAddress(address _permitted) public onlyOwner {
    isPermittedAddress[_permitted] = true;
  }

  function removePermittedAddress(address _permitted) public onlyOwner {
    isPermittedAddress[_permitted] = false;
  }

  // helper for convert dynamic string size to fixed bytes32 size
  function stringToBytes32(string memory source) private pure returns (bytes32 result) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
        return 0x0;
    }

    assembly {
        result := mload(add(source, 32))
    }
   }
}
