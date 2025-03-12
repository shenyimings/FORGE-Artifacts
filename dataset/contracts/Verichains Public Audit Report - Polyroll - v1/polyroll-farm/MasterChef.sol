// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/ReentrancyGuard.sol";

import "./RollToken.sol";
import "./Prize.sol";
import "./libs/IReferral.sol";
import "./libs/IRandGen.sol";

// MasterChef is the master of Roll. He can make Roll and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once Roll is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of ROLLs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accRollPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accRollPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;             // Address of LP token contract.
        uint256 allocPoint;         // How many allocation points assigned to this pool. ROLLs to distribute per block.
        uint256 lastRewardBlock;    // Last block number that ROLLs distribution occurs.
        uint256 accRollPerShare;    // Accumulated ROLLs per share, times 1e18. See below.
        uint16 depositFeeBP;        // Deposit fee in basis points
        uint32 prizeRound;          // Number of lottery rounds completed
        uint256 prizeTotal;         // Total lottery prize in pool.
        uint256 lastPrizeBlock;     // Last block number where lottery prize is distributed.
        address[] players;          // List of addresses of lottery players.
        uint256[] playerStakes;     // List of player's stakes a.k.a. player's contribution to lottery pool.
        mapping(address => uint256) playerIds; // Mapping of address to indexes. Used to check if player has participated before this round.
    }

    // The ROLL TOKEN!
    RollToken public roll;
    address public devAddress;
    address public feeAddress;

    // Initial emission rate: 50 ROLL per block.
    uint256 public constant INITIAL_EMISSION_RATE = 50 ether;
    // Target emission rate: 5 ROLL per block.
    uint256 public constant FINAL_EMISSION_RATE = 5 ether;
    // Reduce emission every 43200 blocks ~24 hours.
    uint256 public constant EMISSION_REDUCTION_PERIOD_BLOCKS = 43200;
    // Emission reduction rate per period in basis points: 2%.
    uint256 public constant EMISSION_REDUCTION_RATE_PER_PERIOD = 200;
    // Last reduction period index
    uint256 public lastReductionPeriodIndex = 0;
    // ROLL tokens created per block.
    uint256 public rollPerBlock = INITIAL_EMISSION_RATE;

    // Store info of each pool in mapping
    uint256 poolInfoLength;
    mapping(uint256 => PoolInfo) public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when ROLL mining starts.
    uint256 public startBlock;

    // Roll referral contract address.
    IReferral public referral;
    // Referral commission rate: 1%.
    uint16 public referralCommissionRate = 100;
    // Maximum referral commission rate: 5%.
    uint16 public constant MAXIMUM_REFERRAL_COMMISSION_RATE = 500;

    // Contract for holding lottery prizes
    Prize public prize;
    // Roll referral contract address.
    IRandGen public randGen;
    // Mapping to map Chainlink VRF requestId to poolId.
    mapping(bytes32 => uint256) public requestIds;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event UpdateEmissionRate(address indexed user, uint256 rollPerBlock);
    event ReferralCommissionPaid(address indexed user, address indexed referrer, uint256 commissionAmount);
    event lotteryDrawn(uint256 indexed pid, uint256 prizeTotal, uint32 prizeRound);
    event lotterySettled(uint256 indexed pid, uint256 prizeTotal, uint32 prizeRound);

    constructor(
        RollToken _roll,
        Prize _prize,
        IReferral _referral,
        IRandGen _randGen,
        uint256 _startBlock,
        address _devAddress,
        address _feeAddress
    ) public {
        roll = _roll;
        prize = _prize;
        referral = _referral;
        randGen = _randGen;
        startBlock = _startBlock;
        devAddress = _devAddress;
        feeAddress = _feeAddress;
    }

    function poolLength() external view returns (uint256) {
        return poolInfoLength;
    }

    mapping(IERC20 => bool) public poolExistence;
    modifier nonDuplicated(IERC20 _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
        _;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _lpToken, uint16 _depositFeeBP) external onlyOwner nonDuplicated(_lpToken) {
        require(_depositFeeBP <= 10000, "add: invalid deposit fee basis points");
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolExistence[_lpToken] = true;

        PoolInfo storage pool = poolInfo[poolInfoLength];
        pool.lpToken = _lpToken;
        pool.allocPoint = _allocPoint;
        pool.lastRewardBlock = lastRewardBlock;
        pool.depositFeeBP = _depositFeeBP;
        pool.lastPrizeBlock = lastRewardBlock;
        poolInfoLength++;
    }

    // Update the given pool's ROLL allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP) external onlyOwner {
        require(_depositFeeBP <= 10000, "set: invalid deposit fee basis points");
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from);
    }

    // View function to see pending ROLLs on frontend.
    function pendingRoll(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRollPerShare = pool.accRollPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 rollReward = multiplier.mul(rollPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accRollPerShare = accRollPerShare.add(rollReward.mul(1e18).div(lpSupply));
        }
        return user.amount.mul(accRollPerShare).div(1e18).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        for (uint256 pid = 0; pid < poolInfoLength; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 rollReward = multiplier.mul(rollPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        roll.mint(devAddress, rollReward.div(10));
        roll.mint(address(this), rollReward);
        pool.accRollPerShare = pool.accRollPerShare.add(rollReward.mul(1e18).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for ROLL allocation.
    function deposit(uint256 _pid, uint256 _amount, address _referrer) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        // Compute deposit fee beforehand to save on gas
        uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);

        updatePool(_pid);
        if (_amount > 0 && address(referral) != address(0) && _referrer != address(0) && _referrer != msg.sender) {
            referral.recordReferral(msg.sender, _referrer);
        }
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accRollPerShare).div(1e18).sub(user.rewardDebt);
            if (pending > 0) {
                safeRollTransfer(msg.sender, pending);
                payReferralCommission(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            if (pool.depositFeeBP > 0) {
                // Transfer 75% of deposit fee to Fee Address for token buyback and Polyroll games
                pool.lpToken.safeTransfer(feeAddress, depositFee.mul(3).div(4));

                // Transfer 25% of deposit fee to Prize contract
                pool.lpToken.safeTransfer(address(prize), depositFee.div(4));
                pool.prizeTotal = pool.prizeTotal.add(depositFee.div(4));

                // Update user's deposit after subtracting fee
                user.amount = user.amount.add(_amount).sub(depositFee);

                // Register player in lottery.
                if (pool.players.length == 0) {
                    // If player is new and is first player, add player to players list, add depositFee to playerStakes list, and set playerId to map to 0.
                    pool.players.push(msg.sender);
                    pool.playerStakes.push(depositFee.div(4));
                    pool.playerIds[msg.sender] = 0;
                } else if (pool.players[pool.playerIds[msg.sender]] != msg.sender) {
                    // If player is new, add player to players list, add depositFee to playerStakes list, and set playerId to map to index where player is recorded.
                    pool.players.push(msg.sender);
                    pool.playerStakes.push(depositFee.div(4));
                    pool.playerIds[msg.sender] = pool.players.length - 1;
                } else {
                    // If player is not new, add depositFee to playerStakes record.
                    pool.playerStakes[pool.playerIds[msg.sender]] = pool.playerStakes[pool.playerIds[msg.sender]].add(depositFee.div(4));
                }
            } else {
                user.amount = user.amount.add(_amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accRollPerShare).div(1e18);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accRollPerShare).div(1e18).sub(user.rewardDebt);
        if (pending > 0) {
            safeRollTransfer(msg.sender, pending);
            payReferralCommission(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accRollPerShare).div(1e18);
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

    // Safe roll transfer function, just in case if rounding error causes pool to not have enough ROLL.
    function safeRollTransfer(address _to, uint256 _amount) internal {
        uint256 rollBal = roll.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > rollBal) {
            transferSuccess = roll.transfer(_to, rollBal);
        } else {
            transferSuccess = roll.transfer(_to, _amount);
        }
        require(transferSuccess, "safeRollTransfer: Transfer failed");
    }

    // Update dev address by the previous dev.
    function setDevAddress(address _devAddress) external onlyOwner {
        devAddress = _devAddress;
    }

    function setFeeAddress(address _feeAddress) external onlyOwner {
        feeAddress = _feeAddress;
    }

    function setRandGen(IRandGen _randGen) external onlyOwner {
        randGen = _randGen;
    }
    
    // Reduce emission rate every day. This function can be called publicly.
    function updateEmissionRate() public {
        require(block.number > startBlock, "updateEmissionRate: Can only be called after mining starts");
        require(rollPerBlock > FINAL_EMISSION_RATE, "updateEmissionRate: Emission rate has reached FINAL_EMISSION_RATE already");

        // currentIndex is roughly equal to number of days elapsed since startBlock
        uint256 currentIndex = block.number.sub(startBlock).div(EMISSION_REDUCTION_PERIOD_BLOCKS);
        require(currentIndex > lastReductionPeriodIndex, "updateEmissionRate: Wait at least 1 day after previous update.");

        // Compute new emission rate
        uint256 newEmissionRate = rollPerBlock;
        for (uint256 index = lastReductionPeriodIndex; index < currentIndex; ++index) {
            newEmissionRate = newEmissionRate.mul(1e4 - EMISSION_REDUCTION_RATE_PER_PERIOD).div(1e4);
        }
        newEmissionRate = newEmissionRate < FINAL_EMISSION_RATE ? FINAL_EMISSION_RATE : newEmissionRate;
        require(newEmissionRate < rollPerBlock, "updateEmissionRate: New emission rate must be less than current emission rate.");

        massUpdatePools();
        lastReductionPeriodIndex = currentIndex;
        rollPerBlock = newEmissionRate;
        emit UpdateEmissionRate(msg.sender, rollPerBlock);
    }

    // Update the referral contract address by the owner
    function setReferralAddress(IReferral _referral) external onlyOwner {
        referral = _referral;
    }

    // Update referral commission rate by the owner
    function setReferralCommissionRate(uint16 _referralCommissionRate) external onlyOwner {
        require(_referralCommissionRate <= MAXIMUM_REFERRAL_COMMISSION_RATE, "setReferralCommissionRate: invalid referral commission rate basis points");
        referralCommissionRate = _referralCommissionRate;
    }

    // Pay referral commission to the referrer who referred this user.
    function payReferralCommission(address _user, uint256 _pending) internal {
        if (address(referral) != address(0) && referralCommissionRate > 0) {
            address referrer = referral.getReferrer(_user);
            uint256 commissionAmount = _pending.mul(referralCommissionRate).div(10000);

            if (referrer != address(0) && commissionAmount > 0) {
                roll.mint(_user, commissionAmount);
                roll.mint(referrer, commissionAmount);
                emit ReferralCommissionPaid(_user, referrer, commissionAmount);
            }
        }
    }

    // Update the startBlock if farming has not started yet
    function updateStartBlock(uint256 _startBlock) external onlyOwner {
	    require(startBlock > block.number, "updateStartBlock: Farm already started.");
        startBlock = _startBlock;
        // Update lastRewardBlock of all pools
        for (uint256 pid = 0; pid < poolInfoLength; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            pool.lastRewardBlock = _startBlock;
        }
    }

    // View function to see prizeTotal for a given pool.
    function getPrizeTotal(uint256 _pid) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        return pool.prizeTotal;
    }

    // View function to see number of players in pool
    function getPrizeRound(uint256 _pid) external view returns (uint32) {
        PoolInfo storage pool = poolInfo[_pid];
        return pool.prizeRound;
    }

    // View function to see current number of players in pool
    function getPlayerCount(uint256 _pid) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        return pool.players.length;
    }

    // Draw random number from Chainlink VRF.
    function drawLottery(uint256 _pid) external {
        require(msg.sender == devAddress, "Only dev can call drawWinner to prevent spamming Chainlink oracle.");
        PoolInfo storage pool = poolInfo[_pid];

        // require(block.number.sub(pool.lastPrizeBlock) >= 40000, "Wait at least 40000 blocks after last call.");
        require(pool.players.length > 0, "There must be at least 1 player.");
        require(pool.prizeTotal > 0, "Lottery pot must be greater than 0.");

        // Request random number from Chainlink VRF.
        bytes32 requestId = randGen.getRandomNumber(_pid);

        // Store requestId in mapping to handle simultaneous requests.
        requestIds[requestId] = _pid;

        emit lotterySettled(_pid, pool.prizeTotal, pool.prizeRound);
    }

    // Callback function called by Chainlink via RandGen contract to send random number and declare winners for a given pool.
    function settleLottery(bytes32 requestId, uint256 randomNumber) external nonReentrant {
        require(msg.sender == address(randGen), "Only RandGen contract can call this.");

        uint256 pid = requestIds[requestId];
        PoolInfo storage pool = poolInfo[pid];
        IERC20 lpToken = pool.lpToken;

        // Pick grand prize winner, weighted by player stakes.
        uint256 winnerStake = randomNumber.mod(pool.prizeTotal);
        uint256 winnerIndex = 0;
        while (winnerStake > pool.playerStakes[winnerIndex]) {
            winnerStake = winnerStake.sub(pool.playerStakes[winnerIndex]);
            winnerIndex += 1;
        }

        // Get actual token balance in Prize contract to prevent overflow issues.
        uint prizeTotal = lpToken.balanceOf(address(prize));

        // Send grand prize to winner: 50% of prize pool is awarded to grand prize winner
        prize.transferPrize(address(pool.players[winnerIndex]), lpToken, prizeTotal.div(2));

        // Consolation prizes: Remaining 50% of prize pool used to reimburse deposit fees of lucky players
        prizeTotal = prizeTotal.div(2);
        while(prizeTotal > 0) {
            winnerIndex = (winnerIndex + 1).mod(pool.players.length);
            uint consolationPrize = pool.playerStakes[winnerIndex].mul(4);
            if (consolationPrize <= prizeTotal) {
                prize.transferPrize(address(pool.players[winnerIndex]), lpToken, consolationPrize);
                prizeTotal = prizeTotal.sub(consolationPrize);
            } else {
                prize.transferPrize(address(pool.players[winnerIndex]), lpToken, prizeTotal);
                prizeTotal = 0;
            }
        }

        // Update lottery records
        emit lotterySettled(pid, pool.prizeTotal, pool.prizeRound);
        pool.prizeRound = pool.prizeRound + 1;
        pool.prizeTotal = 0;
        pool.players = new address[](0);
        pool.playerStakes = new uint256[](0);
        pool.lastPrizeBlock = block.number;
    }
}
