// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

contract MultiOwner {
  // Multi owner data
  mapping(address => bool) private _owners;

  // Multi owner data
  mapping(address => uint256) private _activeTime;

  // Total number of owners
  uint256 private _totalOwner;

  // Only allow listed address to trigger smart contract
  modifier onlyListedOwner() {
    require(
      _owners[msg.sender] && block.timestamp > _activeTime[msg.sender],
      'MultiOwner: We are only allow owner to trigger this contract'
    );
    _;
  }

  // Transfer ownership event
  event TransferOwnership(address indexed preOwner, address indexed newOwner);

  constructor(address[] memory owners_) {
    for (uint256 i = 0; i < owners_.length; i += 1) {
      _owners[owners_[i]] = true;
      emit TransferOwnership(address(0), owners_[i]);
    }
    _totalOwner = owners_.length;
  }

  /*******************************************************
   * Internal section
   ********************************************************/

  function _transferOwnership(address newOwner, uint256 lockDuration) internal returns (bool) {
    require(newOwner != address(0), 'MultiOwner: Can not transfer ownership to zero address');
    _owners[msg.sender] = false;
    _owners[newOwner] = true;
    _activeTime[newOwner] = block.timestamp + lockDuration;
    emit TransferOwnership(msg.sender, newOwner);
    return _owners[newOwner];
  }

  /*******************************************************
   * View section
   ********************************************************/

  function isOwner(address checkAddress) public view returns (bool) {
    return _owners[checkAddress] && block.timestamp > _activeTime[checkAddress];
  }

  function totalOwner() public view returns (uint256) {
    return _totalOwner;
  }
}
