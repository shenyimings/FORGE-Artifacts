// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../interfaces/tokenomics/ICNCToken.sol";
import "../../interfaces/tokenomics/IAmmStaker.sol";
import "../../libraries/ScaledMath.sol";

contract AmmStaker is Ownable, IAmmStaker {
    using ScaledMath for uint256;
    using SafeERC20 for IERC20;

    // Approaches 500k tokens in total inflation
    uint256 internal constant INITIAL_INFLATION_RATE = 600_000 * 1e18;
    uint256 internal constant INFLATION_RATE_DECAY = 0.3999999 * 1e18;
    uint256 internal constant INFLATION_RATE_PERIOD = 365 days;

    // Global trackers
    uint256 public currentInflationRate;
    uint256 public lastInflationRateDecay;
    uint256 public totalClaimable;
    uint256 public stakedIntegral;
    uint256 public totalStaked;

    // Per account trackers
    mapping(address => uint256) public balances;
    mapping(address => uint256) public accountAccruals;
    mapping(address => uint256) public accountShares;

    address public ammToken;
    address public immutable rewardToken;
    address public immutable treasury;
    bool public terminated;
    uint256 public lastUpdate;

    event TokensClaimed(address indexed account, uint256 amount);
    event AmmTokenStaked(address indexed account, uint256 amount);
    event AmmTokenUnstaked(address indexed account, uint256 amount);
    event AmmTokenSet(address _ammToken);

    constructor(address _rewardToken, address _treasury) {
        rewardToken = _rewardToken;
        treasury = _treasury;
        currentInflationRate = INITIAL_INFLATION_RATE / INFLATION_RATE_PERIOD;
        lastUpdate = block.timestamp;
        lastInflationRateDecay = block.timestamp;
    }

    function setAmmToken(address _ammToken) external override onlyOwner {
        require(ammToken == address(0), "Amm token already initialized");
        ammToken = _ammToken;
        emit AmmTokenSet(_ammToken);
    }

    function shutdown() external override onlyOwner {
        require(!terminated, "Already terminated");
        globalCheckpoint();
        terminated = true;
        IERC20 _rewardToken = IERC20(rewardToken);
        _rewardToken.safeTransfer(treasury, _rewardToken.balanceOf(address(this)) - totalClaimable);
    }

    function claimRewards() external override returns (uint256) {
        _userCheckpoint(msg.sender);
        uint256 amount = accountShares[msg.sender];
        if (amount <= 0) return 0;
        accountShares[msg.sender] = 0;
        totalClaimable -= amount;
        IERC20(rewardToken).safeTransfer(msg.sender, amount);
        _executeInflationRateUpdate();
        emit TokensClaimed(msg.sender, amount);
        return amount;
    }

    function claimableRewards(address user) external view override returns (uint256) {
        uint256 tempStakedIntegral = stakedIntegral;
        if (!terminated && totalStaked > 0) {
            uint256 timeElapsed = block.timestamp - lastUpdate;
            tempStakedIntegral += (currentInflationRate * timeElapsed).divDown(totalStaked);
        }
        return
            accountShares[user] +
            balances[user].mulDown(tempStakedIntegral - accountAccruals[user]);
    }

    function executeInflationRateUpdate() external override {
        globalCheckpoint();
        _executeInflationRateUpdate();
    }

    function stakeFor(address account, uint256 amount) public override {
        require(amount > 0, "Cannot stake 0");
        require(!terminated, "Staker is terminated");
        _userCheckpoint(account);

        uint256 oldBal = IERC20(ammToken).balanceOf(address(this));
        IERC20(ammToken).safeTransferFrom(msg.sender, address(this), amount);
        uint256 newBal = IERC20(ammToken).balanceOf(address(this));
        uint256 staked = newBal - oldBal;
        balances[account] += staked;
        totalStaked += staked;
        emit AmmTokenStaked(account, amount);
    }

    function unstakeFor(address dst, uint256 amount) public override {
        require(amount > 0, "Cannot unstake 0");
        require(balances[msg.sender] >= amount, "Not enough funds to unstake");

        _userCheckpoint(msg.sender);

        uint256 oldBal = IERC20(ammToken).balanceOf(address(this));
        IERC20(ammToken).safeTransfer(dst, amount);
        uint256 newBal = IERC20(ammToken).balanceOf(address(this));
        uint256 unstaked = oldBal - newBal;
        balances[msg.sender] -= unstaked;
        totalStaked -= unstaked;
        emit AmmTokenUnstaked(msg.sender, amount);
    }

    function globalCheckpoint() public override returns (bool) {
        if (terminated) {
            return false;
        }
        // Update the integral of total token supply for the pool
        uint256 timeElapsed = block.timestamp - lastUpdate;
        if (totalStaked > 0) {
            stakedIntegral += (currentInflationRate * timeElapsed).divDown(totalStaked);
        }
        lastUpdate = block.timestamp;
        return true;
    }

    function _executeInflationRateUpdate() internal {
        if (block.timestamp >= lastInflationRateDecay + INFLATION_RATE_PERIOD) {
            currentInflationRate = currentInflationRate.mulDown(INFLATION_RATE_DECAY);
            lastInflationRateDecay = block.timestamp;
        }
    }

    function _userCheckpoint(address user) internal {
        globalCheckpoint();
        uint256 claimableAdded = balances[user].mulDown(stakedIntegral - accountAccruals[user]);
        accountShares[user] += claimableAdded;
        totalClaimable += claimableAdded;
        accountAccruals[user] = stakedIntegral;
    }
}
