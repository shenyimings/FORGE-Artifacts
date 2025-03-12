// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./GovernedMulti.sol";

contract PoolMulti is GovernedMulti, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 constant multiplierScale = 10 ** 18;

    mapping(address => uint256) public rewardsNotTransferred;
    mapping(address => uint256) public balancesBefore;
    mapping(address => uint256) public currentMultipliers;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public userMultipliers;
    mapping(address => mapping(address => uint256)) public owed;

    uint256 public poolSize;

    event ClaimRewardToken(address indexed user, address token, uint256 amount);
    event Deposit(address indexed user, uint256 amount, uint256 balanceAfter);
    event Withdraw(address indexed user, uint256 amount, uint256 balanceAfter);

    constructor(address _owner, address _poolToken) {
        require(_poolToken != address(0), "pool token must not be 0x0");

        transferOwnership(_owner);

        poolToken = IERC20(_poolToken);
    }

    function deposit(uint256 amount) public {
        require(amount > 0, "amount must be greater than 0");

        require(
            poolToken.allowance(msg.sender, address(this)) >= amount,
            "allowance must be greater than 0"
        );

        // it is important to calculate the amount owed to the user before doing any changes
        // to the user's balance or the pool's size
        _calculateOwed(msg.sender);

        uint256 newBalance = balances[msg.sender].add(amount);
        balances[msg.sender] = newBalance;
        poolSize = poolSize.add(amount);

        poolToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, newBalance);
    }

    function withdraw(uint256 amount) public {
        require(amount > 0, "amount must be greater than 0");

        uint256 currentBalance = balances[msg.sender];
        require(currentBalance >= amount, "insufficient balance");

        // it is important to calculate the amount owed to the user before doing any changes
        // to the user's balance or the pool's size
        _calculateOwed(msg.sender);

        uint256 newBalance = currentBalance.sub(amount);
        balances[msg.sender] = newBalance;
        poolSize = poolSize.sub(amount);

        poolToken.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, newBalance);
    }

    function claim_allTokens() public nonReentrant {
        _calculateOwed(msg.sender);

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            _claim(address(rewardTokens[i]));
        }
    }

    // claim calculates the currently owed reward and transfers the funds to the user
    function claim(address token) public nonReentrant returns (uint256){
        _calculateOwed(msg.sender);

        return _claim(token);
    }

    function withdrawAndClaim(uint256 amount) public {
        withdraw(amount);
        claim_allTokens();
    }

    function pullRewardFromSource_allTokens() public {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            pullRewardFromSource(address(rewardTokens[i]));
        }
    }

    // pullRewardFromSource transfers any amount due from the source to this contract so it can be distributed
    function pullRewardFromSource(address token) public override {
        softPullReward(token);

        uint256 amountToTransfer = rewardsNotTransferred[token];

        // if there's nothing to transfer, stop the execution
        if (amountToTransfer == 0) {
            return;
        }

        rewardsNotTransferred[token] = 0;

        IERC20(token).safeTransferFrom(rewardSources[token], address(this), amountToTransfer);
    }

    // rewardLeft returns the amount that was not yet distributed
    // even though it is not a view, this function is only intended for external use
    function rewardLeft(address token) external returns (uint256) {
        softPullReward(token);

        return IERC20(token).allowance(rewardSources[token], address(this)).sub(rewardsNotTransferred[token]);
    }

    function softPullReward_allTokens() internal {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            softPullReward(address(rewardTokens[i]));
        }
    }

    // softPullReward calculates the reward accumulated since the last time it was called but does not actually
    // execute the transfers. Instead, it adds the amount to rewardNotTransferred variable
    function softPullReward(address token) internal {
        uint256 lastPullTs = lastSoftPullTs[token];

        // no need to execute multiple times in the same block
        if (lastPullTs == block.timestamp) {
            return;
        }

        uint256 rate = rewardRatesPerSecond[token];
        address source = rewardSources[token];

        // don't execute if the setup was not completed
        if (rate == 0 || source == address(0)) {
            return;
        }

        // if there's no allowance left on the source contract, don't try to pull anything else
        uint256 allowance = IERC20(token).allowance(source, address(this));
        uint256 rewardNotTransferred = rewardsNotTransferred[token];
        if (allowance == 0 || allowance <= rewardNotTransferred) {
            lastSoftPullTs[token] = block.timestamp;
            return;
        }

        uint256 timeSinceLastPull = block.timestamp.sub(lastPullTs);
        uint256 amountToPull = timeSinceLastPull.mul(rate);

        // only pull the minimum between allowance left and the amount that should be pulled for the period
        uint256 allowanceLeft = allowance.sub(rewardNotTransferred);
        if (amountToPull > allowanceLeft) {
            amountToPull = allowanceLeft;
        }

        rewardsNotTransferred[token] = rewardNotTransferred.add(amountToPull);
        lastSoftPullTs[token] = block.timestamp;
    }

    function ackFunds_allTokens() internal {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            ackFunds(address(rewardTokens[i]));
        }
    }

    // ackFunds checks the difference between the last known balance of `token` and the current one
    // if it goes up, the multiplier is re-calculated
    // if it goes down, it only updates the known balance
    function ackFunds(address token) internal {
        uint256 balanceNow = IERC20(token).balanceOf(address(this)).add(rewardsNotTransferred[token]);
        uint256 balanceBeforeLocal = balancesBefore[token];

        if (balanceNow <= balanceBeforeLocal || balanceNow == 0) {
            balancesBefore[token] = balanceNow;
            return;
        }

        // if there's no bond staked, it doesn't make sense to ackFunds because there's nobody to distribute them to
        // and the calculation would fail anyways due to division by 0
        uint256 poolSizeLocal = poolSize;
        if (poolSizeLocal == 0) {
            return;
        }

        uint256 diff = balanceNow.sub(balanceBeforeLocal);
        uint256 multiplier = currentMultipliers[token].add(diff.mul(multiplierScale).div(poolSizeLocal));

        balancesBefore[token] = balanceNow;
        currentMultipliers[token] = multiplier;
    }

    // _calculateOwed calculates and updates the total amount that is owed to an user and updates the user's multiplier
    // to the current value
    // it automatically attempts to pull the token from the source and acknowledge the funds
    function _calculateOwed(address user) internal {
        softPullReward_allTokens();
        ackFunds_allTokens();

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = address(rewardTokens[i]);
            uint256 reward = _userPendingReward(user, token);

            owed[user][token] = owed[user][token].add(reward);
            userMultipliers[user][token] = currentMultipliers[token];
        }
    }

    // _userPendingReward calculates the reward that should be based on the current multiplier / anything that's not included in the `owed[user]` value
    // it does not represent the entire reward that's due to the user unless added on top of `owed[user]`
    function _userPendingReward(address user, address token) internal view returns (uint256) {
        uint256 multiplier = currentMultipliers[token].sub(userMultipliers[user][token]);

        return balances[user].mul(multiplier).div(multiplierScale);
    }

    function _claim(address token) internal returns (uint256) {
        uint256 amount = owed[msg.sender][token];
        if (amount == 0) {
            return 0;
        }

        // check if there's enough balance to distribute the amount owed to the user
        // otherwise, pull the rewardNotTransferred from source
        if (IERC20(token).balanceOf(address(this)) < amount) {
            pullRewardFromSource(token);
        }

        owed[msg.sender][token] = 0;

        IERC20(token).safeTransfer(msg.sender, amount);

        // acknowledge the amount that was transferred to the user
        balancesBefore[token] = balancesBefore[token].sub(amount);

        emit ClaimRewardToken(msg.sender, token, amount);

        return amount;
    }
}
