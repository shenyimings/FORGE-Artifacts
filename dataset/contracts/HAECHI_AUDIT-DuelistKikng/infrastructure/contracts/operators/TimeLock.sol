// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract TimeLock {
  address private immutable _owner;

  address private immutable _beneficiary;

  uint256 private _timelock;

  IERC20 private immutable _token;

  event StartTimeLock(address indexed beneficiary, address indexed token, uint256 indexed timelock);

  modifier onlyBeneficiary() {
    require(msg.sender == _beneficiary);
    _;
  }

  modifier onlyOwner() {
    require(msg.sender == _owner);
    _;
  }

  constructor(
    address beneficiary_,
    address token_,
    uint256 ifoTime_
  ) {
    _owner = msg.sender;
    _beneficiary = beneficiary_;
    _timelock = ifoTime_ + 1 hours + 5 minutes;
    _token = IERC20(token_);
    emit StartTimeLock(beneficiary_, token_, _timelock);
  }

  // Beneficiary could able to withdraw any time after the time lock passed
  function withdraw() external onlyBeneficiary {
    require(block.timestamp > _timelock);
    _token.transfer(_beneficiary, _token.balanceOf(address(this)));
  }

  // Owner could able to help beneficiary to withdraw regardless the time lock
  // This could resolve the glitch between blockchain time and epoch time
  function helpWithdraw() external onlyOwner {
    _token.transfer(_beneficiary, _token.balanceOf(address(this)));
  }

  function getBlockchainTime() public view returns (uint256, uint256) {
    return (block.timestamp, _timelock);
  }
}
