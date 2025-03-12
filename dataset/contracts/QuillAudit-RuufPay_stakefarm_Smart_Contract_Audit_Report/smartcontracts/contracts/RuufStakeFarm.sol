// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract RuufStakeFarm {
    using SafeERC20 for IERC20;

    address immutable private homeToken;
    address public owner;

    struct UserStake {
        uint256 amount;
        uint64 stakeDate;
        uint16 months;
    }

    mapping(address => UserStake) private balances;

    uint256[4] public totalTokensStaked;
    uint16[4] public ir = [200,400,500,732];
    uint256[4] public maxStakes = [30000000*10**18,60000000*10**18,120000000*10**18,240000000*10**18];

    event HomeTokenStaked(address _user, uint _amount, uint _date);
    event WithdrawWithRewards(address _user, uint _homeAmount, uint _rewardsAmount);
    event WithdrawWithoutRewards(address _user, uint _homeAmount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address _homeToken) {
        homeToken = _homeToken;
        owner = msg.sender;
    }

    function stake(address _user, uint256 _amount, uint16 _months) external {
        require(_amount > 0, "InvalidAmount");
        require(_months == 3 || _months == 6 || _months == 9 || _months == 12, "InvalidMonths");
        require(IERC20(homeToken).balanceOf(msg.sender) >= _amount, "NoEnoughTokens");
        require(balances[_user].amount == 0, "UserAlreadyStaked");

        if (_months == 3) require(totalTokensStaked[0] + _amount <= maxStakes[0], "MaxLimitReached3Months");
        else if (_months == 6) require(totalTokensStaked[1] + _amount <= maxStakes[1], "MaxLimitReached6Months");
        else if (_months == 9) require(totalTokensStaked[2] + _amount <= maxStakes[2], "MaxLimitReached9Months");
        else if (_months == 12) require(totalTokensStaked[3] + _amount <= maxStakes[3], "MaxLimitReached12Months");

        balances[_user] = UserStake({
            amount: _amount,
            stakeDate: uint64(block.timestamp),
            months: _months
        });

        IERC20(homeToken).safeTransferFrom(msg.sender, address(this), _amount);
        if (_months == 3) totalTokensStaked[0] += _amount;
        else if (_months == 6) totalTokensStaked[1] += _amount;
        else if (_months == 9) totalTokensStaked[2] += _amount;
        else if (_months == 12) totalTokensStaked[3] += _amount;

        emit HomeTokenStaked(_user, _amount, block.timestamp);
    }

    function changeIr(uint256 _index, uint16 _ir) external {
        require(msg.sender == owner, "BadOwner");
        require(_index >= 0 && _index <= 3, "BadIndex");
        ir[_index] = _ir;
    }

    function changeMaxStakes(uint256 _index, uint16 _maxStake) external {
        require(msg.sender == owner, "BadOwner");
        require(_index >= 0 && _index <= 3, "BadIndex");
        maxStakes[_index] = _maxStake;
    }

    function withdraw() external {
        _withdraw(msg.sender);
    }

    function withdraw(address _user) external {
        require(msg.sender == owner, "BadOwner");
        _withdraw(_user);
    }

    function _withdraw(address _user) internal {
        require(balances[_user].stakeDate > 0, "NoStaked");

        uint256 stakeDate = balances[_user].stakeDate;
        uint256 rewards = _calculateRewards(_user);
        uint256 amount = balances[_user].amount;
        uint256 months = balances[_user].months;
        delete balances[_user];

        if (months == 3) totalTokensStaked[0] -= amount;
        else if (months == 6) totalTokensStaked[1] -= amount;
        else if (months == 9) totalTokensStaked[2] -= amount;
        else if (months == 12) totalTokensStaked[3] -= amount;

        if ((block.timestamp - stakeDate) >= months * 30 days) {
            IERC20(homeToken).safeTransfer(_user, amount + rewards);
            emit WithdrawWithRewards(_user, amount, rewards);
        } else {
            IERC20(homeToken).safeTransfer(_user, amount);
            emit WithdrawWithoutRewards(_user, amount);
        }
    }

    function changeOwner(address _owner) external {
        require(msg.sender == owner, "BadOwner");
        owner = _owner;
        emit OwnershipTransferred(msg.sender, _owner);
    }

    function getUserData(address _user) external view returns(uint256 homeTokens, uint256 stakeDate, uint256 pendingRewards, uint256 multiplier, uint16 months, int256 untilRewards, uint16 finalIr) {
        homeTokens = balances[_user].amount;
        stakeDate = balances[_user].stakeDate;
        pendingRewards = _calculateRewards(_user);
        months = balances[_user].months;
        multiplier = _calculateMultiplier(stakeDate, months);
        untilRewards = int256(stakeDate + (months * 30 days)) - int256(block.timestamp);
        if (months == 3) finalIr = ir[0];
        else if (months == 6) finalIr = ir[0] + ir[1];
        else if (months == 9) finalIr = ir[0] + ir[1] + ir[2];
        else if (months == 12) finalIr = ir[0] + ir[1] + ir[2] + ir[3];
    }

    function _calculateRewards(address _user) internal view returns(uint256) {
        uint256 amount = balances[_user].amount;
        uint16 months = balances[_user].months;
        uint256 multiplier = _calculateMultiplier(balances[_user].stakeDate, months);

        return amount * multiplier / 10000;
    }

    function _calculateMultiplier(uint256 _stakeDate, uint16 _months) internal view returns(uint256 multiplier) {
        uint256 stakedMonths = (block.timestamp - _stakeDate) / 30 days;
        if (stakedMonths >= 3 && _months == 3) multiplier = ir[0];
        else if (stakedMonths >= 6 && _months == 6) multiplier = ir[0] + ir[1];
        else if (stakedMonths >= 9 && _months == 9) multiplier = ir[0] + ir[1] + ir[2];
        else if (stakedMonths >= 12 && _months == 12) multiplier = ir[0] + ir[1] + ir[2] + ir[3];
    }
}
