//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IMinter.sol";

contract Staking is Ownable {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    struct PoolInfo {
        uint256 accRewardPerShare;
        uint256 lastRewardTime;
        uint256 endRewardTime;
        uint256 startRewardTime;

        uint256 rewardPerSecond;
    }


    // governance
    uint256 private constant ACC_REWARD_PRECISION = 1e12;


    mapping (uint256 => mapping(address => UserInfo)) public userInfo;
    PoolInfo[] public poolInfo;
    mapping (address => mapping(address => bool)) public addedPools;
    mapping (address => bool) public addedRewards;
    IERC20[] public lpToken;
    IERC20[] public reward;

    address public PAN;
    IMinter public minter;

    /* ========== Modifiers =============== */

    constructor(address _PAN, address _minter) {
        PAN = _PAN;
        minter = IMinter(_minter);
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    function getRewardForDuration(uint256 _pid, uint256 _from, uint256 _to) public view returns (uint256) {
        PoolInfo memory _pool = poolInfo[_pid];
        if (_from >= _to || _from >= _pool.endRewardTime) return 0;
        if (_to <= _pool.startRewardTime) return 0;
        if (_from <= _pool.startRewardTime) {
            if (_to <= _pool.endRewardTime) return (_to - _pool.startRewardTime) * _pool.rewardPerSecond;
            else return (_pool.endRewardTime - _pool.startRewardTime) * _pool.rewardPerSecond;
        }
        if (_to <= _pool.endRewardTime) return (_to - _from) * _pool.rewardPerSecond;
        else return (_pool.endRewardTime - _from) * _pool.rewardPerSecond;
    }

    function getRewardPerSecond(uint256 _pid) public view returns (uint256) {
        return getRewardForDuration(_pid, block.timestamp, block.timestamp + 1);
    }

    function pendingReward(address _account, uint256 _pid) external view returns (uint256 _pending) {
        UserInfo storage _user = userInfo[_pid][_account];
        PoolInfo memory _pool = poolInfo[_pid];

        uint256 _accRewardPerShare = _pool.accRewardPerShare;
        uint256 _lpSupply = lpToken[_pid].balanceOf(address(this));
        if (block.timestamp > _pool.lastRewardTime && _lpSupply > 0) {
            uint256 _rewardAmount = getRewardForDuration(_pid, _pool.lastRewardTime, block.timestamp);
            _accRewardPerShare += (_rewardAmount * ACC_REWARD_PRECISION) / _lpSupply;
        }
        _pending = uint256(int256(_user.amount * _accRewardPerShare / ACC_REWARD_PRECISION) - _user.rewardDebt);
    }

    /// @notice Update reward variables of the given pool.
    function updatePool(uint256 _pid) public returns (PoolInfo memory _pool) {
        _pool = poolInfo[_pid];
        if (block.timestamp > _pool.lastRewardTime) {
            uint256 _lpSupply = lpToken[_pid].balanceOf(address(this));
            if (_lpSupply > 0) {
                uint256 _rewardAmount = getRewardForDuration(_pid, _pool.lastRewardTime, block.timestamp);
                _pool.accRewardPerShare += _rewardAmount * ACC_REWARD_PRECISION / _lpSupply;
            }
            _pool.lastRewardTime = block.timestamp;
            emit LogUpdatePool(_pid, _pool.lastRewardTime, _lpSupply, _pool.accRewardPerShare);
        }
    }

    function massUpdatePools(uint256[] calldata pids) external {
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    function deposit(uint256 _pid, uint256 _amount, address _to) public {
        PoolInfo memory _pool = updatePool(_pid);
        UserInfo storage _user = userInfo[_pid][_to];

        _user.amount += _amount;
        _user.rewardDebt += int256(_amount * _pool.accRewardPerShare / ACC_REWARD_PRECISION);


        emit Deposit(msg.sender, _pid, _amount, _to);
    }


    function withdraw(uint256 _pid, uint256 _amount, address _to) public {
        PoolInfo memory _pool = updatePool(_pid);
        UserInfo storage _user = userInfo[_pid][msg.sender];

        _user.rewardDebt -= int256(_amount * _pool.accRewardPerShare / ACC_REWARD_PRECISION);
        _user.amount -= _amount;

        lpToken[_pid].safeTransfer(_to, _amount);
        emit Withdraw(msg.sender, _pid, _amount, _to);
    }


    function harvest(uint256 _pid, address _to) public {
        PoolInfo memory _pool = updatePool(_pid);
        UserInfo storage _user = userInfo[_pid][msg.sender];

        int256 _accumulatedReward = int256(_user.amount * _pool.accRewardPerShare / ACC_REWARD_PRECISION);
        uint256 _pendingReward = uint256(_accumulatedReward - _user.rewardDebt);

        // Effects
        _user.rewardDebt = _accumulatedReward;

       transferReward(reward[_pid], _to, _pendingReward);
        emit Harvest(msg.sender, _pid, _pendingReward);
    }


    function withdrawAndHarvest(uint256 _pid, uint256 _amount, address _to) public {
        PoolInfo memory _pool = updatePool(_pid);
        UserInfo storage _user = userInfo[_pid][msg.sender];

        int256 _accumulatedReward = int256(_user.amount * _pool.accRewardPerShare / ACC_REWARD_PRECISION);
        uint256 _pendingReward = uint256(_accumulatedReward - _user.rewardDebt);

        _user.rewardDebt = _accumulatedReward - int256(_amount * _pool.accRewardPerShare / ACC_REWARD_PRECISION);
        _user.amount -= _amount;

        transferReward(reward[_pid], _to, _pendingReward);
        lpToken[_pid].safeTransfer(_to, _amount);

        emit Withdraw(msg.sender, _pid, _amount, _to);
        emit Harvest(msg.sender, _pid, _pendingReward);
    }

    function massHarvest(uint256[] calldata _pids, address _to) public {
        uint256 len = _pids.length;
        for (uint256 i = 0; i < len; ++i) {
            harvest(_pids[i], _to);
        }
    }

    function emergencyWithdraw(uint256 _pid, address _to) public {
        UserInfo storage _user = userInfo[_pid][msg.sender];
        uint256 _amount = _user.amount;
        _user.amount = 0;
        _user.rewardDebt = 0;

        lpToken[_pid].safeTransfer(_to, _amount);
        emit EmergencyWithdraw(msg.sender, _pid, _amount, _to);
    }

    /* ========== INTERNAL FUNCTIONS ========== */



    function transferReward(IERC20 _reward, address _user, uint256 _amount) internal {
        if (_amount > 0) {
            if (address(_reward) != PAN) {
                _reward.safeTransfer(_user, _amount);
            } else {
                minter.transfer(_user, _amount);
            }
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function add(IERC20 _lpToken, IERC20 _reward) public onlyOwner {
        require(!addedPools[address(_lpToken)][address(_reward)], 'Staking: added before');
        uint256 lastRewardBlock = block.timestamp;
        lpToken.push(_lpToken);
        reward.push(_reward);

        poolInfo.push(PoolInfo({
            accRewardPerShare: 0,
            lastRewardTime: lastRewardBlock,
            endRewardTime: 0,
            startRewardTime : lastRewardBlock,
            rewardPerSecond : 0
        }));
        addedPools[address(_lpToken)][address(_reward)] = true;
        addedRewards[address(_reward)] = true;
        emit LogPoolAddition(lpToken.length - 1, _lpToken, _reward);
    }


    function allocateMoreRewards(uint256 _pid, uint256 _addedReward, uint256 _days) external onlyOwner {
        PoolInfo storage _pool = poolInfo[_pid];
        uint256 _pendingSeconds = (_pool.endRewardTime >  block.timestamp) ? (_pool.endRewardTime - block.timestamp) : 0;
        uint256 _newPendingReward = (_pool.rewardPerSecond * _pendingSeconds) + _addedReward;
        uint256 _newPendingSeconds = _pendingSeconds + (_days * (1 days));
        uint256 _newRewardPerSecond = _newPendingReward / _newPendingSeconds;
        _pool.rewardPerSecond = _newRewardPerSecond;
        if (_days > 0) {
            if (_pool.endRewardTime <  block.timestamp) {
                _pool.endRewardTime =  block.timestamp + (_days * (1 days));
            } else {
                _pool.endRewardTime = _pool.endRewardTime +  (_days * (1 days));
            }
        }
        if (address(lpToken[_pid]) != PAN) {
            reward[_pid].safeTransferFrom(msg.sender, address(this), _addedReward);
        }
        emit LogRewardPerSecond(_newRewardPerSecond);

    }

    function rescueFund(IERC20 _token, uint256 _amount) external onlyOwner {
        require(addedRewards[address(_token)] == true, 'Staking : !reward');
        require(_amount > 0 && _amount <= _token.balanceOf(address(this)), "invalid amount");
        _token.safeTransfer(owner(), _amount);
        emit FundRescued(owner(), _amount);
    }


    function changeMinter(address _newMinter) external onlyOwner {
        minter = IMinter(_newMinter);
    }
    /* =============== EVENTS ==================== */

    event Deposit(address indexed user, uint256 pid, uint256 amount, address indexed to);
    event Withdraw(address indexed user, uint256 pid, uint256 amount, address indexed to);
    event EmergencyWithdraw(address indexed user, uint256 pid, uint256 amount, address indexed to);
    event Harvest(address indexed user, uint256 pid, uint256 amount);
    event LogUpdatePool(uint256 pid, uint256 lastRewardTime, uint256 lpSupply, uint256 accRewardPerShare);
    event LogRewardPerSecond(uint256 rewardPerSecond);
    event FundRescued(address indexed receiver, uint256 amount);
    event LogPoolAddition(uint256 indexed pid,  IERC20 indexed lpToken, IERC20 indexed rewarder);
}