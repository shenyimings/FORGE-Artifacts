// SPDX-License-Identifier: WTFPL License
pragma solidity >=0.6.0;

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "@pancakeswap/pancake-swap-lib/contracts/utils/ReentrancyGuard.sol";

import "../interfaces/IMasterShepherd.sol";
import "../interfaces/IDummyMintable.sol";
import "../interfaces/IStrategyShepherd.sol";
import "../interfaces/ILamaHerd.sol";
import "./LlamaToken.sol";

contract MasterShepherdV2 is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of LAMAs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accLamaPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accLamaPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. LAMAs to distribute per block.
        uint256 lastRewardBlock; // Last block number that LAMAs distribution occurs.
        uint256 accLamaPerShare; // Accumulated LAMAs per share, times 1e12. See below.
        uint256 totalDepositAmt; // Current total deposit amount in this pool
        address strategy; // Address of StrategyShepherd
        uint16 depositFeeBP; // Deposit fee in basis points
    }

    address private dummyToken;

    IMasterShepherd public msV1;

    bool public msV1Linked;
    // msV1 linked pool id
    uint256 public msV1pid;
    // The LAMA TOKEN
    LlamaToken public lama;
    // referral
    address public lamaHerdAddr;

    // The maximum deposit fee allowed is 10%
    uint16 public MAX_DEPOSIT_FEE = 1000;
    // Deposit Fee address
    address public feeAddr;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // to check if a pool with a given IBEP20 already exists
    mapping(IBEP20 => bool) public tokenList;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    uint256 public stakePoolId = 0;
    // The block number when LAMA mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event MassHarvestStake(
        uint256[] poolsId,
        bool autoStake,
        uint256 extraStake
    );
    event EmergencyBEP20Drain(address token, address recipient, uint256 amount);

    constructor(
        address _msV1,
        address _lama,
        address _dummyToken,
        address _feeAddr
    ) public {
        msV1 = IMasterShepherd(_msV1);
        dummyToken = _dummyToken;
        lama = LlamaToken(_lama);

        feeAddr = _feeAddr;
    }

    modifier poolExists(uint256 _pid) {
        require(_pid < poolInfo.length, "validatePool: pool exists?");
        _;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function setStartBlock(uint256 _startBlock) public onlyOwner {
        require(startBlock == 0, "already started");
        startBlock = _startBlock;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // Adding the same LP token more than once is not allowed.
    function add(
        uint256 _allocPoint,
        IBEP20 _lpToken,
        uint16 _depositFeeBP,
        address _strategy,
        bool _withUpdate
    ) external onlyOwner {
        require(
            _depositFeeBP <= MAX_DEPOSIT_FEE,
            "add: invalid deposit fee basis points"
        );
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accLamaPerShare: 0,
                totalDepositAmt: 0,
                strategy: _strategy,
                depositFeeBP: _depositFeeBP
            })
        );

        tokenList[_lpToken] = true;
    }

    // Update the given pool's LAMA allocation point and deposit fee. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint16 _depositFeeBP,
        bool _withUpdate
    ) external onlyOwner poolExists(_pid) {
        require(
            _depositFeeBP <= MAX_DEPOSIT_FEE,
            "set: invalid deposit fee basis points"
        );
        if (_withUpdate) {
            massUpdatePools();
        }
        PoolInfo storage pool = poolInfo[_pid];
        totalAllocPoint = totalAllocPoint.sub(pool.allocPoint).add(_allocPoint);
        pool.allocPoint = _allocPoint;
        pool.depositFeeBP = _depositFeeBP;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        pure
        returns (uint256)
    {
        return _to.sub(_from);
    }

    // View function to see pending LAMAs on frontend.
    function pendingLama(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accLamaPerShare = pool.accLamaPerShare;
        uint256 lpTotal = pool.totalDepositAmt;
        if (block.number > pool.lastRewardBlock && lpTotal != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 lamaReward =
                multiplier.mul(lamaPerBlock()).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accLamaPerShare = accLamaPerShare.add(
                lamaReward.mul(1e12).div(lpTotal)
            );
        }
        return user.amount.mul(accLamaPerShare).div(1e12).sub(user.rewardDebt);
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
        internalUpdatePool(_pid);
        // withdraw all pending rewards from MasterShepherdV1
        msV1.withdraw(msV1pid, 0);
    }

    // Deposit LP tokens to MasterChef for LAMA allocation.
    function deposit(
        uint256 _pid,
        uint256 _amount,
        address _shepherd
    ) external nonReentrant poolExists(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        if (
            _amount > 0 && lamaHerdAddr != address(0) && _shepherd != address(0)
        ) {
            ILamaHerd(lamaHerdAddr).setShepherd(msg.sender, _shepherd);
        }

        if (user.amount > 0) {
            uint256 pending =
                user.amount.mul(pool.accLamaPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            if (pending > 0) {
                safeLamaTransfer(msg.sender, pending);
                payRefFees(pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            uint256 depositAmount = _amount;
            if (pool.depositFeeBP > 0) {
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(feeAddr, depositFee);
                depositAmount = _amount.sub(depositFee);
            }
            if (pool.strategy != address(0)) {
                pool.lpToken.safeIncreaseAllowance(
                    pool.strategy,
                    depositAmount
                );
                depositAmount = IStrategyShepherd(pool.strategy).deposit(
                    depositAmount,
                    msg.sender
                );
            }
            user.amount = user.amount.add(depositAmount);
            pool.totalDepositAmt = pool.totalDepositAmt.add(depositAmount);
        }
        user.rewardDebt = user.amount.mul(pool.accLamaPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterShepherd.
    function withdraw(uint256 _pid, uint256 _withdrawAmt)
        external
        nonReentrant
        poolExists(_pid)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (pool.strategy != address(0)) {
            require(
                IStrategyShepherd(pool.strategy).lpLockedTotal() > 0,
                "Total is 0"
            );
        }
        require(
            user.amount >= _withdrawAmt,
            "withdraw: more than user deposited"
        );

        updatePool(_pid);

        uint256 pending =
            user.amount.mul(pool.accLamaPerShare).div(1e12).sub(
                user.rewardDebt
            );
        if (pending > 0) {
            safeLamaTransfer(msg.sender, pending);
        }
        // Withdraw lp tokens
        if (_withdrawAmt > user.amount) {
            _withdrawAmt = user.amount;
        }

        if (_withdrawAmt > 0) {
            if (pool.strategy != address(0)) {
                uint256 withdrewAmount =
                    IStrategyShepherd(pool.strategy).withdraw(
                        _withdrawAmt,
                        msg.sender
                    );

                user.amount = withdrewAmount > user.amount
                    ? 0
                    : user.amount.sub(withdrewAmount);
            } else {
                user.amount = user.amount.sub(_withdrawAmt);
            }

            if (pool.totalDepositAmt < _withdrawAmt) {
                _withdrawAmt = pool.totalDepositAmt;
            }
            pool.totalDepositAmt = pool.totalDepositAmt.sub(_withdrawAmt);
            pool.lpToken.safeTransfer(address(msg.sender), _withdrawAmt);
        }
        user.rewardDebt = user.amount.mul(pool.accLamaPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _withdrawAmt);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;

        if (pool.strategy != address(0)) {
            IStrategyShepherd(pool.strategy).withdraw(amount, msg.sender);
        }

        user.amount = 0;
        user.rewardDebt = 0;
        pool.totalDepositAmt = pool.totalDepositAmt.sub(amount);
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe lama transfer function, just in case if rounding error causes pool not to have enough LAMAs.
    function safeLamaTransfer(address _to, uint256 _amount) internal {
        uint256 lamaBal = lama.balanceOf(address(this));
        if (_amount > lamaBal) {
            lama.transfer(_to, lamaBal);
        } else {
            lama.transfer(_to, _amount);
        }
    }

    // Update fee address by the previous address
    function setFeeAddr(address _feeAddr) external {
        require(msg.sender == feeAddr, "setFeeAddr: FORBIDDEN");
        feeAddr = _feeAddr;
    }

    function setLamaHerd(address _lamaHerd) external onlyOwner {
        lamaHerdAddr = _lamaHerd;
    }

    function linkToMSv1(uint256 _v1Pid) external onlyOwner {
        require(!msV1Linked, "Already linked");
        IDummyMintable token = IDummyMintable(dummyToken);
        uint256 amount = 1 ether;
        token.mint(amount);
        token.approve(address(msV1), amount);
        msV1.deposit(_v1Pid, amount);
        msV1Linked = true;
        msV1pid = _v1Pid;
    }

    /**
     ** @dev Harvest all pools where user has pending balance at the same time!  Be careful of gas spending!
     ** _ids[] list of pools id to harvest, [] to harvest all
     ** _autoStake if true all pending balance is staked To Stake Pool (stakePoolId)
     ** _extraStake if >0, desired user balance will be added to pending for stake too
     **/
    function massHarvestStake(
        uint256[] calldata _ids,
        bool _autoStake,
        uint256 _extraStake
    ) external nonReentrant {
        bool zeroLenght = _ids.length == 0;
        uint256 idxlength = _ids.length;

        //if empty check all
        if (zeroLenght) {
            idxlength = poolInfo.length;
        }

        uint256 totalPending = 0;
        uint256 accumulatedLamaReward = 0;

        for (uint256 i = 0; i < idxlength; i++) {
            uint256 pid = zeroLenght ? i : _ids[i];
            if (pid >= poolInfo.length) continue;

            accumulatedLamaReward = accumulatedLamaReward.add(
                internalUpdatePool(pid)
            );

            PoolInfo storage pool = poolInfo[pid];
            UserInfo storage user = userInfo[pid][msg.sender];
            uint256 pending =
                user.amount.mul(pool.accLamaPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            totalPending = totalPending.add(pending);
            user.rewardDebt = user.amount.mul(pool.accLamaPerShare).div(1e12);
        }

        // withdraw all pending rewards from MasterShepherdV1
        msV1.withdraw(msV1pid, 0);

        if (totalPending > 0) {
            payRefFees(totalPending);
            safeLamaTransfer(msg.sender, totalPending);

            if (_autoStake) {
                totalPending = totalPending.add(_extraStake);
                stake(totalPending);
            }
        }
        emit MassHarvestStake(_ids, _autoStake, _extraStake);
    }

    function stake(uint256 _amount) internal {
        if (_amount == 0) return;

        PoolInfo storage pool = poolInfo[stakePoolId];
        UserInfo storage user = userInfo[stakePoolId][msg.sender];

        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accLamaPerShare).div(1e12);
        emit Deposit(msg.sender, stakePoolId, _amount);
    }

    function setStakePoolId(uint256 _id) external onlyOwner {
        stakePoolId = _id;
    }

    // Owner can drain tokens that are sent here by mistake, excluding LAMA and staked LP tokens
    function drainStuckToken(address _token) external onlyOwner {
        require(_token != address(lama), "LAMA cannot be drained");
        IBEP20 token = IBEP20(_token);
        require(tokenList[token] == false, "Pool tokens cannot be drained");
        uint256 amount = token.balanceOf(address(this));
        token.transfer(msg.sender, amount);
        emit EmergencyBEP20Drain(address(token), msg.sender, amount);
    }

    function lamaPerBlock() public view returns (uint256) {
        return msV1.lamaPerBlock();
    }

    function internalUpdatePool(uint256 _pid) internal returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return 0;
        }
        uint256 lpTotal = pool.totalDepositAmt;
        if (lpTotal == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return 0;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 lamaReward =
            multiplier.mul(lamaPerBlock()).mul(pool.allocPoint).div(
                totalAllocPoint
            );

        pool.accLamaPerShare = pool.accLamaPerShare.add(
            lamaReward.mul(1e12).div(lpTotal)
        );
        pool.lastRewardBlock = block.number;
        return lamaReward;
    }

    function payRefFees(uint256 pending) internal {
        if (lamaHerdAddr != address(0)) {
            // 2% ref fees
            uint256 toShepherd = pending.mul(20).div(1000);
            ILamaHerd(lamaHerdAddr).payRefFees(msg.sender, toShepherd);
        }
    }
}
