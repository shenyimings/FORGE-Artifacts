// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "./interfaces/IStakePoolRewardFund.sol";
import "./interfaces/IStakePool.sol";
import "./interfaces/IStakePoolRewardRebaser.sol";
import "./interfaces/IStakePoolRewardMultiplier.sol";
import "./interfaces/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import './libraries/TransferHelper.sol';
import "./interfaces/IStakePool.sol";

contract StakePoolRewardFund is IStakePoolRewardFund {
    address public stakePool;
    address public timelock;
    bool private _initialized;

    function initialize(address _stakePool, address _timelock) external override {
        require(_initialized == false, "StakePoolRewardFund: already initialized");
        stakePool = _stakePool;
        timelock = _timelock;
        _initialized = true;
    }

    function safeTransfer(address _token, address _to, uint256 _value) external override {
        require(msg.sender == stakePool, "StakePoolRewardFund: !stakePool");
        TransferHelper.safeTransfer(_token, _to, _value);
    }

    function allowRecoverRewardToken(address _token) public view returns (bool){
        return IStakePool(stakePool).allowRecoverRewardToken(_token);
    }

    function recoverAllRewardToken(
        address _token,
        address _to
    ) external {
        recoverRewardToken(_token, _to, IERC20(address(_token)).balanceOf(address(this)));
    }

    function recoverRewardToken(
        address _token,
        address _to,
        uint256 _amount
    ) public {
        require(msg.sender == timelock, "StakePoolRewardFund: !timelock");
        require(allowRecoverRewardToken(_token), "StakePoolRewardFund: not allow recover reward token");
        TransferHelper.safeTransfer(_token, _to, _amount);
    }
}
