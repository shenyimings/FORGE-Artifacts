// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/*

    ███████╗██████╗  █████╗ ███╗   ██╗██╗  ██╗███████╗███╗   ██╗███████╗████████╗███████╗██╗███╗   ██╗
    ██╔════╝██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝██╔════╝████╗  ██║██╔════╝╚══██╔══╝██╔════╝██║████╗  ██║
    █████╗  ██████╔╝███████║██╔██╗ ██║█████╔╝ █████╗  ██╔██╗ ██║███████╗   ██║   █████╗  ██║██╔██╗ ██║
    ██╔══╝  ██╔══██╗██╔══██║██║╚██╗██║██╔═██╗ ██╔══╝  ██║╚██╗██║╚════██║   ██║   ██╔══╝  ██║██║╚██╗██║
    ██║     ██║  ██║██║  ██║██║ ╚████║██║  ██╗███████╗██║ ╚████║███████║   ██║   ███████╗██║██║ ╚████║
    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚══════╝╚═╝╚═╝  ╚═══╝
                                                                      
    Website: https://frankenstein.finance/
    twitter: https://twitter.com/FrankenDefi
*/

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IReferrals.sol";
import "./interfaces/IHelp.sol";

// Mint
abstract contract NativeToken is ERC20 {
    function mint(address _to, uint256 _amount) public virtual;
}

contract MasterChef is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 shares; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.

        // We do some fancy math here. Basically, any point in time, the amount of AUTO
        // entitled to a user but is pending to be distributed is:
        //
        //   amount = user.shares / sharesTotal * wantLockedTotal
        //   pending reward = (amount * pool.accNATIVEPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws want tokens to a pool. Here's what happens:
        //   1. The pool's `accNATIVEPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    struct PoolInfo {
        IERC20 want; // Address of the want token.
        uint256 allocPoint; // How many allocation points assigned to this pool. NATIVE to distribute per block.
        uint256 lastRewardBlock; // Last block number that NATIVE distribution occurs.
        uint256 accNATIVEPerShare; // Accumulated NATIVE per share, times 1e12. See below.
        address strat; // Strategy address that will auto compound want tokens
    }

    // Token address
    address public NATIVE;
    // LotteryNFT address
    address public lottery;
    // Referrals Interface
    IReferrals public referrals;
    // Owner reward per block: 10%
    uint256 public ownerNATIVEReward = 1000;
    // Lottery reward per block: 1%
    uint256 public lotteryNATIVEReward = 100;
    // Referrals reward per block: 0.25%
    uint256 percReferrals = 25;
    // NATIVE tokens created per block
    uint256 public NATIVEPerBlock;
    // Native total supply: 2 mil = 2000000e18
    uint256 public NATIVEMaxSupply = 2000000e18;
    // Approx Monday, 17 May 2021 19:00:00
    uint256 public startTime = 1621278000;
    // Counter StartTime
    uint256 public startTimeCount = 0;
    
    /*For BSC*/
    // Natives per block: (0.190496575342466 - owner 10% - lottery 1% - referrals 0.25%)
    uint256 public NATIVEPerBlockBSC = 171232876712329000;

    /*For FTM*/
    // Natives per block: (0.063498858447488 - owner 10% - lottery 1% - referrals 0.25%)
    uint256 public NATIVEPerBlockFTM = 57077625570776330;

    PoolInfo[] public poolInfo; // Info of each pool.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo; // Info of each user that stakes LP tokens.
    uint256 public totalAllocPoint = 0; // Total allocation points. Must be the sum of all allocation points in all pools.

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(address _lottery, address _token, IReferrals _referrals, uint _type) public {
        NATIVE = _token;
        lottery = _lottery;
        referrals = _referrals;
        if(_type == 0){
            NATIVEPerBlock = NATIVEPerBlockBSC;
        } else {
            NATIVEPerBlock = NATIVEPerBlockFTM;
        }
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do. (Only if want tokens are stored here.)
    function add(
        uint256 _allocPoint,
        IERC20 _want,
        bool _withUpdate,
        address _strat
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                want: _want,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accNATIVEPerShare: 0,
                strat: _strat
            })
        );
    }

    // Update the given pool's NATIVE allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (IERC20(NATIVE).totalSupply() >= NATIVEMaxSupply) {
            return 0;
        }
        return _to.sub(_from);
    }

    // View function to see pending AUTO on frontend.
    function pendingNATIVE(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accNATIVEPerShare = pool.accNATIVEPerShare;
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        if (block.number > pool.lastRewardBlock && sharesTotal != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 NATIVEReward = multiplier.mul(NATIVEPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accNATIVEPerShare = accNATIVEPerShare.add(NATIVEReward.mul(1e12).div(sharesTotal));
        }
        return user.shares.mul(accNATIVEPerShare).div(1e12).sub(user.rewardDebt);
    }

    // View function to see staked Want tokens on frontend.
    function stakedWantTokens(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strat).wantLockedTotal();
        if (sharesTotal == 0) {
            return 0;
        }
        return user.shares.mul(wantLockedTotal).div(sharesTotal);
    }

    // View the function to see the tokens bet on the strategy.
    function getWantLockedTotal(uint256 _pid)
        external
        view
        returns (uint256)
    {
        return IStrategy(poolInfo[_pid].strat).wantLockedTotal();
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
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        if (sharesTotal == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        if (multiplier <= 0) {
            return;
        }
        uint256 NATIVEReward =
            multiplier.mul(NATIVEPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );

        NativeToken(NATIVE).mint(
            owner(),
            NATIVEReward.mul(ownerNATIVEReward).div(10000)
        );

        NativeToken(NATIVE).mint(
            lottery,
            NATIVEReward.mul(lotteryNATIVEReward).div(10000)
        );

        NativeToken(NATIVE).mint(address(this), NATIVEReward);

        pool.accNATIVEPerShare = pool.accNATIVEPerShare.add(
            NATIVEReward.mul(1e12).div(sharesTotal)
        );
        pool.lastRewardBlock = block.number;
    }

    // function to harvest all pools
    function harvestAll() public nonReentrant {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            UserInfo storage user = userInfo[pid][msg.sender];
            if (user.shares > 0) {
                updatePool(pid);
                uint256 pending = user.shares.mul(pool.accNATIVEPerShare).div(1e12).sub(user.rewardDebt);
                if (pending > 0) {
                    safeNATIVETransfer(msg.sender, pending);
                    uint256 _amountSponsor = pending.mul(percReferrals).div(10000);
                    NativeToken(NATIVE).mint(referrals.getSponsor(msg.sender), _amountSponsor);
                    referrals.updateEarn(referrals.getSponsor(msg.sender), _amountSponsor);
                }
                user.rewardDebt = user.shares.mul(pool.accNATIVEPerShare).div(1e12);
            }
        }
    }

    // Want tokens moved from user -> AUTOFarm (AUTO allocation) -> Strat (compounding)
    function deposit(uint256 _pid, uint256 _wantAmt, address _sponsor) public nonReentrant {
        require(block.timestamp > startTime, "!startTime");
        if(referrals.isMember(msg.sender) == false){
            if(referrals.isMember(_sponsor) == false){
                _sponsor = referrals.membersList(0);
            }
            referrals.addMember(msg.sender, _sponsor);
        }

        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.shares > 0) {
            uint256 pending =
                user.shares.mul(pool.accNATIVEPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            if (pending > 0) {
                safeNATIVETransfer(msg.sender, pending);
                uint256 _amountSponsor = pending.mul(percReferrals).div(10000);
                NativeToken(NATIVE).mint(referrals.getSponsor(msg.sender), _amountSponsor);
                referrals.updateEarn(referrals.getSponsor(msg.sender), _amountSponsor);
            }
        }
        if (_wantAmt > 0) {
            pool.want.safeTransferFrom(
                address(msg.sender),
                address(this),
                _wantAmt
            );

            pool.want.safeIncreaseAllowance(pool.strat, _wantAmt);
            uint256 sharesAdded =
                IStrategy(poolInfo[_pid].strat).deposit(msg.sender, _wantAmt);
            user.shares = user.shares.add(sharesAdded);
        }
        user.rewardDebt = user.shares.mul(pool.accNATIVEPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _wantAmt);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _wantAmt) public nonReentrant {
        updatePool(_pid);

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strat).wantLockedTotal();
        uint256 sharesTotal = IStrategy(poolInfo[_pid].strat).sharesTotal();

        require(user.shares > 0, "user.shares is 0");
        require(sharesTotal > 0, "sharesTotal is 0");

        // Withdraw pending AUTO
        uint256 pending =
            user.shares.mul(pool.accNATIVEPerShare).div(1e12).sub(
                user.rewardDebt
            );
        if (pending > 0) {
            safeNATIVETransfer(msg.sender, pending);
            uint256 _amountSponsor = pending.mul(percReferrals).div(10000);
            NativeToken(NATIVE).mint(referrals.getSponsor(msg.sender), _amountSponsor);
            referrals.updateEarn(referrals.getSponsor(msg.sender), _amountSponsor);
        }

        // Withdraw want tokens
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);
        if (_wantAmt > amount) {
            _wantAmt = amount;
        }
        if (_wantAmt > 0) {
            uint256 sharesRemoved =
                IStrategy(poolInfo[_pid].strat).withdraw(msg.sender, _wantAmt);

            if (sharesRemoved > user.shares) {
                user.shares = 0;
            } else {
                user.shares = user.shares.sub(sharesRemoved);
            }

            uint256 wantBal = IERC20(pool.want).balanceOf(address(this));
            if (wantBal < _wantAmt) {
                _wantAmt = wantBal;
            }
            pool.want.safeTransfer(address(msg.sender), _wantAmt);
        }
        user.rewardDebt = user.shares.mul(pool.accNATIVEPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _wantAmt);
    }

    function withdrawAll(uint256 _pid) public nonReentrant {
        withdraw(_pid, uint256(-1));
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strat).wantLockedTotal();
        uint256 sharesTotal = IStrategy(poolInfo[_pid].strat).sharesTotal();
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);

        IStrategy(poolInfo[_pid].strat).withdraw(msg.sender, amount);

        pool.want.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
        user.shares = 0;
        user.rewardDebt = 0;
    }

    // Safe AUTO transfer function, just in case if rounding error causes pool to not have enough
    function safeNATIVETransfer(address _to, uint256 _NATIVEAmt) internal {
        uint256 NATIVEBal = IERC20(NATIVE).balanceOf(address(this));
        if (_NATIVEAmt > NATIVEBal) {
            IERC20(NATIVE).transfer(_to, NATIVEBal);
        } else {
            IERC20(NATIVE).transfer(_to, _NATIVEAmt);
        }
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount)
        public
        onlyOwner
    {
        require(_token != NATIVE, "!safe");
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function inCaseOfRequiringChangeOfInitialDate(uint256 _newDate)
        public
        onlyOwner
    {
        require(startTimeCount == 0, "!inCaseOfRequiringChangeOfInitialDate");
        startTime = _newDate;
        startTimeCount = 1;
    }    

}