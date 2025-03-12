pragma solidity ^0.6.12;

import "../../zeppelin-solidity/contracts/access/Ownable.sol";

contract MerkleTreeTokensVerification is Ownable{
  bytes32 public root;

  constructor(bytes32 _root)public{
    root = _root;
  }

  // owner can update root
  function changeRoot(bytes32 _root) public onlyOwner{
    root = _root;
  }


  function verify(
    address _leaf,
    bytes32 [] memory proof,
    uint256 [] memory positions
  )
    public
    view
    returns (bool)
  {
    bytes32 leaf = getLeaf(_leaf);
    bytes32 computedHash = leaf;

    for (uint256 i = 0; i < proof.length; i++) {
       bytes32 proofElement = proof[i];
       if (positions[i] == 1) {
       computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
      } else {
       computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
       }
     }

     return computedHash == root;
  }

  // internal helpers for convert address
  function addressToString(address x) internal pure returns (string memory) {
    bytes memory b = new bytes(20);
    for (uint i = 0; i < 20; i++)
        b[i] = byte(uint8(uint(x) / (2**(8*(19 - i)))));
    return string(b);
  }

  function getLeaf(address _input) internal pure returns(bytes32){
    return keccak256(abi.encodePacked(addressToString(_input)));
  }
}
