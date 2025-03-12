pragma solidity 0.5.12;

import "../libraries/testing/LAventusTimeMock.sol";
import "../Owned.sol";

contract TimeMachine is Owned {

  IAventusStorage public s;

  constructor(IAventusStorage _s)
    public
  {
    s = _s;
  }

  function getCurrentTime()
    external
    view
    returns (uint time_)
  {
    time_ = LAventusTimeMock.getCurrentTime(s);
  }

  function init()
    onlyOwner
    external
  {
    LAventusTimeMock.init(s);
  }

  function advanceToTime(uint _timestamp)
    onlyOwner
    external
  {
    LAventusTimeMock.advanceToTime(s, _timestamp);
  }
}