pragma solidity 0.7.6;

import "../interfaces/IEpochController.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IStakePoolEpochReward.sol";

contract EpochControllerMock is IEpochController {
    uint256 private _epoch = 0;
    address public rewardToken;
    uint256 public lastEpochTime;

    constructor(address _rewardToken) {
        rewardToken = _rewardToken;
    }

    function epoch() external override view returns (uint256) {
        return _epoch;
    }

    function nextEpochPoint() external override view returns (uint256) {
        return lastEpochTime + nextEpochLength();
    }

    function nextEpochLength() public override view returns (uint256) {
        return 12 hours;
    }

    function resetEpochTime() external {
        lastEpochTime = block.timestamp;
    }

    function updateEpochTime(uint256 _lastEpochTime) external {
        lastEpochTime = _lastEpochTime;
    }

    function allocateSeigniorage(uint256 _amount, address _pool) external {
        _epoch = _epoch + 1;
        lastEpochTime = block.timestamp;
        IERC20(rewardToken).transferFrom(msg.sender, address(this), _amount);
        IERC20(rewardToken).approve(_pool, 0);
        IERC20(rewardToken).approve(_pool, _amount);
        IStakePoolEpochReward(_pool).allocateReward(_amount);
    }

    function nextEpochAllocatedReward(address _pool) external override view returns (uint256) {
        return 0;
    }
}
