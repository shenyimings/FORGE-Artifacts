pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";

library LAventusTime {

  function getCurrentTime(IAventusStorage)
    external
    view
    returns (uint time_)
  {
      time_ = now;
  }
}