// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {OwnableUpgradeable as Ownable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {PausableUpgradeable as Pausable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {ReentrancyGuardUpgradeable as ReentrancyGuard} from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable as SafeERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ILP.sol";
import "./interfaces/IRewarder.sol";
import "./interfaces/IMasterMantis.sol";


contract MasterMantis is Initializable, Ownable, Pausable, ReentrancyGuard, IMasterMantis {
    using SafeERC20 for IERC20;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event UserVoted(address indexed user, UserVotePayload payload);
    event UserVotesReset(address indexed user);
    event GaugeUpdate(uint256 totalAssets, uint256 totalVotes);

    event GaugeIntervalUpdated(uint256 indexed gaugeUpdateInterval);
    event GaugeWeightUpdated(uint256 indexed gaugeAssetWeight, uint256 indexed gaugeVoteWeight);
    event MntPerBlockUpdated(uint256 indexed mntPerBlock);
    event veMntUpdated(address indexed veMnt);
    event PoolContractSet(address indexed pool, bool status);
    event RewarderSet(uint256 indexed pid, address indexed rewarder);

    struct UserInfo {
        uint256 amount;
        uint256 rewardFactor;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        address lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. MNT to distribute per block.
        uint256 lastRewardBlock; // Last block number that MNT distribution occurs.
        uint256 accMntPerShare; // Accumulated MNT per share, times 1e12. See below.
        uint256 totalRewardFactor;  // sum of user reward factors
        uint256 totalVotes;
    }

    struct VoteItem {
        uint256 pid;
        uint256 amount;
    }

    struct UserVotePayload {
        uint256 totalVotes;
        VoteItem[] votes;
    }

    IERC20 public mnt;
    // MNT tokens created per block.
    uint256 public mntPerBlock;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // pid -> rewarder
    mapping(uint256 => IRewarder) public rewarders;

    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The block number when MNT mining starts.
    uint256 public startBlock;

    address public veMnt;
    mapping(address => bool) public poolContracts;

    uint256 public gaugeUpdateInterval;
    uint256 public nextGaugeUpdate;
    uint256 public gaugeAssetWeight;
    uint256 public gaugeVoteWeight;

    mapping(address => uint256) public userVoteTotal;
    mapping(address => mapping(uint256 => uint256)) public userVoteItem;
    mapping(address => uint256[]) public userVotedPids;


    modifier onlyVeMnt() {
        require(veMnt == msg.sender, 'Not Allowed');
        _;
    }

    modifier onlyPoolContracts() {
        require(poolContracts[msg.sender], 'Not Allowed');
        _;
    }

    function initialize(address _mnt, address _veMnt, uint256 _mntPerBlock, uint256 _nextGaugeUpdate) external initializer {
        require(_mnt != address(0), "Cannot be zero address");
        require(_veMnt != address(0), "Cannot be zero address");
        require(_nextGaugeUpdate > block.timestamp + 15 days, "Gauge update in past");
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();
        mnt = IERC20(_mnt);
        veMnt = _veMnt;
        
        mntPerBlock = _mntPerBlock;
        startBlock = block.number;

        gaugeUpdateInterval = 15 days;
        nextGaugeUpdate = _nextGaugeUpdate;
        gaugeAssetWeight = 50;
        gaugeVoteWeight = 50;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setGaugeUpdateInterval(uint256 _gaugeUpdateInterval) external onlyOwner {
        require(_gaugeUpdateInterval > 0, "Cannot be 0");
        gaugeUpdateInterval = _gaugeUpdateInterval;
        emit GaugeIntervalUpdated(_gaugeUpdateInterval);
    }

    function setGaugeWeights(uint256 _gaugeAssetWeight, uint256 _gaugeVoteWeight) external onlyOwner {
        require(_gaugeAssetWeight + _gaugeVoteWeight == 100, "Incorrect sum");
        gaugeUpdate();
        gaugeAssetWeight = _gaugeAssetWeight;
        gaugeVoteWeight = _gaugeVoteWeight;
        emit GaugeWeightUpdated(_gaugeAssetWeight, _gaugeVoteWeight);
    }

    function setMntPerBlock(uint256 _mntPerBlock) external onlyOwner {
        massUpdatePools();
        mntPerBlock = _mntPerBlock;
        emit MntPerBlockUpdated(_mntPerBlock);
    }

    function setVeMnt(address _veMnt) external onlyOwner {
        require(_veMnt != address(0), "Cannot be zero address");
        massUpdatePools();
        veMnt = _veMnt;
        emit veMntUpdated(_veMnt);
    }

    function setPoolContract(address _poolContract, bool _status) external onlyOwner {
        require(_poolContract != address(0), "Cannot be zero address");
        poolContracts[_poolContract] = _status;
        emit PoolContractSet(_poolContract, _status);
    }

    function setRewarder(uint256 _pid, address _rewarder) external onlyOwner {
        rewarders[_pid] = IRewarder(_rewarder);
        emit RewarderSet(_pid, _rewarder);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function getTokenPid(address token) external view override returns (uint256) {
        uint256 poolSize = poolInfo.length;
        for (uint256 i = 0; i < poolSize; i++) {
            if (token == address(poolInfo[i].lpToken)) {
                return i;
            }
        }
        revert("Token not present");
    }

    function getRewarderToken(uint256 _pid) public view returns (address) {
        if (address(rewarders[_pid]) == address(0)) {
            return address(0);
        }
        return address(rewarders[_pid].rewardToken());
    }

    function gaugeUpdate() public {
        if (block.timestamp >= nextGaugeUpdate) {
            uint256 poolSize = poolInfo.length;
            uint256 totalAsset;
            uint256 totalVotes;
            uint256[] memory assetList = new uint256[](poolSize);
            uint256[] memory voteList = new uint256[](poolSize);
            for (uint256 pid = 0; pid < poolSize; pid++) {
                updatePool(pid);
                PoolInfo memory pool = poolInfo[pid];
                uint256 asset = ILP(pool.lpToken).getEmissionWeightage();
                uint256 votes = pool.totalVotes;
                assetList[pid] = asset;
                voteList[pid] = votes;
                totalAsset += asset;
                totalVotes += votes;
                ILP(pool.lpToken).resetPeriod();
            }
            for (uint256 pid = 0; pid < poolSize; pid++) {
                uint256 assetWeight = totalAsset > 0 ? gaugeAssetWeight * assetList[pid] * totalAllocPoint / totalAsset : 0;
                uint256 voteWeight = totalVotes > 0 ? gaugeVoteWeight * voteList[pid] * totalAllocPoint / totalVotes : 0;
                poolInfo[pid].allocPoint = (assetWeight + voteWeight) / 100;
            }
            nextGaugeUpdate = block.timestamp + gaugeUpdateInterval;
            emit GaugeUpdate(totalAsset, totalVotes);
        }
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, address _lpToken) external onlyOwner {
        massUpdatePools();
        uint256 poolSize = poolInfo.length;
        for (uint256 pid=0; pid < poolSize; pid++) {
            require(poolInfo[pid].lpToken != _lpToken, "Duplicate");
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint += _allocPoint;

        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accMntPerShare: 0,
            totalRewardFactor: 0,
            totalVotes: 0
        }));
    }

    // Update the given pool's MANTIS allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint) external onlyOwner {
        massUpdatePools();
        PoolInfo memory pool = poolInfo[_pid];
        totalAllocPoint = totalAllocPoint - pool.allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // View function to see pending MNTs on frontend.
    function pendingMnt(uint256 _pid, address _user) external view returns (uint256 pendingMNT, uint256 pendingReward) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 accMntPerShare = pool.accMntPerShare;
        uint256 totalRewardFactor = pool.totalRewardFactor;
        if (block.number > pool.lastRewardBlock && totalRewardFactor != 0) {
            uint256 multiplier = block.number - pool.lastRewardBlock;
            uint256 mntReward = multiplier * mntPerBlock * pool.allocPoint / totalAllocPoint;
            accMntPerShare += mntReward * 1e12 / totalRewardFactor;
        }
        pendingMNT = (user.rewardFactor * accMntPerShare / 1e12) - user.rewardDebt;
        if (address(rewarders[_pid]) != address(0)) {
            pendingReward = rewarders[_pid].pendingTokens(_user);
        }
    }

    function getCurrentUserRewardFactor(address _address, UserInfo memory user) public view returns (uint256) {
        uint256 veMntBalance = IERC20(veMnt).balanceOf(_address);
        return _getRewardFactor(user.amount, veMntBalance);
    }

    function _getRewardFactor(uint256 _amount, uint256 veMntBalance) internal pure returns (uint256) {
        return _amount * (1e12 + sqrt(veMntBalance)) / 1e12;
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 totalRewardFactor = pool.totalRewardFactor;
        if (totalRewardFactor == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number - pool.lastRewardBlock;
        uint256 mntReward = multiplier * mntPerBlock * pool.allocPoint / totalAllocPoint;
        pool.accMntPerShare += mntReward * 1e12 / totalRewardFactor;

        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for MNT allocation.
    function deposit(address _user, uint256 _pid, uint256 _amount) external override nonReentrant whenNotPaused {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        gaugeUpdate();
        updatePool(_pid);
        if (user.rewardFactor > 0) {
            uint256 pending = (user.rewardFactor * pool.accMntPerShare / 1e12) - user.rewardDebt;
            safeMntTransfer(_user, pending);
        }
        IERC20(pool.lpToken).safeTransferFrom(msg.sender, address(this), _amount);
        user.amount += _amount;
        uint256 newRewardFactor = getCurrentUserRewardFactor(_user, user);
        _updateUserPoolRewardFactor(pool, user, newRewardFactor);
        if (address(rewarders[_pid]) != address(0)) {
            rewarders[_pid].onMntReward(_user, user.amount);
        }
        emit Deposit(_user, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        gaugeUpdate();
        updatePool(_pid);
        uint256 pending = (user.rewardFactor * pool.accMntPerShare / 1e12) - user.rewardDebt;
        safeMntTransfer(msg.sender, pending);
        user.amount -= _amount;
        uint256 newRewardFactor = getCurrentUserRewardFactor(msg.sender, user);
        _updateUserPoolRewardFactor(pool, user, newRewardFactor);
        IERC20(pool.lpToken).safeTransfer(address(msg.sender), _amount);

        if (address(rewarders[_pid]) != address(0)) {
            rewarders[_pid].onMntReward(msg.sender, user.amount);
        }
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function withdrawFor(address recipient, uint256 _pid, uint256 _amount) external override onlyPoolContracts nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][recipient];
        require(user.amount >= _amount, "withdraw: not good");
        gaugeUpdate();
        updatePool(_pid);
        uint256 pending = (user.rewardFactor * pool.accMntPerShare / 1e12) - user.rewardDebt;
        safeMntTransfer(recipient, pending);
        user.amount -= _amount;
        uint256 newRewardFactor = getCurrentUserRewardFactor(recipient, user);
        _updateUserPoolRewardFactor(pool, user, newRewardFactor);
        IERC20(pool.lpToken).safeTransfer(address(msg.sender), _amount);

        if (address(rewarders[_pid]) != address(0)) {
            rewarders[_pid].onMntReward(recipient, user.amount);
        }
        emit Withdraw(recipient, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        IERC20(pool.lpToken).safeTransfer(msg.sender, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        pool.totalRewardFactor -= user.rewardFactor;
        user.rewardFactor = 0;
        if (address(rewarders[_pid]) != address(0)) {
            rewarders[_pid].onEmergencyWithdraw(msg.sender);
        }
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }

    function claim(uint256[] memory pids) external nonReentrant {
        gaugeUpdate();
        uint256 totalClaimAmount;
        for (uint i = 0; i < pids.length; i++) {
            uint256 _pid = pids[i];
            updatePool(_pid);
            PoolInfo memory pool = poolInfo[_pid];
            UserInfo storage user = userInfo[_pid][msg.sender];
            if (user.rewardFactor == 0) continue;
            uint256 totalRewards = (user.rewardFactor * pool.accMntPerShare / 1e12);
            uint256 pending = totalRewards - user.rewardDebt;
            user.rewardDebt = totalRewards;
            totalClaimAmount += pending;
            if (address(rewarders[_pid]) != address(0)) {
                rewarders[_pid].onMntReward(msg.sender, user.amount);
            }
        }
        safeMntTransfer(msg.sender, totalClaimAmount);
    }

    function updateRewardFactor(address _user) external override onlyVeMnt {
        uint256 veMntBalance = IERC20(veMnt).balanceOf(_user);
        uint256 totalClaimAmount;
        uint256 poolSize = poolInfo.length;
        for(uint i = 0; i < poolSize; i++) {
            UserInfo storage user = userInfo[i][_user];
            if (user.amount > 0) {
                PoolInfo storage pool = poolInfo[i];
                updatePool(i);
                totalClaimAmount += (user.rewardFactor * pool.accMntPerShare / 1e12) - user.rewardDebt;
                uint256 newRewardFactor = _getRewardFactor(user.amount, veMntBalance);
                _updateUserPoolRewardFactor(pool, user, newRewardFactor);
            }
        }
        safeMntTransfer(_user, totalClaimAmount);
    }

    function _updateUserPoolRewardFactor(PoolInfo storage pool, UserInfo storage user, uint256 newRewardFactor) internal {
        pool.totalRewardFactor = pool.totalRewardFactor - user.rewardFactor + newRewardFactor;
        user.rewardFactor = newRewardFactor;
        user.rewardDebt = newRewardFactor * pool.accMntPerShare / 1e12;
    }

    function vote(UserVotePayload calldata payload) external nonReentrant whenNotPaused {
        require(payload.totalVotes <= IERC20(veMnt).balanceOf(msg.sender), "Votes too high");
        gaugeUpdate();
        uint256 userVotedPidsSize = userVotedPids[msg.sender].length;
        for (uint256 i=0; i < userVotedPidsSize; i++) {
            uint256 pid = userVotedPids[msg.sender][i];
            poolInfo[pid].totalVotes -= userVoteItem[msg.sender][pid];
            delete userVoteItem[msg.sender][pid];
        }
        delete userVotedPids[msg.sender];
        uint256 voteAmount;
        uint256 numPids = payload.votes.length;
        for (uint256 i=0; i < numPids; i++) {
            uint256 amount = payload.votes[i].amount;
            require(amount > 0, "Cannot vote 0 amount");
            uint256 pid = payload.votes[i].pid;
            userVoteItem[msg.sender][pid] = amount;
            userVotedPids[msg.sender].push(pid);
            poolInfo[pid].totalVotes += amount;
            voteAmount += amount;
        }
        require(voteAmount == payload.totalVotes, "Vote Mismatch");
        userVoteTotal[msg.sender] = voteAmount;

        emit UserVoted(msg.sender, payload);
    }

    function resetVote(address user) external override onlyVeMnt {
        uint256 userVotedPidsSize = userVotedPids[user].length;
        for (uint256 i=0; i < userVotedPidsSize; i++) {
            uint256 pid = userVotedPids[user][i];
            poolInfo[pid].totalVotes -= userVoteItem[user][pid];
            delete userVoteItem[user][pid];
        }
        delete userVotedPids[user];
        userVoteTotal[user] = 0;
        emit UserVotesReset(user);
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function safeMntTransfer(address _to, uint256 _amount) internal {
        mnt.safeTransfer(_to, _amount);
    }

    function withdrawMnt() external onlyOwner {
        mnt.safeTransfer(msg.sender, mnt.balanceOf(address(this)));
    }
}