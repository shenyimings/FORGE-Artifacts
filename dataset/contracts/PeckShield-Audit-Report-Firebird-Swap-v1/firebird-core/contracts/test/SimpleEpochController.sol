pragma solidity 0.7.6;

import "../interfaces/IEpochController.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IStakePoolEpochReward.sol";
import '../libraries/TransferHelper.sol';
contract SimpleEpochController is IEpochController {
    uint256 public _epoch = 0;
    uint256 public epochLength = 5 minutes;
    uint256 public lastEpochTime;
    address public allocator;
    address public owner;

    constructor() {
        owner = msg.sender;
        allocator = msg.sender;
    }

    function epoch() external override view returns (uint256) {
        return _epoch;
    }

    function nextEpochPoint() external override view returns (uint256) {
        return lastEpochTime + nextEpochLength();
    }

    function setOwner(address _owner) external {
        require(msg.sender == owner, 'SimpleEpochController: FORBIDDEN');
        owner = _owner;
    }

    function setAllocator(address _allocator) external {
        require(msg.sender == owner, 'SimpleEpochController: FORBIDDEN');
        allocator = _allocator;
    }
    function nextEpochLength() public override view returns (uint256) {
        return epochLength;
    }

    function allocateReward(address pool) external {
        require(msg.sender == allocator, 'SimpleEpochController: FORBIDDEN');
        uint256 _amount = nextEpochAllocatedReward(pool);
        address rewardToken = IStakePoolEpochReward(pool).rewardToken();
        TransferHelper.safeApprove(rewardToken, pool, _amount);
        _epoch = _epoch + 1;
        lastEpochTime = block.timestamp;
        IStakePoolEpochReward(pool).allocateReward(_amount);
    }

    function nextEpochAllocatedReward(address pool) public override view returns (uint256) {
        address rewardToken = IStakePoolEpochReward(pool).rewardToken();
        return IERC20(rewardToken).balanceOf(address(this));
    }
}
