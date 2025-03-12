// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

contract ElectionVerify {
  function verify(
    bytes32 _voteData,
    address _address,
    uint256 _index,
    uint256 _amount,
    string memory _key
  ) public pure returns (bool) {
    return keccak256(abi.encode(_address, _index, _amount, _key)) == _voteData;
  }

  function hash(
    address _address,
    uint256 _index,
    uint256 _amount,
    string memory _key
  ) public pure returns (bytes32) {
    return keccak256(abi.encode(_address, _index, _amount, _key));
  }
}
