// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";

import "../core/interfaces/IAlpManager.sol";

import "./interfaces/IRewardTracker.sol";
import "./interfaces/IRewardTracker.sol";

// provide a way to transfer staked ALP tokens by unstaking from the sender
// and staking for the receiver
// tests in RewardRouterV2.js
contract StakedAlp {
    using SafeMath for uint256;

    string public constant name = "StakedAlp";
    string public constant symbol = "sALP";
    uint8 public constant decimals = 18;

    address public alp;
    IAlpManager public alpManager;
    address public stakedAlpTracker;
    address public feeAlpTracker;

    mapping (address => mapping (address => uint256)) public allowances;

    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(
        address _alp,
        IAlpManager _alpManager,
        address _stakedAlpTracker,
        address _feeAlpTracker
    ) public {
        alp = _alp;
        alpManager = _alpManager;
        stakedAlpTracker = _stakedAlpTracker;
        feeAlpTracker = _feeAlpTracker;
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transfer(address _recipient, uint256 _amount) external returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool) {
        uint256 nextAllowance = allowances[_sender][msg.sender].sub(_amount, "StakedAlp: transfer amount exceeds allowance");
        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function balanceOf(address _account) external view returns (uint256) {
        IRewardTracker(stakedAlpTracker).depositBalances(_account, alp);
    }

    function totalSupply() external view returns (uint256) {
        IERC20(stakedAlpTracker).totalSupply();
    }

    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), "StakedAlp: approve from the zero address");
        require(_spender != address(0), "StakedAlp: approve to the zero address");

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        require(_sender != address(0), "StakedAlp: transfer from the zero address");
        require(_recipient != address(0), "StakedAlp: transfer to the zero address");

        require(
            alpManager.lastAddedAt(_sender).add(alpManager.cooldownDuration()) <= block.timestamp,
            "StakedAlp: cooldown duration not yet passed"
        );

        IRewardTracker(stakedAlpTracker).unstakeForAccount(_sender, feeAlpTracker, _amount, _sender);
        IRewardTracker(feeAlpTracker).unstakeForAccount(_sender, alp, _amount, _sender);

        IRewardTracker(feeAlpTracker).stakeForAccount(_sender, _recipient, alp, _amount);
        IRewardTracker(stakedAlpTracker).stakeForAccount(_recipient, _recipient, feeAlpTracker, _amount);
    }
}
