// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./lib/roles/OwnerRole.sol";
import "./lib/SafeMath.sol";
import "./lib/IBEP20.sol";
import "./Token.sol";

contract MasterChef is OwnerRole {
    using SafeMath for uint256;

    Token public token;

    uint256 public tokensPerBlock;
    uint256 public startBlock;
    uint256 public totalAllocPoint;

    address public devAddress;
    uint16 public harvestDevFee;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint16 extraBonus;
    }

    struct PoolInfo {
        IBEP20 token;
        uint256 total;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accTokensPerShare;
        uint16 depositFee;
        uint16 withdrawFee;
        uint16 extraBonus;
    }

    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(Token _token, uint256 _tokensPerBlock, uint256 _startBlock) public {
        token = _token;
        tokensPerBlock = _tokensPerBlock;
        startBlock = _startBlock;

        devAddress = msg.sender;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function getMultiplier(uint256 _blockFrom, uint256 _blockTo) public pure returns (uint256) {
        return _blockTo.sub(_blockFrom);
    }

    function calcFee(uint256 _amount, uint16 _percent) public pure returns (uint256) {
        require(_percent >= 0 && _percent <= 10000);

        return _amount.mul(_percent).div(10000);
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        if (pool.total == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tokensReward = multiplier.mul(tokensPerBlock).mul(pool.allocPoint).div(totalAllocPoint);

        if (harvestDevFee > 0) {
            uint256 harvestFeeAmount = calcFee(tokensReward, harvestDevFee);
            token.mint(address(this), harvestFeeAmount);
            token.transfer(devAddress, harvestFeeAmount);
        }

        token.mint(address(this), tokensReward);

        pool.accTokensPerShare = pool.accTokensPerShare.add(tokensReward.mul(1e12).div(pool.total));
        pool.lastRewardBlock = block.number;
    }

    function pending(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 accTokensPerShare = pool.accTokensPerShare;

        if (block.number > pool.lastRewardBlock && pool.total != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 treeReward = multiplier.mul(tokensPerBlock).mul(pool.allocPoint).div(totalAllocPoint);

            accTokensPerShare = accTokensPerShare.add(treeReward.mul(1e12).div(pool.total));
        }

        uint256 total = user.amount.mul(accTokensPerShare).div(1e12).sub(user.rewardDebt);

        if (user.extraBonus > 0) {
            uint256 extraBonusAmount = calcFee(total, user.extraBonus);
            total = total.add(extraBonusAmount);
        }

        return total;
    }

    function deposit(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(_pid);

        if (user.amount > 0) {
            uint256 pendingTokens = user.amount.mul(pool.accTokensPerShare).div(1e12).sub(user.rewardDebt);
            if (pendingTokens > 0) {
                safeTokenTransfer(msg.sender, pendingTokens, _pid);
            }
        }

        if (_amount > 0) {
            pool.token.transferFrom(address(msg.sender), address(this), _amount);

            if (pool.depositFee > 0) {
                uint256 depositFeeAmount = calcFee(_amount, pool.depositFee);

                pool.token.transfer(devAddress, depositFeeAmount);
                _amount = _amount.sub(depositFeeAmount);
            }

            user.amount = user.amount.add(_amount);
            pool.total = pool.total.add(_amount);

            if (pool.extraBonus > user.extraBonus) {
                user.extraBonus = pool.extraBonus;
            }
        }

        user.rewardDebt = user.amount.mul(pool.accTokensPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount);

        updatePool(_pid);

        if (user.amount > 0) {
            uint256 pendingTokens = user.amount.mul(pool.accTokensPerShare).div(1e12).sub(user.rewardDebt);
            if (pendingTokens > 0) {
                safeTokenTransfer(msg.sender, pendingTokens, _pid);
            }
        }

        if (_amount > 0) {
            user.extraBonus = 0;
            user.amount = user.amount.sub(_amount);
            pool.total = pool.total.sub(_amount);

            if (pool.withdrawFee > 0) {
                uint256 withdrawFeeAmount = calcFee(_amount, pool.withdrawFee);

                pool.token.transfer(devAddress, withdrawFeeAmount);
                _amount = _amount.sub(withdrawFeeAmount);
            }

            pool.token.transfer(address(msg.sender), _amount);
        }

        user.rewardDebt = user.amount.mul(pool.accTokensPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function emergencyWithdraw(uint256 _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 amount = user.amount;

        user.amount = 0;
        user.extraBonus = 0;
        user.rewardDebt = 0;

        pool.total = pool.total.sub(amount);

        if (pool.withdrawFee > 0) {
            uint256 withdrawFeeAmount = calcFee(amount, pool.withdrawFee);

            pool.token.transfer(devAddress, withdrawFeeAmount);
            amount = amount.sub(withdrawFeeAmount);
        }

        pool.token.transfer(address(msg.sender), amount);

        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    function safeTokenTransfer(address _to, uint256 _amount, uint256 _pid) internal {
        uint256 balance = token.balanceOf(address(this));
        if (_amount > balance) {
            _amount = balance;
        }

        token.transfer(_to, _amount);

        UserInfo storage user = userInfo[_pid][_to];
        if (user.extraBonus > 0) {
            uint256 extraBonusAmount = calcFee(_amount, user.extraBonus);
            token.mint(address(this), extraBonusAmount);
            token.transfer(_to, extraBonusAmount);
        }
    }

    function add(IBEP20 _token, uint256 _allocPoint, uint16 _depositFee, uint16 _withdrawFee, uint16 _extraBonus, bool _withUpdate) external onlyOwner {
        require(_depositFee >= 0 && _depositFee <= 10000);
        require(_withdrawFee >= 0 && _withdrawFee <= 10000);

        if (_withUpdate) {
            massUpdatePools();
        }

        totalAllocPoint = totalAllocPoint.add(_allocPoint);

        poolInfo.push(PoolInfo({
            token: _token,
            total: 0,
            allocPoint: _allocPoint,
            lastRewardBlock: block.number > startBlock ? block.number: startBlock,
            accTokensPerShare: 0,
            depositFee: _depositFee,
            withdrawFee: _withdrawFee,
            extraBonus: _extraBonus
        }));
    }

    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFee, uint16 _withdrawFee, uint16 _extraBonus, bool _withUpdate) external onlyOwner {
        require(_depositFee >= 0 && _depositFee <= 10000);
        require(_withdrawFee >= 0 && _withdrawFee <= 10000);

        if (_withUpdate) {
            massUpdatePools();
        }

        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;

        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFee = _depositFee;
        poolInfo[_pid].withdrawFee = _withdrawFee;
        poolInfo[_pid].extraBonus = _extraBonus;

        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
        }
    }

    function updateDevAddress(address _devAddress) external onlyOwner {
        devAddress = _devAddress;
    }

    function updateHarvestDevFee(uint16 _harvestDevFee) external onlyOwner {
        harvestDevFee = _harvestDevFee;
    }

    function updateTokensPerBlock(uint256 _tokensPerBlock) external onlyOwner {
        massUpdatePools();
        tokensPerBlock = _tokensPerBlock;
    }
}
