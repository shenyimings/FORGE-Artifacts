pragma solidity ^0.6.2;

import "../core/Pool.sol";
import "./MockState.sol";
import "../core/Constants.sol";

contract MockPool is Pool, MockState {
    uint256 private _blockNumber;
    uint256 private _blockTimestamp;
    uint256 private _stakeLockupDuration;
    uint256 private _vestingDuration;
    address private _cook;
    address private _univ2;

    constructor(
        address cook,
        address univ2,
        uint256 stakeLockupDuration,
        uint256 vestingDuration,
        uint256 cook_reward_per_block
    ) public Pool(cook, univ2, cook_reward_per_block, 0, 0) {
        _cook = cook;
        _univ2 = univ2;
        _blockNumber = block.number;
        _blockTimestamp = block.timestamp;
        _stakeLockupDuration = stakeLockupDuration;
        _vestingDuration = vestingDuration;
    }

    function cook() public view override returns (IERC20) {
        return IERC20(_cook);
    }

    function univ2() public view override returns (IERC20) {
        return IERC20(_univ2);
    }

    /**
     * Mock
     */
    function setBlockNumber(uint256 blockNumber) external {
        _blockNumber = blockNumber;
    }

    function blockNumber() public view override returns (uint256) {
        return _blockNumber;
    }

    function blockNumberE() external view returns (uint256) {
        return _blockNumber;
    }

    function setBlockTimestamp(uint256 blockTimestamp) external {
        _blockTimestamp = blockTimestamp;
    }

    function blockTimestamp() public view override returns (uint256) {
        return _blockTimestamp;
    }

    function blockTimestampE() external view returns (uint256) {
        return _blockTimestamp;
    }

    function setStakeLockupDuration(uint256 stakeLockupDuration) external {
        _stakeLockupDuration = stakeLockupDuration;
    }

    function getStakeLockupDuration() public view override returns (uint256) {
        return _stakeLockupDuration;
    }

    function setVestingDuration(uint256 vestingDuration) external {
        _vestingDuration = vestingDuration;
    }

    function getVestingDuration() public view override returns (uint256) {
        return _vestingDuration;
    }
}
