// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./CSWToken.sol";


interface IShares {
    function sendTo(address to, uint amount) external;
    function updatePrice() external;
}

contract MasterChef is Ownable {
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint amount;         // How many LP tokens the user has provided.
        uint rewardKept;
        uint rewardDebt;     // Reward debt. See explanation below.
        uint rewardSharesKept;
        uint rewardSharesDebt;     // Reward debt. See explanation below.
        uint lastClaimedBlock;  // last powered Block
    }

    // Info of each pool.
    struct PoolInfo {
        uint amount;
        IERC20 lpToken;           // Address of LP token contract.
        uint allocPoint;       // How many allocation points assigned to this pool. SHs to distribute per block.
        uint lastRewardBlock;  // Last block number that Shs distribution occurs.
        uint accShPerPower;   // Accumulated Shs per share, times 1e12. See below.
        uint16 depositFeeBP;      // Deposit fee in basis points

        uint lastSharesRewardBlock;  // Last block number that Shs distribution occurs.
        uint accSharesPerPower;   // Accumulated Shs per share, times 1e12. See below.
    }

    CSWToken public sh;
    IShares public shares;
    // Dev address.
    address public devaddr;
    // SH tokens created per block.
    uint public shPerBlock = 1e18;

    // Deposit Fee address
    address public feeAddress;
    address public sharesAddress;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping (uint => mapping (address => UserInfo)) public userInfo;
    // Block number in which the user made token withdrawal from pool 0
    mapping (address => uint) public lastTokenWithdrawBlock;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint public totalAllocPoint = 0;
    // The block number when Sh mining starts.
    uint public startBlock;

    // Referrers
    mapping (address => address) public referrer;
    mapping (address => mapping (uint8 => uint)) public referrals;
    mapping (address => uint) public referrerReward;
    uint16[] public referrerRewardRate = [ 600, 300, 100 ];

    event Deposit(address indexed user, uint indexed pid, uint amount);
    event Withdraw(address indexed user, uint indexed pid, uint amount);
    event Claim(address indexed user, uint indexed pid, uint amount);
    event EmergencyWithdraw(address indexed user, uint indexed pid, uint256 amount);

    constructor (
        CSWToken _sh,
        IShares _shares,
        address _devaddr,
        address _feeAddress,
        address _sharesAddress,
        uint _startBlock,
        uint _shAllocPoint
    ) {
        require(_devaddr != address(0), "address can't be 0");
        require(_feeAddress != address(0), "address can't be 0");

        sh = _sh;
        shares = _shares;
        devaddr = _devaddr;
        feeAddress = _feeAddress;
        sharesAddress = _sharesAddress;
        startBlock = _startBlock;

        totalAllocPoint = _shAllocPoint;
        poolInfo.push(PoolInfo({
            amount: 0,
            lpToken: _sh,
            allocPoint: _shAllocPoint,
            lastRewardBlock: startBlock,
            accShPerPower: 0,
            depositFeeBP: 0,
            lastSharesRewardBlock: startBlock,
            accSharesPerPower: 0
        }));
    }

    function poolLength() external view returns (uint) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint _allocPoint, IERC20 _lpToken, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 500, "add: invalid deposit fee basis points");
        if (_withUpdate) {
            _massUpdatePools();
        }

        uint lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint += _allocPoint;
        poolInfo.push(PoolInfo({
            amount:0,
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accShPerPower: 0,
            depositFeeBP: _depositFeeBP,
            lastSharesRewardBlock: lastRewardBlock,
            accSharesPerPower: 0
        }));
    }

    // Update the given pool's SH allocation point and deposit fee. Can only be called by the owner.
    function set(uint _pid, uint _allocPoint, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 500, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            _massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    function setFeeAddress(address _feeAddress) public {
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        feeAddress = _feeAddress;
    }

    //Pancake has to add hidden dummy pools inorder to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint _shPerBlock) public onlyOwner {
        _massUpdatePools();
        shPerBlock = _shPerBlock;
    }

    // View function to see pending SHs on frontend.
    function pendingSh(uint _pid, address _user) external view returns (uint) {
        UserInfo storage user = userInfo[_pid][_user];
        return (user.rewardKept + _pendingSh(_pid, _user)) * (100 + aprMultiplier(_pid, _user)) / 100;
    }

    // View function to see pending SHs on frontend.
    function pendingShares(uint _pid, address _user) external view returns (uint) {
        UserInfo storage user = userInfo[_pid][_user];
        return user.rewardSharesKept + _pendingShares(_pid, _user);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function _massUpdatePools() internal {
        uint length = poolInfo.length;
        for (uint pid = 0; pid < length; ++pid) {
            _updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function _updatePool(uint _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        if (pool.amount == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            pool.lastSharesRewardBlock = block.number;
            return;
        }

        uint blockAmount = block.number - pool.lastRewardBlock;
        uint shReward = blockAmount * shPerBlock * pool.allocPoint / totalAllocPoint;
        sh.mint(devaddr, shReward / 10);
        sh.mint(address(this), shReward);
        pool.accShPerPower += shReward * 1e12 / pool.amount;
        pool.lastRewardBlock = block.number;

        uint sharesMultiplier = (block.number - pool.lastSharesRewardBlock) / 74000;
        if (sharesMultiplier > 0) {
            uint sharesReward = 1e18 * sharesMultiplier / 3;
            pool.accSharesPerPower += sharesReward * 1e12 / pool.amount;
            pool.lastSharesRewardBlock = block.number;
        }
    }

    // Deposit LP tokens to MasterChef for SH allocation.
    function deposit(uint _pid, uint _amount, address _ref) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        _updatePool(_pid);
        _keepPendingShAndShares(_pid, msg.sender);
        uint balance = pool.lpToken.balanceOf(address(this));
        
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            

            if(pool.depositFeeBP > 0){
                uint depositFee = _amount * pool.depositFeeBP / 10000;
                pool.lpToken.safeTransfer(feeAddress, depositFee * 3 / 5);
                pool.lpToken.safeTransfer(sharesAddress, depositFee * 2 / 5);
                shares.updatePrice();
                _amount -= depositFee;
            }

            uint amount = pool.lpToken.balanceOf(address(this)) - balance;
            
            user.amount += amount;
            pool.amount += amount;
        }

        user.rewardDebt = user.amount * pool.accShPerPower / 1e12;
        user.rewardSharesDebt = user.amount * pool.accSharesPerPower / 1e12;

        if (user.lastClaimedBlock == 0) {
            user.lastClaimedBlock = block.number;
        }

        if (_ref != address(0) && _ref != msg.sender && referrer[msg.sender] == address(0)) {
            referrer[msg.sender] = _ref;

            // direct ref
            referrals[_ref][0] += 1;
            referrals[_ref][1] += referrals[msg.sender][0];
            referrals[_ref][2] += referrals[msg.sender][1];

            // direct refs from direct ref
            address ref1 = referrer[_ref];
            if (ref1 != address(0)) {
                referrals[ref1][1] += 1;
                referrals[ref1][2] += referrals[msg.sender][0];

                // their refs
                address ref2 = referrer[ref1];
                if (ref2 != address(0)) {
                    referrals[ref2][2] += 1;
                }
            }
        }

        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint _pid, uint _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        _updatePool(_pid);
        _keepPendingShAndShares(_pid, msg.sender);

        if (_amount > 0) {
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
            user.amount -= _amount;
            pool.amount -= _amount;
        }

        user.rewardDebt = user.amount * pool.accShPerPower / 1e12;
        user.rewardSharesDebt = user.amount * pool.accSharesPerPower / 1e12;

        if (_pid == 0) {
            lastTokenWithdrawBlock[msg.sender] = block.number;
        }

        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERSHCY ONLY.
    function emergencyWithdraw(uint _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        pool.amount -= user.amount;
        uint amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardKept = 0;
        user.rewardSharesDebt = 0;
        user.rewardSharesKept = 0;

        if (_pid == 0) {
            lastTokenWithdrawBlock[msg.sender] = block.number;
        }

        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    function _rewardReferrers(uint baseAmount) internal {
        address ref = msg.sender;
        for (uint8 i = 0; i < referrerRewardRate.length; i++) {
            ref = referrer[ref];
            if (ref == address(0)) {
                break;
            }

            uint reward = baseAmount * referrerRewardRate[i] / 10000;
            sh.mint(ref, reward);
            referrerReward[ref] += reward;
        }
    }
    
    function aprMultiplier(uint _pid, address sender) public view returns (uint) {
        UserInfo storage user = userInfo[_pid][sender];
        uint multiplier = (block.number - Math.max(lastTokenWithdrawBlock[sender], user.lastClaimedBlock)) * 10 / 28800; //10% per 24 hours
        if (multiplier > 50) {
            multiplier = 50;
        }
        
        return multiplier;
    }

    function claim(uint _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        _updatePool(_pid);

        uint pending = user.rewardKept + _pendingSh(_pid, msg.sender);

        require(pending > 0, "Nothing to claim");

        _safeShTransfer(msg.sender, pending);
        _rewardReferrers(pending);

        uint multiplier = aprMultiplier(_pid, msg.sender);
        
        if (multiplier > 0) {
            sh.mint(msg.sender, pending * multiplier / 100);
        }

        emit Claim(msg.sender, _pid, pending + pending * multiplier / 100);

        user.rewardKept = 0;
        user.rewardDebt = user.amount * pool.accShPerPower / 1e12;
        user.lastClaimedBlock = block.number;
    }

    function reinvest(uint _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        _updatePool(_pid);

        uint pending = user.rewardKept + _pendingSh(_pid, msg.sender);

        require(pending > 0, "Nothing to claim");

        _rewardReferrers(pending);

        uint multiplier = aprMultiplier(_pid, msg.sender);
        
        if (multiplier > 0) {
            sh.mint(address(this), pending * multiplier / 100);
        }

        user.rewardKept = 0;
        user.rewardDebt = user.amount * pool.accShPerPower / 1e12;

        // adding to pool 0
        uint _amount = pending + pending * multiplier / 100;

        PoolInfo storage reinvestPool = poolInfo[0];
        UserInfo storage reinvestUser = userInfo[0][msg.sender];

        _updatePool(0);
        _keepPendingShAndShares(0, msg.sender);

        reinvestPool.amount += _amount;
        reinvestUser.amount += _amount;
        reinvestUser.rewardDebt = reinvestUser.amount * reinvestPool.accShPerPower / 1e12;
        reinvestUser.rewardSharesDebt = reinvestUser.amount * reinvestPool.accSharesPerPower / 1e12;
    }


    function claimShares(uint _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        _updatePool(_pid);

        uint pending = user.rewardSharesKept + _pendingShares(_pid, msg.sender);

        require(pending > 0, "Nothing to claim");

        shares.sendTo(msg.sender, pending);

        user.rewardSharesKept = 0;
        user.rewardSharesDebt = user.amount * pool.accSharesPerPower / 1e12;
    }

    function _keepPendingShAndShares(uint _pid, address _user) internal {
        UserInfo storage user = userInfo[_pid][_user];
        user.rewardKept += _pendingSh(_pid, _user);
        user.rewardSharesKept += _pendingShares(_pid, _user);
    }

    // DO NOT includes kept reward
    function _pendingSh(uint _pid, address _user) internal view returns (uint) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint accShPerPower = pool.accShPerPower;

        if (block.number > pool.lastRewardBlock && pool.amount != 0) {
            uint blockAmount = block.number - pool.lastRewardBlock;
            uint shReward = blockAmount * shPerBlock * pool.allocPoint / totalAllocPoint;
            accShPerPower += shReward * 1e12 / pool.amount;
        }

        return user.amount * accShPerPower / 1e12 - user.rewardDebt;
    }

    // DO NOT includes kept reward
    function _pendingShares(uint _pid, address _user) internal view returns (uint) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint accSharesPerPower = pool.accSharesPerPower;

        if (_pid > 2) {
            return 0;
        }

        if (block.number > pool.lastRewardBlock && pool.amount != 0) {
            uint blockAmount = (block.number - pool.lastSharesRewardBlock) / 74000;
            uint sharesReward = blockAmount * 1e18 / 3;
            accSharesPerPower += sharesReward * 1e12 / pool.amount;
        }

        return user.amount * accSharesPerPower / 1e12 - user.rewardSharesDebt;
    }

    // Safe sh transfer function, just in case if rounding error causes pool to not have enough SHs.
    function _safeShTransfer(address _to, uint _amount) internal {
        uint shBal = sh.balanceOf(address(this));
        if (_amount > shBal) {
            sh.transfer(_to, shBal);
        } else {
            sh.transfer(_to, _amount);
        }
    }
    
    
    function setShares(IShares _shContract) public onlyOwner {
        shares = _shContract;
    }
}
