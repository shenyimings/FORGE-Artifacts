pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import "../Dependencies/IERC20.sol";
import "../Dependencies/Math.sol";
import "../Dependencies/ReentrancyGuard.sol";
import "../Dependencies/SafeERC20.sol";
import "../Dependencies/SafeMath.sol";
import "../Dependencies/Pausable.sol";
import "../Interfaces/IUniswapV2Pair.sol";
import "../Interfaces/IMultiRewards.sol";
import "../Interfaces/ICommunityIssuance.sol";

contract StakingRewardsPenalty is ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    struct Deposit {
        uint256 timestamp;
        uint256 amount;
    }

    struct UserBalance {
        uint256 total;
        uint256 depositIndex;
        Deposit[] deposits;
    }

    // token to stake - must be a UniV2 LP token
    IUniswapV2Pair public stakingToken;
    // token within `stakingToken` that is forwarded to `MultiRewards`
    IERC20 public wantToken;
    // token within `stakingToken` that is burnt
    address public burnToken;

    mapping (address => UserBalance) userBalances;

    uint256 public constant rewardsDuration = 86400 * 7;
    uint256 public constant rewardsUpdateFrequency = 3600;

    // each index is the total amount collected over 1 week
    uint256[65535] feeAmounts;
    // the current week is calculated from `block.timestamp - startTime`
    uint256 public startTime;
    // active index for `feeAmounts`
    uint256 public feeIndex;
    // address of the contract for single-sided staking of `wantToken`
    address public feeReceiver;
    // address of the CommunityIssuance contract that releases rewards to this contract
    ICommunityIssuance public rewardIssuer;

    address public treasury;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IUniswapV2Pair _stakingToken,
        IERC20 _wantToken,
        address _burnToken,
        address _feeReceiver,
        ICommunityIssuance _rewardIssuer,
        address _treasury
    )
        public
        Ownable()
    {
        stakingToken = _stakingToken;
        wantToken = _wantToken;
        burnToken = _burnToken;

        feeReceiver = _feeReceiver;
        rewardIssuer = _rewardIssuer;
        treasury = _treasury;
        startTime = block.timestamp;
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return userBalances[account].total;
    }

    function userDeposits(address account) external view returns (Deposit[] memory deposits) {
        UserBalance storage user = userBalances[account];
        deposits = new Deposit[](user.deposits.length.sub(user.depositIndex));

        for (uint256 i = 0; i < deposits.length; i++) {
            deposits[i] = user.deposits[user.depositIndex + i];
        }
        return deposits;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply)
            );
    }

    function earned(address account) public view returns (uint256) {
        return userBalances[account].total.mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    // current deposit fee percent, given as an integer out of 10000
    // the deposit fee is fixed, starting at 2% and reducing by 0.5%
    // every 13 weeks until becoming 0 at one year after launch
    function depositFee() public view returns (uint256) {
        uint256 timeSinceStart = block.timestamp.sub(startTime);
        if (timeSinceStart >= 31449600) return 0;
        return uint256(200).sub(timeSinceStart.div(7862400).mul(50));
    }

    // exact fee amount paid when depositing `amount`
    function depositFeeOnAmount(uint256 amount) public view returns (uint256) {
        uint256 fee = depositFee();
        return amount.mul(fee).div(10000);
    }

    // exact fee amount paid when `account` withdraws `amount`
    // the withdrawal fee is variable, starting at 8% and reducing by 1% for each week that
    // the funds have been deposited. withdrawals are always made starting from the oldest
    // deposit, in order to minimize the fee paid.
    function withdrawFeeOnAmount(address account, uint256 amount) public view returns (uint256 feeAmount) {
        UserBalance storage user = userBalances[account];
        require(user.total >= amount, "Amount exceeds user deposit");

        uint256 remaining = amount;
        uint256 timestamp = block.timestamp / 86400 * 86400;
        for (uint256 i = user.depositIndex; ; i++) {
            Deposit storage dep = user.deposits[i];
            uint256 weeklyAmount = dep.amount;
            if (weeklyAmount > remaining) {
                weeklyAmount = remaining;
            }
            uint256 weeksSinceDeposit = timestamp.sub(dep.timestamp).div(604800);
            if (weeksSinceDeposit < 8) {
                // for balances deposited less than 8 weeks ago, a withdrawal
                // fee is applied starting at 8% and decreasing by 1% every week
                uint feeMultiplier = 8 - weeksSinceDeposit;
                feeAmount = feeAmount.add(weeklyAmount.mul(feeMultiplier).div(100));
            }
            remaining = remaining.sub(weeklyAmount);
            if (remaining == 0) {
                return feeAmount;
            }
        }
        revert();
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function addFeeAmount(uint256 _amount) internal {
        uint256 idx = block.timestamp.sub(startTime).div(604800);
        uint256 lpAmount;

        if (feeIndex < idx) {
            while (feeIndex < idx) {
                lpAmount = lpAmount.add(feeAmounts[feeIndex]);
                feeIndex++;
            }
            if (lpAmount > 0) {
                // withdraw LP position
                stakingToken.transfer(address(stakingToken), lpAmount);
                stakingToken.burn(address(this));

                // burn the LIQR withdrawn from the LP position
                uint256 burnAmount = IERC20(burnToken).balanceOf(address(this));
                IERC20(burnToken).transfer(address(0xdead), burnAmount);

                // add the reward token to the LIQR staking contract
                uint256 rewardAmount = wantToken.balanceOf(address(this));
                wantToken.safeTransfer(feeReceiver, rewardAmount);
                IMultiRewards(feeReceiver).notifyRewardAmount(address(wantToken), rewardAmount);
                emit FeeProcessed(lpAmount, burnAmount, rewardAmount);
            }
        }
        // transfer 50% of fee tokens to treasury
        lpAmount = _amount.div(2);
        stakingToken.transfer(treasury, lpAmount);

        // hold remaining fee tokens for 8 weeks
        idx = idx.add(8);
        feeAmounts[idx] = feeAmounts[idx].add(_amount.sub(lpAmount));
    }

    // `amount` is the total amount to deposit, inclusive of any fee amount to be paid
    // the final deposited balance ay be up to 2% less than `amount` depending upon the
    // current deposit fee
    function stake(uint256 amount) external nonReentrant notPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        stakingToken.transferFrom(msg.sender, address(this), amount);

        // apply deposit fee, if any
        uint256 feeAmount = depositFeeOnAmount(amount);
        if (feeAmount > 0) {
            addFeeAmount(feeAmount);
            amount = amount.sub(feeAmount);
        }

        _totalSupply = _totalSupply.add(amount);
        UserBalance storage user = userBalances[msg.sender];
        user.total = user.total.add(amount);
        uint256 timestamp = block.timestamp / 86400 * 86400;
        uint256 length = user.deposits.length;
        if (length == 0 || user.deposits[length-1].timestamp < timestamp) {
            user.deposits.push(Deposit({timestamp: timestamp, amount: amount}));
        } else {
            user.deposits[length-1].amount = user.deposits[length-1].amount.add(amount);
        }
        emit Staked(msg.sender, amount, feeAmount);
    }

    /// `amount` is the total to withdraw inclusive of any fee amounts to be paid.
    /// the final balance received may be up to 8% less than `amount` depending upon
    /// how recently the caller deposited
    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply = _totalSupply.sub(amount);

        UserBalance storage user = userBalances[msg.sender];
        user.total = user.total.sub(amount);

        uint256 amountAfterFee = 0;
        uint256 remaining = amount;
        uint256 timestamp = block.timestamp / 86400 * 86400;
        for (uint256 i = user.depositIndex; ; i++) {
            Deposit storage dep = user.deposits[i];
            uint256 weeklyAmount = dep.amount;
            if (weeklyAmount > remaining) {
                weeklyAmount = remaining;
            }
            uint256 weeksSinceDeposit = timestamp.sub(dep.timestamp).div(604800);
            if (weeksSinceDeposit < 8) {
                // for balances deposited less than 8 weeks ago, a withdrawal
                // fee is applied starting at 8% and decreasing by 1% every week
                uint feeMultiplier = 100 - (8 - weeksSinceDeposit);
                amountAfterFee = amountAfterFee.add(weeklyAmount.mul(feeMultiplier).div(100));
            } else {
                amountAfterFee = amountAfterFee.add(weeklyAmount);
            }
            remaining = remaining.sub(weeklyAmount);
            dep.amount = dep.amount.sub(weeklyAmount);
            if (remaining == 0) {
                user.depositIndex = i;
                break;
            }
        }

        stakingToken.transfer(msg.sender, amountAfterFee);
        uint256 feeAmount = amount.sub(amountAfterFee);
        if (feeAmount > 0) {
            addFeeAmount(feeAmount);
        }
        emit Withdrawn(msg.sender, amount, feeAmount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardIssuer.sendLQTY(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(userBalances[msg.sender].total);
        getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(stakingToken), "Cannot withdraw the staking token");
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
        if (periodFinish < block.timestamp.add(rewardsDuration).sub(rewardsUpdateFrequency)) {
            // if last reward update was more than `rewardsUpdateFrequency` seconds ago, update again
            uint256 issuance = rewardIssuer.issueLQTY();
            if (block.timestamp >= periodFinish) {
                rewardRate = issuance.div(rewardsDuration);
            } else {
                uint256 remaining = periodFinish.sub(block.timestamp);
                uint256 leftover = remaining.mul(rewardRate);
                rewardRate = issuance.add(leftover).div(rewardsDuration);
            }
            lastUpdateTime = block.timestamp;
            periodFinish = block.timestamp.add(rewardsDuration);
            emit RewardAdded(issuance);
        }
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 stakeAmount, uint256 feeAmount);
    event Withdrawn(address indexed user, uint256 withdrawAmount, uint256 feeAmount);
    event FeeProcessed(uint256 lpTokensWithdrawn, uint256 burnAmount, uint256 rewardAmount);
    event RewardPaid(address indexed user, uint256 reward);
    event Recovered(address token, uint256 amount);
}
