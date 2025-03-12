// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract RuufStakeFarm {
    using SafeERC20 for IERC20;

    address immutable private homeToken;
    address public owner;
    address private ownerPendingClaim;

    struct UserStake {
        uint256 amount;
        uint64 stakeDate;
        uint64 months;
        uint16 ir;
    }

    mapping(address => UserStake) private balances;

    uint256[4] public totalTokensStaked;
    uint16[4] public ir = [200,600,1100,1832];
    uint256[4] public maxStakes = [30000000*10**18,60000000*10**18,120000000*10**18,240000000*10**18];

    event HomeTokenStaked(address indexed _user, uint _amount, uint _date);
    event WithdrawWithRewards(address indexed _user, uint _homeAmount, uint _rewardsAmount);
    event WithdrawWithoutRewards(address indexed _user, uint _homeAmount);
    event NewOwnershipProposed(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event IrChanged(uint256 _index, uint16 _ir);
    event MaxStakesChanged(uint256 _index, uint256 _maxStake);

    constructor(address _homeToken) {
        require(_homeToken != address(0), "NullAddress");

        homeToken = _homeToken;
        owner = msg.sender;
    }

    function stake(uint256 _amount, uint64 _months) external {
        require(_amount > 0, "InvalidAmount");
        require(_months == 3 || _months == 6 || _months == 9 || _months == 12, "InvalidMonths");
        require(IERC20(homeToken).balanceOf(msg.sender) >= _amount, "NoEnoughTokens");
        require(balances[msg.sender].amount == 0, "UserAlreadyStaked");

        uint index = 0;
        if (_months == 6) index = 1;
        else if (_months == 9) index = 2;
        else if (_months == 12) index = 3;

        require(totalTokensStaked[index] + _amount <= maxStakes[index], "MaxLimitMonthsReached");

        balances[msg.sender] = UserStake({
            amount: _amount,
            stakeDate: uint64(block.timestamp),
            months: _months,
            ir: ir[index]
        });

        IERC20(homeToken).safeTransferFrom(msg.sender, address(this), _amount);
        totalTokensStaked[index] += _amount;

        emit HomeTokenStaked(msg.sender, _amount, block.timestamp);
    }

    function changeIr(uint256 _index, uint16 _ir) external {
        require(msg.sender == owner, "BadOwner");
        require(_index >= 0 && _index <= 3, "BadIndex");
        ir[_index] = _ir;

        emit IrChanged(_index, _ir);
    }

    function changeMaxStakes(uint256 _index, uint256 _maxStake) external {
        require(msg.sender == owner, "BadOwner");
        require(_index >= 0 && _index <= 3, "BadIndex");
        maxStakes[_index] = _maxStake;

        emit MaxStakesChanged(_index, _maxStake);
    }

    function withdraw(address _user) external {
        if (msg.sender != _user) require(msg.sender == owner, "BadOwner");
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

    function proposeChangeOwner(address _owner) external {
        require(msg.sender == owner, "BadOwner");
        require(_owner != address(0), "NotNullAllowed");
        
        ownerPendingClaim = _owner;
        emit NewOwnershipProposed(msg.sender, _owner);
    }

    function claimOwnership() external {
        require(msg.sender == ownerPendingClaim, "OnlyProposedOwner");

        address oldOwner = owner;
        owner = ownerPendingClaim;
        ownerPendingClaim = address(0);
        emit OwnershipTransferred(oldOwner, owner);
    }

    function getUserData(address _user) external view returns(uint256 homeTokens, uint256 stakeDate, uint256 pendingRewards, uint256 multiplier, uint64 months, int256 untilRewards, uint16 finalIr) {
        homeTokens = balances[_user].amount;
        stakeDate = balances[_user].stakeDate;
        pendingRewards = _calculateRewards(_user);
        months = balances[_user].months;
        finalIr = balances[_user].ir;
        if (block.timestamp >= uint256(stakeDate + (months * 30 days))) {
            untilRewards = 0;
            multiplier = balances[_user].ir;
        } else {
            untilRewards = int256(stakeDate + (months * 30 days)) - int256(block.timestamp);
            multiplier = 0;
        }
    }

    function _calculateRewards(address _user) internal view returns(uint256) {
        uint256 amount = balances[_user].amount;
        uint64 months = balances[_user].months;
        uint64 stakeDate = balances[_user].stakeDate;
        uint256 stakedMonths = (block.timestamp - stakeDate) / 30 days;
        uint256 multiplier = 0;
        if (stakedMonths >= 3 && months == 3) multiplier = balances[_user].ir;
        else if (stakedMonths >= 6 && months == 6) multiplier = balances[_user].ir;
        else if (stakedMonths >= 9 && months == 9) multiplier = balances[_user].ir;
        else if (stakedMonths >= 12 && months == 12) multiplier = balances[_user].ir;

        return amount * multiplier / 10000;
    }
}
