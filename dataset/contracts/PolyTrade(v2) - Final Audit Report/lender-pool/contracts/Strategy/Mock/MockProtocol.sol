//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @author Polytrade
 * @title MockProtocol // NOT FOR PROD
 */
contract MockProtocol {
    IERC20 public token;

    uint public reward = 1;

    mapping(address => uint) private _deposits;
    mapping(address => uint) private _time;
    mapping(address => uint) private _pendingRewards;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function deposit(uint amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        if (_deposits[msg.sender] > 0) {
            _updateRewards(msg.sender, _deposits[msg.sender]);
        } else {
            _time[msg.sender] = block.timestamp;
        }
        _deposits[msg.sender] += amount;
    }

    function withdraw() external {
        require(_deposits[msg.sender] > 0, "No deposit");
        _updateRewards(msg.sender, _deposits[msg.sender]);
        uint amountPending = _pendingRewards[msg.sender];
        uint amount = _deposits[msg.sender];

        _deposits[msg.sender] = 0;
        _pendingRewards[msg.sender] = 0;
        _time[msg.sender] = 0;
        token.transfer(msg.sender, (amount + amountPending));
    }

    function withdrawAmount(uint amount) external {
        require(_deposits[msg.sender] > 0, "No deposit");
        _updateRewards(msg.sender, _deposits[msg.sender]);
        uint amountPending = _pendingRewards[msg.sender];
        _pendingRewards[msg.sender] = 0;
        _deposits[msg.sender] += amountPending;

        _deposits[msg.sender] -= amount;
        _time[msg.sender] = block.timestamp;
        token.transfer(msg.sender, amount);
    }

    function rewardOf(address user) external view returns (uint) {
        return ((_pendingRewards[user]) +
            _calculateRewards(user, _deposits[user]));
    }

    function getDeposits(address user) external view returns (uint) {
        return _deposits[user];
    }

    function _updateRewards(address user, uint amount) private {
        _pendingRewards[user] = _calculateRewards(user, amount);
        _time[user] = block.timestamp;
    }

    function _calculateRewards(address user, uint amount)
        private
        view
        returns (uint)
    {
        return ((block.timestamp - _time[user]) * amount * reward) / 10000000;
    }
}
