// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

pragma experimental ABIEncoderV2;

import "../math/SafeMath.sol";
import "../erc20/SafeERC20.sol";
import '../uniswap/TransferHelper.sol';
import "../utils/Address.sol";
import "../utils/ReentrancyGuard.sol";
import "../utils/Pausable.sol";
import "../utils/StringHelpers.sol";

import "./VeToken.sol";

interface ILockRewards {
    // Views

    function totalSupply() external view returns (uint256);
    function totalBoostedSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    // Mutative
    function stakeLocked(uint256 amount, uint256 secs) external;

    function withdrawLocked(bytes32 kek_id) external;
}

contract LockRewards is ILockRewards, ReentrancyGuard, Pausable, VETokenFactory {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    /* ========== STATE VARIABLES ========== */

    VEToken public veToken;
    ERC20 public stakingToken;

    // Constant for various precisions
    uint256 private constant MULTIPLIER_BASE = 1e6;

    address public owner_address;
    address public timeLock_address; // Governance timeLock address

    uint256 public locked_stake_max_multiplier = 8000000; // 6 decimals of precision. 1x = 1000000
    uint256 public locked_stake_time_for_max_multiplier = 1 * 365 * 86400; // 1 years
    uint256 public locked_stake_min_time = 604800; // 7 * 86400  (7 days)
    string private locked_stake_min_time_str = "604800"; // 7 days on genesis

    uint256 private _staking_token_supply = 0;
    uint256 private _staking_token_boosted_supply = 0;
    mapping(address => uint256) private _locked_balances;
    mapping(address => uint256) private _boosted_balances;

    mapping(address => LockedStake[]) private lockedStakes;

    mapping(address => bool) public greyList;

    bool public unlockedStakes; // Release lock stakes in case of system migration

    struct LockedStake {
        bytes32 kek_id;
        uint256 start_timestamp;
        uint256 amount;
        uint256 ending_timestamp;
        uint256 multiplier; // 6 decimals of precision. 1x = 1000000
        uint256 multiplier_amount; // Front-end display usage
    }

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _stakingToken,
        address _timeLock_address,
        string memory _rewardToken_symbol
    ) public Owned(msg.sender){
        owner_address = msg.sender;
        address rewardToken = genVEToken(_rewardToken_symbol);
        veToken = VEToken(rewardToken);
        stakingToken = ERC20(_stakingToken);
        timeLock_address = _timeLock_address;

        unlockedStakes = false;
    }

    /* ========== VIEWS ========== */

    function totalSupply() external override view returns (uint256) {
        return _staking_token_supply;
    }

    function totalBoostedSupply() external override view returns (uint256) {
        return _staking_token_boosted_supply;
    }

    // locked liquidity tokens
    function balanceOf(address account) external override view returns (uint256) {
        return _locked_balances[account];
    }

    // Total 'balance' used for calculating the percent of the pool the account owns
    // Takes into account the locked stake time multiplier
    function boostedBalanceOf(address account) external view returns (uint256) {
        return _boosted_balances[account];
    }

    function lockedStakesOf(address account) external view returns (LockedStake[] memory) {
        return lockedStakes[account];
    }

    function stakingDecimals() external view returns (uint256) {
        return stakingToken.decimals();
    }

    function stakingMultiplier(uint256 secs) public view returns (uint256) {

        uint256 multiplier = uint(MULTIPLIER_BASE).add(secs.mul(locked_stake_max_multiplier.sub(MULTIPLIER_BASE)).div(locked_stake_time_for_max_multiplier));

        if (multiplier > locked_stake_max_multiplier) multiplier = locked_stake_max_multiplier;
        return multiplier;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stakeLocked(uint256 amount, uint256 secs) external override nonReentrant notPaused  {
        require(amount > 0, "Cannot stake 0");
        require(secs > 0, "Cannot wait for a negative number");
        require(greyList[msg.sender] == false, "address has been greyListed");
        require(secs >= locked_stake_min_time, StringHelpers.strConcat("Minimum stake time not met (", locked_stake_min_time_str, ")") );
        require(secs <= locked_stake_time_for_max_multiplier, "You are trying to stake for too long");


        uint256 multiplier = stakingMultiplier(secs);
        uint256 boostedAmount = amount.mul(multiplier).div(MULTIPLIER_BASE);
        lockedStakes[msg.sender].push(LockedStake(
                keccak256(abi.encodePacked(msg.sender, block.timestamp, amount)),
                block.timestamp,
                amount,
                block.timestamp.add(secs),
                multiplier,
                boostedAmount
            ));

        // Pull the tokens from the staker
        TransferHelper.safeTransferFrom(address(stakingToken), msg.sender, address(this), amount);

        // Staking token supply and boosted supply
        _staking_token_supply = _staking_token_supply.add(amount);
        _staking_token_boosted_supply = _staking_token_boosted_supply.add(boostedAmount);

        // Staking token balance and boosted balance
        _locked_balances[msg.sender] = _locked_balances[msg.sender].add(amount);
        _boosted_balances[msg.sender] = _boosted_balances[msg.sender].add(boostedAmount);

        VEToken(veToken).mint(msg.sender, boostedAmount);

        emit StakeLocked(msg.sender, amount, secs);
    }

    function withdrawLocked(bytes32 kek_id) external override nonReentrant {
        LockedStake memory thisStake;
        thisStake.amount = 0;
        uint theIndex;
        for (uint i = 0; i < lockedStakes[msg.sender].length; i++){
            if (kek_id == lockedStakes[msg.sender][i].kek_id){
                thisStake = lockedStakes[msg.sender][i];
                theIndex = i;
                break;
            }
        }
        require(thisStake.kek_id == kek_id, "Stake not found");
        require(block.timestamp >= thisStake.ending_timestamp || unlockedStakes == true, "Stake is still locked!");

        uint256 theAmount = thisStake.amount;
        uint256 boostedAmount = thisStake.multiplier_amount;
        if (theAmount > 0){
            // Staking token balance and boosted balance
            _locked_balances[msg.sender] = _locked_balances[msg.sender].sub(theAmount);
            _boosted_balances[msg.sender] = _boosted_balances[msg.sender].sub(boostedAmount);

            // Staking token supply and boosted supply
            _staking_token_supply = _staking_token_supply.sub(theAmount);
            _staking_token_boosted_supply = _staking_token_boosted_supply.sub(boostedAmount);

            // Remove the stake from the array
            delete lockedStakes[msg.sender][theIndex];

            // Give the tokens to the withdrawer
            stakingToken.safeTransfer(msg.sender, theAmount);

            // burn the veToken corresponding to Token
            VEToken(veToken).burn(msg.sender, boostedAmount);

            emit WithdrawnLocked(msg.sender, theAmount, kek_id);
        }

    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // Added to support recovering LP Rewards from other systems to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyByOwnerOrGovernance {
        // Admin cannot withdraw the staking token from the contract
        require(tokenAddress != address(stakingToken));
        ERC20(tokenAddress).safeTransfer(owner_address, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setMultipliers(uint256 _locked_stake_max_multiplier) external onlyByOwnerOrGovernance {
        require(_locked_stake_max_multiplier >= 1, "Multiplier must be greater than or equal to 1");

        locked_stake_max_multiplier = _locked_stake_max_multiplier;

        emit LockedStakeMaxMultiplierUpdated(locked_stake_max_multiplier);
    }

    function setLockedStakeTimeForMinAndMaxMultiplier(uint256 _locked_stake_time_for_max_multiplier, uint256 _locked_stake_min_time) external onlyByOwnerOrGovernance {
        require(_locked_stake_time_for_max_multiplier >= 1, "Mul max time must be >= 1");
        require(_locked_stake_min_time >= 1, "Mul min time must be >= 1");

        locked_stake_time_for_max_multiplier = _locked_stake_time_for_max_multiplier;

        locked_stake_min_time = _locked_stake_min_time;
        locked_stake_min_time_str = StringHelpers.uint2str(_locked_stake_min_time);

        emit LockedStakeTimeForMaxMultiplier(locked_stake_time_for_max_multiplier);
        emit LockedStakeMinTime(_locked_stake_min_time);
    }

    function greyListAddress(address _address) external onlyByOwnerOrGovernance {
        greyList[_address] = !(greyList[_address]);
    }

    function unlockStakes() external onlyByOwnerOrGovernance {
        unlockedStakes = !unlockedStakes;

    }

    function setOwnerAndTimeLock(address _new_owner, address _new_timeLock) external onlyByOwnerOrGovernance {
        owner_address = _new_owner;
        timeLock_address = _new_timeLock;
        emit SetOwnerAndTimeLock(_new_owner, _new_timeLock);
    }

    modifier onlyByOwnerOrGovernance() {
        require(msg.sender == owner_address || msg.sender == timeLock_address, "Not owner or timeLock");
        _;
    }

    /* ========== EVENTS ========== */
    event Staked(address indexed user, uint256 amount);
    event StakeLocked(address indexed user, uint256 amount, uint256 secs);
    event Withdrawn(address indexed user, uint256 amount);
    event WithdrawnLocked(address indexed user, uint256 amount, bytes32 kek_id);
    event Recovered(address token, uint256 amount);
    event LockedStakeMaxMultiplierUpdated(uint256 multiplier);
    event LockedStakeTimeForMaxMultiplier(uint256 secs);
    event LockedStakeMinTime(uint256 secs);
    event SetOwnerAndTimeLock(address new_owner, address new_timeLock);
}
