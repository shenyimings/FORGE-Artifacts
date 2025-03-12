// SPDX-License-Identifier: MIT

/*------------------------------------------------------------------------------------------
████████████████████████████████████████████████████████████████████████████████████████████
█─▄─▄─█▄─▄▄▀█─▄▄─█▄─▄▄─█▄─▄█─▄▄▄─██▀▄─██▄─▄█████▄─▄▄─█▄─▄█▄─▀█▄─▄██▀▄─██▄─▀█▄─▄█─▄▄▄─█▄─▄▄─█
███─████─▄─▄█─██─██─▄▄▄██─██─███▀██─▀─███─██▀████─▄████─███─█▄▀─███─▀─███─█▄▀─██─███▀██─▄█▀█
▀▀▄▄▄▀▀▄▄▀▄▄▀▄▄▄▄▀▄▄▄▀▀▀▄▄▄▀▄▄▄▄▄▀▄▄▀▄▄▀▄▄▄▄▄▀▀▀▄▄▄▀▀▀▄▄▄▀▄▄▄▀▀▄▄▀▄▄▀▄▄▀▄▄▄▀▀▄▄▀▄▄▄▄▄▀▄▄▄▄▄▀
-------------------------------------------------------------------------------------------*/

pragma solidity =0.6.12;

import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "./libs/TimeLock.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./TropicalToken.sol";

/* TravelBureau is the travel agency of Tropical Finance. The agency guides you in your Tropical Travel and organizes your voyages
*/

contract TravelBureau is Ownable, ReentrancyGuard, TimeLock {
    using SafeBEP20 for IBEP20;
    using SafeMath for uint256;
    
    // Dev address.
    address public devAddress;
    // Deposit Fee address
    address public feeAddress;
    // TROPICAL tokens created per block.
    uint256 public tropicalPerBlock;
    // Bonus muliplier for early tropical makers.
    uint256 public constant BONUS_MULTIPLIER = 1; // in basis points, rate 1/10000

    // Initial emission rate
    uint256 public constant INITIAL_EMISSION_RATE = 15e18;
    // Minimum emission rate
    uint256 public constant MINIMUM_EMISSION_RATE = 2e18;
    // Reduce emission every 14,680 blocks ~ 24 hours.
    uint256 public constant EMISSION_REDUCTION_PERIOD_BLOCKS = 14680;
    // Emission reduction rate per period in basis points: 3%.
    uint256 public constant EMISSION_REDUCTION_RATE_PER_PERIOD = 300;
    // Last reduction period index
    uint256 public lastReductionPeriodIndex = 0;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when TROPICAL mining starts.
    uint256 public startBlock;

    bool _enableCheckSupplyReaching = true;
    
    // Info of each user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accTropicalPerShare;
        uint16 depositFeeBP;
    }
    
    //Decimals
    uint decimals = 1e18;
    
    // Tropical Token
    TropicalToken public tropical;
    
    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmissionRateUpdated(address indexed caller, uint256 previousAmount, uint256 newAmount);

    constructor(
        TropicalToken _tropical,
        uint256 _startBlock
    ) public {
        tropical = _tropical;
        startBlock = _startBlock;
        devAddress = msg.sender;
        feeAddress = msg.sender;
        tropicalPerBlock = INITIAL_EMISSION_RATE;
    }

    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }

    function enableCheckSupplyReaching(bool _enabled) public onlyOwner timeLock {
        _enableCheckSupplyReaching = _enabled;
    }

    // Safe Check DAIQUIRI supply reaching with a tolerance of 0.01%
    function checkSupplyReaching() public view returns (bool) {
        if(!_enableCheckSupplyReaching) return false;
        return tropical.totalSupplyAndBurnt() >= tropical.maximumSupply();
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IBEP20 _lpToken, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner timeLock {
        require(_depositFeeBP <= 400, "add: deposit fee exceeds limit");

        // Check Duplicated LP Address
        bool pass = true;
        for(uint i = 0; i < poolInfo.length; ++i) {
            if (address(poolInfo[i].lpToken) == address(_lpToken)) {
                pass = false;
                break;
            }
        }
        require(pass, "add: a Pool with this lp address already exists");

        require(poolInfo.length < 80, "add: Pool limit exceeded, no many pools can be added");

        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accTropicalPerShare: 0,
            depositFeeBP: _depositFeeBP
        }));

    }

    // Update the given pool's TROPICAL allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner timeLock {
        require(_depositFeeBP <= 400, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;

    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending TROPICALs on frontend.
    function pendingDaiquiri(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        if(checkSupplyReaching()) {
            return user.amount.mul(pool.accTropicalPerShare).div(decimals).sub(user.rewardDebt);
        }

        uint256 accTropicalPerShare = pool.accTropicalPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tropicalReward = multiplier.mul(tropicalPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accTropicalPerShare = accTropicalPerShare.add(tropicalReward.mul(decimals).div(lpSupply));
        }

        uint256 user_amount = user.amount.mul(accTropicalPerShare).div(decimals).sub(user.rewardDebt);

        return user_amount;
    }

    // Update reward variables for all pools. Be careful of gas spending!
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

        if(checkSupplyReaching()) {
            for (uint256 pid = 0; pid < poolInfo.length; ++pid) {
                poolInfo[pid].allocPoint = 0;
            }
            return;
        }

        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tropicalReward = multiplier.mul(tropicalPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        tropical.mint(devAddress, tropicalReward.div(10));
        tropical.mint(address(this), tropicalReward);
        pool.accTropicalPerShare = pool.accTropicalPerShare.add(tropicalReward.mul(decimals).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for TROPICAL allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        require(block.number >= startBlock, "TravelBureau::FairLaunch: Deposits are available only after mining starts");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        uint256 oldUserAmount = user.amount;
        
        if (oldUserAmount > 0) {
            uint256 pending = oldUserAmount.mul(pool.accTropicalPerShare).div(decimals).sub(user.rewardDebt);
            if (pending > 0) {
                safeTropicalTransfer(msg.sender, pending);
            }
        }
        
        if (_amount > 0) {
            //Deflationary tokens fix
            uint256 previousAmount = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            uint256 afterAmount =  pool.lpToken.balanceOf(address(this));
            _amount = afterAmount.sub(previousAmount);

            if (pool.depositFeeBP > 0) {
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(feeAddress, depositFee);
                user.amount = user.amount.add(_amount).sub(depositFee);
            }
            else { user.amount = user.amount.add(_amount); }

        }
        user.rewardDebt = user.amount.mul(pool.accTropicalPerShare).div(decimals);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = 0;
        if(user.amount > 0) { pending = user.amount.mul(pool.accTropicalPerShare).div(decimals).sub(user.rewardDebt); }

        if (pending > 0) {
            // Add Pending/Harvest amount to final amount, preventing antiBot double action.
            if(address(pool.lpToken) == address(tropical)) { _amount = _amount.add(pending); }
            else { safeTropicalTransfer(msg.sender, pending); }
        }
        if (_amount > 0) {
            // Use SafeTropicalTransfer for DAIQUIRI
            if(address(pool.lpToken) == address(tropical)) {
                _amount = _amount.sub(pending);
                user.amount = user.amount.sub(_amount);
                safeTropicalTransfer(msg.sender, _amount.add(pending)); 
            }
            else {
                user.amount = user.amount.sub(_amount);
                pool.lpToken.safeTransfer(address(msg.sender), _amount); 
            }
        }
        user.rewardDebt = user.amount.mul(pool.accTropicalPerShare).div(decimals);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe tropical transfer function, just in case if rounding error causes pool to not have enough TROPICALs.
    function safeTropicalTransfer(address _to, uint256 _amount) internal {
        uint256 tropicalBal = tropical.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > tropicalBal) {
            transferSuccess = tropical.transfer(_to, tropicalBal);
        } else {
            transferSuccess = tropical.transfer(_to, _amount);
        }
        require(transferSuccess, "safeTropicalTransfer: Transfer failed");
    }

    // Update dev address by the previous dev.
    function setDevAddress(address _devAddress) public timeLock {
        require(msg.sender == devAddress, "setDevAddress: FORBIDDEN");
        devAddress = _devAddress;
    }

    function setFeeAddress(address _feeAddress) public timeLock {
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        feeAddress = _feeAddress;
    }

    // Dynamic emission rate reduction
    function updateEmissionRate() public {
        require(block.number >= startBlock, "updateEmissionRate: Can only be called after mining starts");
        require(tropicalPerBlock > MINIMUM_EMISSION_RATE, "updateEmissionRate: Emission rate has reached the minimum allowed");

        uint256 currentIndex = block.number.sub(startBlock).div(EMISSION_REDUCTION_PERIOD_BLOCKS);
        if (currentIndex <= lastReductionPeriodIndex) { return; }

        uint256 newEmissionRate = tropicalPerBlock;
        for (uint256 index = lastReductionPeriodIndex; index < currentIndex; ++index) {
            newEmissionRate = newEmissionRate.mul(1e4 - EMISSION_REDUCTION_RATE_PER_PERIOD).div(1e4);
        }

        newEmissionRate = newEmissionRate < MINIMUM_EMISSION_RATE ? MINIMUM_EMISSION_RATE : newEmissionRate;
        if (newEmissionRate >= tropicalPerBlock) { return; }

        massUpdatePools();
        lastReductionPeriodIndex = currentIndex;
        uint256 previousEmissionRate = tropicalPerBlock;
        tropicalPerBlock = newEmissionRate;
        emit EmissionRateUpdated(msg.sender, previousEmissionRate, newEmissionRate);
    }
    
}
