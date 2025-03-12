pragma solidity 0.4.26;

import "../Consensus.sol";

contract ConsensusMock is Consensus {
  uint256 currentValidatorsLengthMock = 0;

  function setSystemAddressMock(address _newAddress) public onlyOwner {
    addressStorage[SYSTEM_ADDRESS] = _newAddress;
  }

  function getSystemAddress() public view returns(address) {
    return addressStorage[SYSTEM_ADDRESS];
  }

  function hasCycleEnded() public view returns(bool) {
    return _hasCycleEnded();
  }

  function setNewValidatorSetMock(address[] _newSet) public {
    addressArrayStorage[NEW_VALIDATOR_SET] = _newSet;
  }

  function setStakeAmountMockGroup(address[] _newSet) public {
    for (uint256 i; i < _newSet.length; i+=1) {
       _stakeAmountAdd(_newSet[i],1000000000000000000);
    }
  }

  function addStakeAmountMock(address addr, uint256 amount) public {
    _stakeAmountAdd(addr, amount);
  }

  function setFinalizedMock(bool _status) public {
    boolStorage[IS_FINALIZED] = _status;
  }

  function setShouldEmitInitiateChangeMock(bool _status) public {
    boolStorage[SHOULD_EMIT_INITIATE_CHANGE] = _status;
  }

  function getMinStake() public pure returns(uint256) {
    return 1e22;
  }

  function getMaxStake() public pure returns(uint256) {
    return 5e22;
  }

  function getCycleDurationBlocks() public pure returns(uint256) {
    return 120;
  }

  function setCurrentValidatorsLengthMock(uint256 _currentValidatorsLengthMock) external {
    currentValidatorsLengthMock = _currentValidatorsLengthMock;
  }

  function currentValidatorsLength() public view returns(uint256) {
    if (currentValidatorsLengthMock > 0) {
      return currentValidatorsLengthMock;
    }
    return super.currentValidatorsLength();
  }

  function setValidatorFeeMock(uint256 _amount) external {
    require (_amount <= 1 * DECIMALS);
    _setValidatorFee(msg.sender, _amount);
  }

  function setTotalStakeAmountMock(uint256 _totalStake) public {
    _setTotalStakeAmount(_totalStake);
  }

  function setBlockCounterMock(address _val, uint256 counter) public {
    uintStorage[keccak256(abi.encodePacked("blockCounter", _val))] = counter;
  }
}
