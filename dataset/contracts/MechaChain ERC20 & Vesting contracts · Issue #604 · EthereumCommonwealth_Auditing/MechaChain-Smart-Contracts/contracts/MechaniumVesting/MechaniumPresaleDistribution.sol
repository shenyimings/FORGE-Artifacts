// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MechaniumVesting.sol";
import "../MechaniumStaking/IStakingPool.sol";

/**
 * @title MechaniumPresaleDistribution - Pre-sale distribution smart contract
 * @author EthernalHorizons - <https://ethernalhorizons.com/>
 * @custom:project-website  https://mechachain.io/
 * @custom:security-contact contracts@ethernalhorizons.com
 */
contract MechaniumPresaleDistribution is MechaniumVesting {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
     * ========================
     *          Events
     * ========================
     */

    /**
     * @notice Event emitted when the `vestingStartingTime` has changed
     */
    event VestingStartingTimeChanged(uint256 vestingStartingTime);

    /**
     * @notice Event emitted when `amount` tokens has been transferred to the play to earn pool
     */
    event TransferUnsoldToPTEPool(uint256 amount);

    /**
     * @notice Event emitted when `account` has transferred `amount` tokens to the staking pool
     */
    event TransferToStakingPool(address indexed account, uint256 amount);

    /**
     * ========================
     *  Constants & Immutables
     * ========================
     */

    /// Max vesting starting time
    uint256 private immutable _maxVestingStartingTime;

    /**
     * ========================
     *         Storage
     * ========================
     */

    /// Mapping of address/amount of allocated toknes
    mapping(address => uint256) private _allocatedTokens;

    /// Starting time of the vesting schedule
    uint256 private _vestingStartingTime;

    /// Play to earn pool address
    address internal _ptePoolAddress;

    /// Staking pool address & interface
    address internal _stakingPoolAddress;
    IStakingPool internal _stakingPool;

    /**
     * ========================
     *         Modifiers
     * ========================
     */

    /**
     * @dev Check if the vesting has started
     */
    modifier vestingStarted() {
        require(
            hasVestingStarted(),
            "The vesting schedule has not started yet"
        );
        _;
    }

    /**
     * @dev Check if the vesting has not started
     */
    modifier vestingNotStarted() {
        require(
            !hasVestingStarted(),
            "The vesting schedule has already started"
        );
        _;
    }

    /**
     * ========================
     *     Public Functions
     * ========================
     */

    /**
     * @dev Contract constructor
     * @param token_ address of the ERC20 token contract, this address cannot be changed later
     */
    constructor(IERC20 token_)
        MechaniumVesting(
            token_,
            20, // once the schedule has started, unlock 20%
            30 days // and repeat every month
        )
    {
        _vestingStartingTime = block.timestamp.add(180 days);
        _maxVestingStartingTime = block.timestamp.add(180 days);
    }

    /**
     * @notice Allocate `amount` token `to` address
     * @param to Address of the beneficiary
     * @param amount Total token to be allocated
     */
    function allocateTokens(address to, uint256 amount)
        public
        override
        onlyRole(ALLOCATOR_ROLE)
        tokensAvailable(amount)
        vestingNotStarted
        returns (bool)
    {
        require(amount > 0, "Amount must be superior to 0");
        require(to != address(0), "Address must not be address(0)");

        if (_allocatedTokens[to] == 0) {
            /// first allocation
            _beneficiaryList.push(to);
        }

        _allocatedTokens[to] = _allocatedTokens[to].add(amount);
        _totalAllocatedTokens = _totalAllocatedTokens.add(amount);

        emit Allocated(to, amount);
        if (isSoldOut()) {
            emit SoldOut(totalAllocatedTokens());
        }
        return true;
    }

    /**
     * @notice Start the vesting immediately
     */
    function startVesting()
        public
        vestingNotStarted
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        _vestingStartingTime = block.timestamp;

        emit VestingStartingTimeChanged(_vestingStartingTime);
        return true;
    }

    /**
     * @notice Set the vesting start time
     * @param startTime vesting start time
     */
    function startVesting(uint256 startTime)
        public
        vestingNotStarted
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        require(
            startTime <= _maxVestingStartingTime,
            "Vesting start time must not be more than 6 months"
        );
        require(
            startTime >= block.timestamp,
            "Vesting start time cannot be in the past"
        );

        _vestingStartingTime = startTime;

        emit VestingStartingTimeChanged(_vestingStartingTime);
        return true;
    }

    /**
     * @notice Set the play to earn pool address
     * @param ptePoolAddress PTE pool address
     */
    function setPTEPool(address ptePoolAddress)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        _ptePoolAddress = ptePoolAddress;
        return true;
    }

    /**
     * @notice Transfer unclaimed tokens to PTE pool
     */
    function transferUnsoldToPTEPool()
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        vestingStarted
        returns (bool)
    {
        require(
            _ptePoolAddress != address(0),
            "Play to earn pool address is not set"
        );
        uint256 amount = totalUnallocatedTokens();
        require(amount > 0);

        _token.safeTransfer(_ptePoolAddress, amount);

        emit TransferUnsoldToPTEPool(amount);

        return true;
    }

    /**
     * @notice Set staking pool address
     * @param stakingPoolAddress The staking pool address
     */
    function setStakingPool(address stakingPoolAddress)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        _stakingPoolAddress = stakingPoolAddress;
        _stakingPool = IStakingPool(stakingPoolAddress);
        return true;
    }

    /**
     * @notice Transfer tokens balance ( allocated but not claimed ) to the staking pool
     */
    function transferToStakingPool() public returns (bool) {
        require(
            _stakingPoolAddress != address(0),
            "Staking pool address is not set"
        );
        address account = msg.sender;
        uint256 amount = balanceOf(account);
        require(amount > 0);

        _token.safeTransfer(_stakingPoolAddress, amount);
        _stakingPool.stakeTokensFromDistribution(account, amount);
        _releasedTokens[account] = releasedTokensOf(account).add(amount);

        emit TransferToStakingPool(account, amount);
        return true;
    }

    /**
     * ========================
     *          Views
     * ========================
     */

    /**
     * @dev Return the amount of allocated tokens for `account` from the beginning
     */
    function allocatedTokensOf(address account)
        public
        view
        override
        returns (uint256)
    {
        return _allocatedTokens[account];
    }

    /**
     * @dev Return the amount of tokens that the `account` can unlock in real time
     */
    function pendingTokensOf(address account)
        public
        view
        override
        returns (uint256)
    {
        return
            _pendingTokensCalc(_vestingStartingTime, _allocatedTokens[account])
                .sub(releasedTokensOf(account));
    }

    /**
     * @dev Return the amount of tokens that the `account` can unlock per month
     */
    function unlockableTokens(address account)
        public
        view
        override
        returns (uint256)
    {
        return
            _unlockTokensCalc(_vestingStartingTime, _allocatedTokens[account])
                .sub(releasedTokensOf(account));
    }

    /**
     * @dev Return true if the vesting schedule has started
     */
    function hasVestingStarted() public view returns (bool) {
        return block.timestamp >= _vestingStartingTime;
    }

    /**
     * @dev Return the starting time of the vesting schedule
     */
    function vestingStartingTime() public view returns (uint256) {
        return _vestingStartingTime;
    }

    /**
     * @dev Return the unchangeable maximum vesting starting time
     */
    function maxVestingStartingTime() public view returns (uint256) {
        return _maxVestingStartingTime;
    }

    /**
     * @dev Return the pte pool address
     */
    function getPTEPoolAddress() public view returns (address) {
        return _ptePoolAddress;
    }

    /**
     * @dev Return the staking pool address
     */
    function getStakingPoolAddress() public view returns (address) {
        return _stakingPoolAddress;
    }
}
