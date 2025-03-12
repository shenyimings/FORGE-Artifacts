// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IGaugeController.sol";
import "../interfaces/IGauge.sol";
import "../interfaces/IUniPool.sol";
import "../interfaces/IVotingEscrow.sol";

/**
 * @dev Liquidity gauge that stakes token and earns reward.
 * 
 * Note: The liquidity gauge token might not be 1:1 with the staked token.
 * For plus tokens, the total staked amount increases as interest from plus token accrues.
 * Credit: https://github.com/curvefi/curve-dao-contracts/blob/master/contracts/gauges/LiquidityGaugeV2.vy
 */
contract LiquidityGauge is ERC20Upgradeable, ReentrancyGuardUpgradeable, IGauge {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    event LiquidityLimitUpdated(address indexed account, uint256 balance, uint256 supply, uint256 oldWorkingBalance,
        uint256 oldWorkingSupply, uint256 newWorkingBalance, uint256 newWorkingSupply);
    event Deposited(address indexed account, uint256 stakedAmount, uint256 mintAmount);
    event Withdrawn(address indexed account, uint256 withdrawAmount, uint256 fee, uint256 burnAmount);
    event RewardContractUpdated(address indexed oldRewardContract, address indexed newRewardContract, address[] rewardTokens);
    event WithdrawFeeUpdated(uint256 oldWithdrawFee, uint256 newWithdrawFee);
    event DirectClaimCooldownUpdated(uint256 oldCooldown, uint256 newCooldown);

    uint256 constant TOKENLESS_PRODUCTION = 40;
    uint256 constant WAD = 10**18;
    uint256 constant MAX_PERCENT = 10000;   // 0.01%

    // Token staked in the liquidity gauge
    address public override token;
    // AC token
    address public reward;
    // Gauge controller
    address public controller;
    address public votingEscrow;
    // AC emission rate per seconds in the gauge
    uint256 public rate;
    uint256 public withdrawFee;
    // List of tokens that cannot be salvaged
    mapping(address => bool) public unsalvageable;

    uint256 public workingSupply;
    mapping(address => uint256) public workingBalances;

    uint256 public integral;
    // Last global checkpoint timestamp
    uint256 public lastCheckpoint;
    // Integral of the last user checkpoint
    mapping(address => uint256) public integralOf;
    // Timestamp of the last user checkpoint
    mapping(address => uint256) public checkpointOf;
    // Mapping: User => Rewards accrued last checkpoint
    mapping(address => uint256) public rewards;
    // Mapping: User => Last time the user claims directly from the gauge
    // Users can claim directly from gauge or indirectly via a claimer
    mapping(address => uint256) public lastDirectClaim;
    // The cooldown interval between two direct claims from the gauge
    uint256 public directClaimCooldown;

    address public rewardContract;
    address[] public rewardTokens;
    // Reward token address => Reward token integral
    mapping(address => uint256) public rewardIntegral;
    // Reward token address => (User address => Reward integral of the last user reward checkpoint)
    mapping(address => mapping(address => uint256)) public rewardIntegralOf;

    /**
     * @dev Initlaizes the liquidity gauge contract.
     */
    function initialize(address _token, address _controller, address _votingEscrow) public initializer {
        token = _token;
        controller = _controller;
        reward = IGaugeController(_controller).reward();
        votingEscrow = _votingEscrow;
        directClaimCooldown = 14 days;  // A default 14 day direct claim cool down

        // Should not salvage token from the gauge
        unsalvageable[token] = true;
        // We allow salvage reward token since the liquidity gauge should not hold reward token. It's
        // distributed from gauge controller to user directly.

        __ERC20_init(string(abi.encodePacked(ERC20Upgradeable(_token).name(), " Gauge Deposit")),
            string(abi.encodePacked(ERC20Upgradeable(_token).symbol(), "-gauge")));
        __ReentrancyGuard_init();
    }

    /**
     * @dev Important: Updates the working balance of the user to effectively apply
     * boosting on liquidity mining.
     * @param _account Address to update liquidity limit
     */
    function _updateLiquidityLimit(address _account) internal {
        IERC20Upgradeable _votingEscrow = IERC20Upgradeable(votingEscrow);
        uint256 _votingBalance = _votingEscrow.balanceOf(_account);
        uint256 _votingTotal = _votingEscrow.totalSupply();

        uint256 _balance = balanceOf(_account);
        uint256 _supply = totalSupply();
        uint256 _limit = _balance.mul(TOKENLESS_PRODUCTION).div(100);
        if (_votingTotal > 0) {
            uint256 _boosting = _supply.mul(_votingBalance).mul(100 - TOKENLESS_PRODUCTION).div(_votingTotal).div(100);
            _limit = _limit.add(_boosting);
        }

        _limit = MathUpgradeable.min(_balance, _limit);
        uint256 _oldWorkingBalance = workingBalances[_account];
        uint256 _oldWorkingSupply = workingSupply;
        workingBalances[_account] = _limit;
        uint256 _newWorkingSupply = _oldWorkingSupply.add(_limit).sub(_oldWorkingBalance);
        workingSupply = _newWorkingSupply;

        emit LiquidityLimitUpdated(_account, _balance, _supply, _oldWorkingBalance, _oldWorkingSupply, _limit, _newWorkingSupply);
    }

    /**
     * @dev Claims pending rewards and checkpoint rewards for a user.
     * @param _account Address of the user to checkpoint reward. Zero means global checkpoint only.
     */
    function _checkpointRewards(address _account) internal {
        uint256 _supply = totalSupply();
        address _rewardContract = rewardContract;
        address[] memory _rewardList = rewardTokens;
        uint256[] memory _rewardBalances = new uint256[](_rewardList.length);
        // No op if nothing is staked yet!
        if (_supply == 0 || _rewardContract == address(0x0) || _rewardList.length == 0) return;

        // Reads balance for each reward token
        for (uint256 i = 0; i < _rewardList.length; i++) {
            _rewardBalances[i] = IERC20Upgradeable(_rewardList[i]).balanceOf(address(this));
        }
        IUniPool(_rewardContract).getReward();
        
        uint256 _balance = balanceOf(_account);
        // Checks balance increment for each reward token
        for (uint256 i = 0; i < _rewardList.length; i++) {
            // Integral is in WAD
            uint256 _diff = IERC20Upgradeable(_rewardList[i]).balanceOf(address(this)).sub(_rewardBalances[i]).mul(WAD).div(_supply);
            uint256 _newIntegral = rewardIntegral[_rewardList[i]].add(_diff);
            if (_diff != 0) {
                rewardIntegral[_rewardList[i]] = _newIntegral;
            }
            if (_account == address(0x0))   continue;

            uint256 _userIntegral = rewardIntegralOf[_rewardList[i]][_account];
            if (_userIntegral < _newIntegral) {
                uint256 _claimable = _balance.mul(_newIntegral.sub(_userIntegral)).div(WAD);
                rewardIntegralOf[_rewardList[i]][_account] = _newIntegral;

                if (_claimable > 0) {
                    IERC20Upgradeable(_rewardList[i]).safeTransfer(_account, _claimable);
                }
            }
        }
    }

    /**
     * @dev Performs checkpoint on AC rewards.
     * @param _account User address to checkpoint. Zero to do global checkpoint only.
     */
    function _checkpoint(address _account) internal {
        uint256 _workingSupply = workingSupply;
        if (_workingSupply == 0) {
            lastCheckpoint = block.timestamp;
            return;
        }

        uint256 _diffTime = block.timestamp.sub(lastCheckpoint);
        // Both rate and integral are in WAD
        uint256 _newIntegral = integral.add(rate.mul(_diffTime).div(_workingSupply));
        integral = _newIntegral;
        lastCheckpoint = block.timestamp;

        if (_account == address(0x0))   return;

        uint256 _amount = workingBalances[_account].mul(_newIntegral.sub(integralOf[_account])).div(WAD);
        integralOf[_account] = _newIntegral;
        checkpointOf[_account] = block.timestamp;
        rewards[_account] = rewards[_account].add(_amount);
    }

    /**
     * @dev Performs global checkpoint for the liquidity gauge.
     * Note: AC emission rate change is triggered by gauge controller. Each time there is a rate change,
     * Gauge controller will checkpoint the gauge. Therefore, we could assume that the rate is not changed
     * between two checkpoints!
     */
    function checkpoint() external override nonReentrant {
        _checkpoint(address(0x0));
        // Loads the new emission rate from gauge controller
        rate = IGaugeController(controller).gaugeRates(address(this));
    }

    /**
     * @dev Returns the next time user can trigger a direct claim.
     */
    function nextDirectClaim(address _account) external view returns (uint256) {
        return MathUpgradeable.max(block.timestamp, lastDirectClaim[_account].add(directClaimCooldown));
    }

    /**
     * @dev Returns the amount of AC token that the user can claim.
     * @param _account Address of the account to check claimable reward.
     */
    function claimable(address _account) external view override returns (uint256) {
        // Reward claimable until the previous checkpoint
        uint256 _reward = workingBalances[_account].mul(integral.sub(integralOf[_account])).div(WAD);
        // Add the remaining claimable rewards
        _reward = _reward.add(rewards[_account]);
        if (workingSupply > 0) {
            uint256 _diffTime = block.timestamp.sub(lastCheckpoint);
            // Both rate and integral are in WAD
            uint256 _additionalReard = rate.mul(_diffTime).mul(workingBalances[_account]).div(workingSupply).div(WAD);

            _reward = _reward.add(_additionalReard);
        }

        return _reward;
    }

    /**
     * @dev Returns the amount of reward token that the user can claim until the latest checkpoint.
     * @param _account Address of the account to check claimable reward.
     * @param _rewardToken Address of the reward token
     */
    function claimableReward(address _account, address _rewardToken) external view returns (uint256) {
        return balanceOf(_account).mul(rewardIntegral[_rewardToken].sub(rewardIntegralOf[_rewardToken][_account])).div(WAD);
    }

    /**
     * @dev Claims reward for the user. 
     * @param _account Address of the user to claim.
     * @param _claimRewards Whether to claim other rewards as well.
     */
    function claim(address _account, bool _claimRewards) external nonReentrant {
        _claim(_account, _account, _claimRewards);
    }

    /**
     * @dev Claims reward for the user. 
     * @param _account Address of the user to claim.
     * @param _receiver Address that receives the claimed reward
     * @param _claimRewards Whether to claim other rewards as well.
     */
    function claim(address _account, address _receiver, bool _claimRewards) external override nonReentrant {
        _claim(_account, _receiver, _claimRewards);
    }

    /**
     * @dev Claims reward for the user. It transfers the claimable reward to the user and updates user's liquidity limit.
     * Note: We allow anyone to claim other rewards on behalf of others, but not for the AC reward. This is because claiming AC
     * reward also updates the user's liquidity limit. Therefore, only authorized claimer can do that on behalf of user.
     * @param _account Address of the user to claim.
     * @param _receiver Address that receives the claimed reward
     * @param _claimRewards Whether to claim other rewards as well.
     */
    function _claim(address _account, address _receiver, bool _claimRewards) internal {
        // Direct claim mean user claiming directly to the gauge. Cooldown applies to direct claim.
        // Indirect claim means user claimsing via claimers. There is no cooldown in indirect claim.
        require((_account == msg.sender && block.timestamp >= lastDirectClaim[_account].add(directClaimCooldown))
            || IGaugeController(controller).claimers(msg.sender), "cannot claim");

        _checkpoint(_account);
        _updateLiquidityLimit(_account);

        uint256 _claimable = rewards[_account];
        if (_claimable > 0) {
            IGaugeController(controller).claim(_account, _receiver, _claimable);
            rewards[_account] = 0;
        }

        if (_claimRewards) {
            _checkpointRewards(_account);
        }

        // Cooldown applies only to direct claim
        if (_account == msg.sender) {
            lastDirectClaim[msg.sender] = block.timestamp;
        }
    }

    /**
     * @dev Claims all rewards for the caller.
     * @param _account Address of the user to claim.
     */
    function claimRewards(address _account) external nonReentrant {
        _checkpointRewards(_account);
    }

    /**
     * @dev Checks whether an account can be kicked.
     * An account is kickable if the account has another voting event since last checkpoint,
     * or the lock of the account expires.
     */
    function kickable(address _account) public view override returns (bool) {
        address _votingEscrow = votingEscrow;
        uint256 _lastUserCheckpoint = checkpointOf[_account];
        uint256 _lastUserEvent = IVotingEscrow(_votingEscrow).user_point_history__ts(_account, IVotingEscrow(_votingEscrow).user_point_epoch(_account));

        return IERC20Upgradeable(_votingEscrow).balanceOf(_account) == 0 || _lastUserEvent > _lastUserCheckpoint;
    }

    /**
     * @dev Kicks an account for abusing their boost. Only kick if the user
     * has another voting event, or their lock expires.
     */
    function kick(address _account) external override nonReentrant {
        // We allow claimers to kick since kick can be seen as subset of claim.
        require(kickable(_account) || IGaugeController(controller).claimers(msg.sender), "kick not allowed");

        _checkpoint(_account);
        _updateLiquidityLimit(_account);
    }

    /**
     * @dev Returns the total amount of token staked.
     */
    function totalStaked() public view override returns (uint256) {
        return IERC20Upgradeable(token).balanceOf(address(this));
    }

    /**
     * @dev Returns the amount staked by the user.
     */
    function userStaked(address _account) public view override returns (uint256) {
        uint256 _totalSupply = totalSupply();
        uint256 _balance = IERC20Upgradeable(token).balanceOf(address(this));

        return _totalSupply == 0 ? 0 : balanceOf(_account).mul(_balance).div(_totalSupply);
    }

    /**
     * @dev Deposit the staked token into liquidity gauge.
     * @param _amount Amount of staked token to deposit.
     */
    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "zero amount");
        if (_amount == uint256(int256(-1))) {
            // -1 means deposit all
            _amount = IERC20Upgradeable(token).balanceOf(msg.sender);
        }

        _checkpoint(msg.sender);
        _checkpointRewards(msg.sender);

        uint256 _totalSupply = totalSupply();
        uint256 _balance = IERC20Upgradeable(token).balanceOf(address(this));
        // Note: Ideally, when _totalSupply = 0, _balance = 0.
        // However, it's possible that _balance != 0 when _totalSupply = 0, e.g.
        // 1) There are some leftover due to rounding error after all people withdraws;
        // 2) Someone sends token to the liquidity gauge before there is any deposit.
        // Therefore, when either _totalSupply or _balance is 0, we treat the gauge is empty.
        uint256 _mintAmount = _totalSupply == 0 || _balance == 0 ? _amount : _amount.mul(_totalSupply).div(_balance);
        
        _mint(msg.sender, _mintAmount);
        _updateLiquidityLimit(msg.sender);

        IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), _amount);

        address _rewardContract = rewardContract;
        if (_rewardContract != address(0x0)) {
            IUniPool(_rewardContract).stake(_amount);
        }

        emit Deposited(msg.sender, _amount, _mintAmount);
    }

    /**
     * @dev Withdraw the staked token from liquidity gauge.
     * @param _amount Amounf of staked token to withdraw
     */
    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0, "zero amount");
        uint256 _burnAmount = 0;
        if (_amount == uint256(int256(-1))) {
            // -1 means withdraw all
            _amount = userStaked(msg.sender);
            _burnAmount = balanceOf(msg.sender);
        } else {
            uint256 _totalSupply = totalSupply();
            uint256 _balance = IERC20Upgradeable(token).balanceOf(address(this));
            require(_totalSupply > 0 && _balance > 0, "no balance");
            _burnAmount = _amount.mul(_totalSupply).div(_balance);
        }

        _checkpoint(msg.sender);
        _checkpointRewards(msg.sender);

        _burn(msg.sender, _burnAmount);
        _updateLiquidityLimit(msg.sender);

        address _rewardContract = rewardContract;
        if (_rewardContract != address(0x0)) {
            IUniPool(_rewardContract).withdraw(_amount);
        }
        
        uint256 _fee;
        address _token = token;
        address _controller = controller;
        if (withdrawFee > 0) {
            _fee = _amount.mul(withdrawFee).div(MAX_PERCENT);
            IERC20Upgradeable(_token).safeTransfer(_controller, _fee);
            // Donate the withdraw fee for future processing
            // Withdraw fee for plus token is donated to all token holders right away
            IGaugeController(_controller).donate(_token);
        }

        IERC20Upgradeable(_token).safeTransfer(msg.sender, _amount.sub(_fee));
        emit Withdrawn(msg.sender, _amount, _fee, _burnAmount);
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     */
    function _transfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        _checkpoint(_sender);
        _checkpoint(_recipient);
        _checkpointRewards(_sender);
        _checkpointRewards(_recipient);

        // Invoke super _transfer to emit Transfer event
        super._transfer(_sender, _recipient, _amount);

        _updateLiquidityLimit(_sender);
        _updateLiquidityLimit(_recipient);
    }

    /*********************************************
     *
     *    Governance methods
     *
     **********************************************/
    
    /**
     * @dev All liqduiity gauge share the same governance of gauge controller.
     */
    function _checkGovernance() internal view {
        require(msg.sender == IGaugeController(controller).governance(), "not governance");
    }

    modifier onlyGovernance() {
        _checkGovernance();
        _;
    }

    /**
     * @dev Updates the reward contract and reward tokens.
     * @param _rewardContract The new active reward contract.
     * @param _rewardTokens The reward tokens from the reward contract.
     */
    function setRewards(address _rewardContract, address[] memory _rewardTokens) external onlyGovernance {
        address _currentRewardContract = rewardContract;
        address _token = token;
        if (_currentRewardContract != address(0x0)) {
            _checkpointRewards(address(0x0));
            IUniPool(_currentRewardContract).exit();

            IERC20Upgradeable(_token).safeApprove(_currentRewardContract, 0);
        }

        if (_rewardContract != address(0x0)) {
            require(_rewardTokens.length > 0, "reward tokens not set");
            IERC20Upgradeable(_token).safeApprove(_rewardContract, uint256(int256(-1)));
            IUniPool(_rewardContract).stake(totalSupply());

            rewardContract = _rewardContract;
            rewardTokens = _rewardTokens;

            // Complete an initial checkpoint to make sure that everything works.
            _checkpointRewards(address(0x0));

            // Reward contract is tokenized as well
            unsalvageable[_rewardContract] = true;
            // Don't salvage any reward token
            for (uint256 i = 0; i < _rewardTokens.length; i++) {
                unsalvageable[_rewardTokens[i]] = true;
            }
        }

        emit RewardContractUpdated(_currentRewardContract, _rewardContract, _rewardTokens);
    }

    /**
     * @dev Updates the withdraw fee. Only governance can update withdraw fee.
     */
    function setWithdrawFee(uint256 _withdrawFee) external onlyGovernance {
        require(_withdrawFee <= MAX_PERCENT, "too big");
        uint256 _oldWithdrawFee = withdrawFee;
        withdrawFee = _withdrawFee;

        emit WithdrawFeeUpdated(_oldWithdrawFee, _withdrawFee);
    }

    /**
     * @dev Updates the cooldown between two direct claims.
     */
    function setDirectClaimCooldown(uint256 _cooldown) external onlyGovernance {
        uint256 _oldCooldown = directClaimCooldown;
        directClaimCooldown = _cooldown;

        emit DirectClaimCooldownUpdated(_oldCooldown, _cooldown);
    }

    /**
     * @dev Used to salvage any ETH deposited to gauge contract by mistake. Only governance can salvage ETH.
     * The salvaged ETH is transferred to treasury for futher operation.
     */
    function salvage() external onlyGovernance {
        uint256 _amount = address(this).balance;
        address payable _target = payable(IGaugeController(controller).treasury());
        (bool success, ) = _target.call{value: _amount}(new bytes(0));
        require(success, 'ETH salvage failed');
    }

    /**
     * @dev Used to salvage any token deposited to gauge contract by mistake. Only governance can salvage token.
     * The salvaged token is transferred to treasury for futhuer operation.
     * @param _token Address of the token to salvage.
     */
    function salvageToken(address _token) external onlyGovernance {
        require(!unsalvageable[_token], "cannot salvage");

        IERC20Upgradeable _target = IERC20Upgradeable(_token);
        _target.safeTransfer(IGaugeController(controller).treasury(), _target.balanceOf(address(this)));
    }
}