pragma solidity 0.5.12;

import "../../interfaces/IAventusStorage.sol";

library LAventusTimeMock {

  bytes32 constant mockCurrentTimeKey = keccak256(abi.encodePacked("MockCurrentTime"));

  function init(IAventusStorage _storage)
    external
  {
    _storage.setUInt(mockCurrentTimeKey, now);
  }

  function advanceToTime(IAventusStorage _storage, uint _timestamp)
    external
  {
    require(_timestamp >= getCurrentTime(_storage), "Who do you think you are? Marty McFly!?");
    _storage.setUInt(mockCurrentTimeKey, _timestamp);
  }

  function getCurrentTime(IAventusStorage _storage)
    public
    view
    returns (uint time_)
  {
    time_ = _storage.getUInt(mockCurrentTimeKey);
  }
}