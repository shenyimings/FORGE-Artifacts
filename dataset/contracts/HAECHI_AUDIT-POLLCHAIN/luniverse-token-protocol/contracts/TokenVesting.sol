pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./SideToken.sol";

contract TokenVesting {
  using SafeMath for uint256;

  uint256 constant SECONDS_IN_A_DAY = 86400;

  SideToken sideToken;

  address public recipient;
  uint256 public vestedAmount;
  uint256 public releasedAmount;

  uint256 public startTimestamp;
  uint256 public cliffTimestamp;

  uint256 public durationInSeconds;
  uint256 public intervalInSeconds;

  uint256 public intervalInDays;
  uint256 public releaseAmountADay;

  event Released(address recipient, uint256 releaseAmount, uint256 releasedAmount);

  constructor(SideToken _sideToken, address _recipient, uint256 _vestedAmount, uint256 _start, uint256 _cliffInDays, uint256 _durationInDays, uint256 _intervalInDays) public {
    sideToken = _sideToken;
    recipient = _recipient;
    vestedAmount = _vestedAmount;

    startTimestamp = _start;
    cliffTimestamp = startTimestamp.add(_cliffInDays.mul(SECONDS_IN_A_DAY));
    durationInSeconds = _durationInDays.mul(SECONDS_IN_A_DAY);

    intervalInDays = _intervalInDays;
    intervalInSeconds = _intervalInDays.mul(SECONDS_IN_A_DAY);

    releaseAmountADay = vestedAmount.div(_durationInDays);
  }

  function release() external {
    uint256 releaseAmount = calculateReleaseAmount(block.timestamp);

    releaseAmount = releaseAmount.sub(releasedAmount);

    require(releaseAmount > 0 );

    sideToken.transfer(recipient, releaseAmount);

    releasedAmount = releasedAmount.add(releaseAmount);

    emit Released(recipient, releaseAmount, releasedAmount);
  }

  function calculateReleaseAmount(uint256 blockTimestamp) public view returns (uint256 releaseAmount) {
    // Don't release befor cliff
    if ( blockTimestamp < cliffTimestamp)
      return 0;

    // Release all after duration
    if ( blockTimestamp >= cliffTimestamp.add(durationInSeconds) )
      return vestedAmount - releasedAmount;

    uint256 timeDiff = blockTimestamp.sub(cliffTimestamp);
    uint256 pastIntervals = timeDiff.div(intervalInSeconds).add(1);

    // releaseAmountADay * pastIntervals * intervalInDays
    releaseAmount = releaseAmountADay.mul(pastIntervals.mul(intervalInDays));

    if ( releaseAmount > vestedAmount )
      releaseAmount = vestedAmount;

    return releaseAmount;
  }
}
