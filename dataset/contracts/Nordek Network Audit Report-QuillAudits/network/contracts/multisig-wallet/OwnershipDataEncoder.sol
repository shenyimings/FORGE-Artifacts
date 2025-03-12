// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract OwnershipDataEncoder {
    
    mapping(bytes32 => address) internal addressStorage;

    function getOwner() public view returns(address) {
      return addressStorage[keccak256(abi.encodePacked("owner"))];
    }

    function _setOwner(address _owner) private {
      addressStorage[keccak256(abi.encodePacked("owner"))] = _owner;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function transferOwnership(address _newOwner) public  {
      require(_newOwner != address(0));
      emit OwnershipTransferred(getOwner(), _newOwner);
      _setOwner(_newOwner);
    }

    function getData(address _newOwner) public pure returns (bytes memory) {
        return abi.encodeWithSignature("transferOwnership(address)", _newOwner);
    }
}