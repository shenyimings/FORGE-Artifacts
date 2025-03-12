// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IMintableERC20} from "./interfaces/IMintableERC20.sol";
import {Pool} from "./libraries/pools/Pool.sol";
import {Stake} from "./libraries/pools/Stake.sol";
import {Whitelist} from "./Whitelist.sol";
import {WhitelistChecker} from "./WhitelistChecker.sol";

/// @title StakingPools
/// @dev A contract which allows users to stake to farm tokens.
///
/// This contract was inspired by Chef Nomi's 'MasterChef' contract which can be found in this
/// repository: https://github.com/sushiswap/sushiswap.
contract StakingPools is WhitelistChecker, ReentrancyGuard {
    using Pool for Pool.Data;
    using Pool for Pool.Context;
    using SafeERC20 for IERC20;
    using Stake for Stake.Data;

    event PeriodUpdated(uint256 period, uint256 updateTime);

    event PeriodThresholdUpdated(uint256 periodThreshold);

    event RewardAddressUpdated(address rewardAddress);

    event LevelAdded(
        uint256 interest,
        uint256 lowerBound,
        uint256 upperBound,
        uint256 timeAdded
    );

    event TokensDeposited(address indexed user, uint256 amount);

    event TokensWithdrawn(address indexed user, uint256 amount);

    event TokensClaimed(address indexed user, uint256 amount);

    /// @dev The context shared between the pools.
    Pool.Context private _ctx;

    Pool.Data private _pool;

    /// @dev A mapping of all of the user stakes mapped by address.
    mapping(address => Stake.Data) private _stakes;

    constructor(address _governance, IERC20 _token) {
        require(
            _governance != address(0),
            "StakingPools: governance address cannot be 0x0"
        );
        require(
            address(_token) != address(0),
            "StakingPools: token address cannot be 0x0"
        );

        _pool.token = _token;
        _pool.totalDeposited = 0;
        governance = _governance;
    }

    /// @dev Returns ture if removing the NFT does not affact the staking contract, false otherwise.
    ///
    /// When the removal hinders the token owner from claim/exit existing deposit,
    /// the owner is considered "affected".
    ///
    /// @param _whitelist The whitelist of the NFT.
    /// @param _owner The owner of the NFT.
    /// @param _tokenId The token ID of the NFT.
    function acceptsRemoval(
        Whitelist _whitelist,
        address _owner,
        uint256 _tokenId
    ) external view override returns (bool) {
        return (
            whitelistIndex[_whitelist] == 0 ||
            _stakes[_owner].totalDeposited == 0 ||
            getAllBalance(_owner) > 1 ||
            _whitelist.ownerOf(_tokenId) != _owner
        );
    }

    /// @dev Sets the period for calculating interest.
    ///
    /// This function can only called by the current governance.
    ///
    /// @param _period The period in block time unit for calculating interest.
    function updatePeriod(uint256 _period) external onlyGovernance {
        require(_period > 0, "StakingPools: period cannot be 0");
        _ctx.updatePeriod(_period);

        emit PeriodUpdated(_period, block.timestamp);
    }

    /// @dev Sets the threshold of periods to wait before claiming interest is allowed
    ///
    /// @param _periodThreshold The threshold of periods to wait before claiming interest is allowed
    function setPeriodThreshold(uint256 _periodThreshold)
        external
        onlyGovernance
    {
        require(
            _periodThreshold > 0,
            "StakingPools: period threshold cannot be 0"
        );
        _ctx.periodThreshold = _periodThreshold;

        emit PeriodThresholdUpdated(_periodThreshold);
    }

    /// @dev Sets the address of the official account distributing tokens as reward of stakings.
    ///
    /// This function can only called by the current governance.
    ///
    /// @param _rewardAddress the new token distributing address.
    function setRewardingAddress(address _rewardAddress)
        external
        onlyGovernance
    {
        require(
            _rewardAddress != address(0),
            "StakingPools: reward token pool cannot be 0x0"
        );
        _ctx.rewardAddress = _rewardAddress;

        emit RewardAddressUpdated(_rewardAddress);
    }

    /// @dev Set the interest for deposits which amount is not smaller than the lowerBound and smaller than the upperBound
    ///
    /// This function can only called by the current governance.
    ///
    /// @param _interest the interest per period
    /// @param _lowerBound the lower bound(included) of a deposit to get interest
    /// @param _interest the upper bound(excluded) of a deposit to get interest
    function addLevel(
        uint256 _interest,
        uint256 _lowerBound,
        uint256 _upperBound
    ) external onlyGovernance {
        require(
            _lowerBound < _upperBound,
            "StakingPools: level lower bound cannot be smaller than its upper bound"
        );
        require(
            _ctx.periods.length > 0,
            "StakingPools: adding level before adding a peroid is invalid"
        );
        uint256 currentPeriod = _ctx.toPeriods(block.timestamp);
        _ctx.levels.push(
            Pool.Level({
                interest: _interest,
                lowerBound: _lowerBound,
                upperBound: _upperBound,
                updatePeriod: currentPeriod
            })
        );

        emit LevelAdded(_interest, _lowerBound, _upperBound, currentPeriod);
    }

    /// @dev Stakes tokens into a pool.
    ///
    /// @param _depositAmount the amount of tokens to deposit.
    function deposit(uint256 _depositAmount)
        external
        nonReentrant
        inWhitelist()
    {
        Stake.Data storage _stake = _stakes[msg.sender];
        require(
            _inLevel(_stake.totalDeposited + _depositAmount, _ctx.levels),
            "StakingPools: not in any level"
        );
        _stake.update(_ctx);

        _deposit(_depositAmount);
    }

    /// @dev Claims all rewarded tokens from a pool.
    ///
    /// @param _claimAmount Claims the amount if the user interest is enough, claim all otherwise.
    function claim(uint256 _claimAmount) external nonReentrant inWhitelist() {
        Stake.Data storage _stake = _stakes[msg.sender];
        _stake.update(_ctx);

        require(
            _stake.canClaim(_ctx),
            "StakingPools: staking too short to be claimed"
        );

        _claim(_claimAmount);
    }

    /// @dev Claims all rewards from the pool and withdraws all staked tokens.
    function exit() external nonReentrant inWhitelist() {
        Stake.Data storage _stake = _stakes[msg.sender];
        _stake.update(_ctx);

        if (_stake.canClaim(_ctx)) {
            _claim(_stake.totalUnclaimed);
        }
        _withdraw();
    }

    /// @dev Gets the number of updates for period
    ///
    /// @return the preiod update count
    function getPeriodCount() external view returns (uint256) {
        return _ctx.periods.length;
    }

    /// @dev Gets the period to calculate interest
    ///
    /// @param n the n-th period updated
    ///
    /// @return The period
    /// @return The time the period becomes valid
    function getPeriod(uint256 n) external view returns (uint256, uint256) {
        Pool.Period memory _period = _ctx.periods[n];
        return (_period.period, _period.updateTime);
    }

    /// @dev Gets the threshold of periods to wait before claiming interest is allowed
    ///
    /// @return The period
    function getPeriodThreshold() external view returns (uint256) {
        return _ctx.periodThreshold;
    }

    /// @dev Gets the address of the official account distributing tokens as reward of stakings.
    ///
    /// @return The address distributing tokens
    function getRewardingAddress() external view returns (address) {
        return _ctx.rewardAddress;
    }

    /// @dev Gets the count of deposit levels added before.
    ///
    /// @return The count
    function getLevelCount() external view returns (uint256) {
        return _ctx.levels.length;
    }

    /// @dev Gets the n-th level added
    ///
    /// @param n the index to the level added before.
    ///
    /// @return the interest, lower bound, upper bound, and update period of the level
    function getLevel(uint256 n)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        Pool.Level memory level = _ctx.levels[n];
        return (
            level.interest,
            level.lowerBound,
            level.upperBound,
            level.updatePeriod
        );
    }

    /// @dev Returns true if the deposit is long enough to be claimed
    ///
    /// @param _account The target account to be checked.
    ///
    /// @return True if the _account can claim any, false otherwise.
    function canClaim(address _account) external view returns (bool) {
        Stake.Data storage _stake = _stakes[_account];
        return _stake.canClaim(_ctx);
    }

    /// @dev Gets the token a pool accepts.
    ///
    /// @return the token.
    function getPoolToken() external view returns (IERC20) {
        return _pool.token;
    }

    /// @dev Gets the total amount of funds staked in a pool.
    ///
    /// @return the total amount of staked or deposited tokens.
    function getPoolTotalDeposited() external view returns (uint256) {
        return _pool.totalDeposited;
    }

    /// @dev Gets the number of tokens a user has staked into a pool.
    ///
    /// @param _account The account to query.
    ///
    /// @return the amount of deposited tokens.
    function getStakeTotalDeposited(address _account)
        external
        view
        returns (uint256)
    {
        Stake.Data storage _stake = _stakes[_account];
        return _stake.totalDeposited;
    }

    /// @dev Gets the number of unclaimed reward tokens a user can claim from a pool.
    ///
    /// @param _account The account to get the unclaimed balance of.
    ///
    /// @return the amount of unclaimed reward tokens a user has in a pool.
    function getStakeInfo(address _account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        Stake.Data storage _stake = _stakes[_account];
        uint256 _totalDeposited = _stake.totalDeposited;
        uint256 _totalInterest = 0;
        if (_totalDeposited > 0) {
            _totalInterest =
                _stake._updateInterest(_ctx) +
                _stake.totalUnclaimed;
        }
        return (
            _totalDeposited,
            _totalInterest,
            _stake.lastUpdatePeriod,
            _stake.depositPeriod
        );
    }

    /// @dev Stakes tokens of the msg.sender to the pool.
    ///
    /// The pool and stake MUST be updated before calling this function.
    ///
    /// @param _depositAmount the amount of tokens to deposit.
    function _deposit(uint256 _depositAmount) internal {
        Stake.Data storage _stake = _stakes[msg.sender];

        _pool.totalDeposited = _pool.totalDeposited + _depositAmount;
        _stake.totalDeposited = _stake.totalDeposited + _depositAmount;

        _pool.token.safeTransferFrom(msg.sender, address(this), _depositAmount);

        emit TokensDeposited(msg.sender, _depositAmount);
    }

    /// @dev Withdraws all staked tokens of the msg.sender from the pool.
    ///
    /// The pool and stake MUST be updated before calling this function.
    /// The function only withdraws staked tokens, not the interest yield.
    function _withdraw() internal {
        Stake.Data storage _stake = _stakes[msg.sender];

        uint256 _withdrawAmount = _stake.totalDeposited;
        _pool.totalDeposited = _pool.totalDeposited - _withdrawAmount;
        _stake.totalDeposited = 0;
        _stake.totalUnclaimed = 0;

        _pool.token.safeTransfer(msg.sender, _withdrawAmount);

        emit TokensWithdrawn(msg.sender, _withdrawAmount);
    }

    /// @dev Claims some rewarded tokens of the msg.sender from the pool.
    ///
    /// The pool and stake MUST be updated before calling this function.
    ///
    /// @param _claimAmount Claims the amount if the user interest is enough, claim all otherwise.
    function _claim(uint256 _claimAmount) internal {
        Stake.Data storage _stake = _stakes[msg.sender];

        if (_claimAmount >= _stake.totalUnclaimed) {
            _claimAmount = _stake.totalUnclaimed;
            _stake.totalUnclaimed = 0;
        } else {
            _stake.totalUnclaimed = _stake.totalUnclaimed - _claimAmount;
        }

        _pool.token.safeTransferFrom(
            _ctx.rewardAddress,
            msg.sender,
            _claimAmount
        );

        emit TokensClaimed(msg.sender, _claimAmount);
    }

    /// @dev Check if the amount of deposit in defined in any level
    ///
    /// @param _amount the amount to be checked
    /// @param _levels the array of defined levels
    ///
    /// @return True if the amount is with any level, false otherwise.
    function _inLevel(uint256 _amount, Pool.Level[] storage _levels)
        internal
        view
        returns (bool)
    {
        for (uint256 i = 0; i < _levels.length; i++) {
            if (
                _ctx.levels[i].lowerBound <= _amount &&
                _amount < _ctx.levels[i].upperBound
            ) {
                return true;
            }
        }
        return false;
    }
}
