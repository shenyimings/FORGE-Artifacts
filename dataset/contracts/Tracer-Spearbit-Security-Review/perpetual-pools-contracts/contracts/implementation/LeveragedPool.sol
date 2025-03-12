//SPDX-License-Identifier: CC-BY-NC-ND-4.0
pragma solidity 0.8.7;

import "../interfaces/ILeveragedPool.sol";
import "../interfaces/IPoolCommitter.sol";
import "../interfaces/IPoolToken.sol";
import "../interfaces/IPausable.sol";
import "../interfaces/IInvariantCheck.sol";
import "../interfaces/ITwoStepGovernance.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./PoolSwapLibrary.sol";
import "../interfaces/IOracleWrapper.sol";

/// @title The pool contract itself
contract LeveragedPool is ILeveragedPool, Initializable, IPausable, ITwoStepGovernance {
    using SafeERC20 for IERC20;
    // #### Globals

    // Each balance is the amount of quote tokens in the pair
    uint256 public override shortBalance;
    uint256 public override longBalance;
    uint256 public constant LONG_INDEX = 0;
    uint256 public constant SHORT_INDEX = 1;

    address public override governance;
    uint32 public override frontRunningInterval;
    uint32 public override updateInterval;
    bytes16 public fee;
    bytes16 public override leverageAmount;

    address public override provisionalGovernance;
    bool public override paused;
    bool public override governanceTransferInProgress;
    address public keeper;
    address public feeAddress;
    address public secondaryFeeAddress;
    uint256 public secondaryFeeSplitPercent; // Split to secondary fee address as a percentage.
    address public override quoteToken;
    address public override poolCommitter;
    address public override oracleWrapper;
    address public override settlementEthOracle;
    address public invariantCheckContract;
    IInvariantCheck public invariantCheck;
    address[2] public tokens;
    uint256 public override lastPriceTimestamp; // The last time the pool was upkept

    string public override poolName;

    // #### Modifiers

    /**
     * @dev Check invariants before function body only. This is used in functions where the state of the pool is updated after exiting PoolCommitter (i.e. executeCommitments)
     */
    modifier checkInvariantsBeforeFunction() {
        invariantCheck.checkInvariants(address(this));
        require(!paused, "Pool is paused");
        _;
    }

    modifier checkInvariantsAfterFunction() {
        require(!paused, "Pool is paused");
        _;
        invariantCheck.checkInvariants(address(this));
        require(!paused, "Pool is paused");
    }

    modifier onlyKeeper() {
        require(msg.sender == keeper, "msg.sender not keeper");
        _;
    }

    modifier onlyInvariantCheckContract() {
        require(msg.sender == invariantCheckContract, "msg.sender not invariantCheckContract");
        _;
    }

    modifier onlyPoolCommitter() {
        require(msg.sender == poolCommitter, "msg.sender not poolCommitter");
        _;
    }

    modifier onlyGov() {
        require(msg.sender == governance, "msg.sender not governance");
        _;
    }

    // #### Functions

    function initialize(ILeveragedPool.Initialization calldata initialization) external override initializer {
        require(initialization._feeAddress != address(0), "Fee address cannot be 0 address");
        require(initialization._quoteToken != address(0), "Quote token cannot be 0 address");
        require(initialization._oracleWrapper != address(0), "Oracle wrapper cannot be 0 address");
        require(initialization._settlementEthOracle != address(0), "Keeper oracle cannot be 0 address");
        require(initialization._owner != address(0), "Owner cannot be 0 address");
        require(initialization._keeper != address(0), "Keeper cannot be 0 address");
        require(initialization._longToken != address(0), "Long token cannot be 0 address");
        require(initialization._shortToken != address(0), "Short token cannot be 0 address");
        require(initialization._poolCommitter != address(0), "PoolCommitter cannot be 0 address");
        require(initialization._invariantCheckContract != address(0), "InvariantCheck cannot be 0 address");
        require(initialization._fee < PoolSwapLibrary.WAD_PRECISION, "Fee >= 100%");
        require(initialization._secondaryFeeSplitPercent <= 100, "Secondary fee split cannot exceed 100%");
        require(initialization._updateInterval != 0, "Update interval cannot be 0");

        // set the owner of the pool. This is governance when deployed from the factory
        governance = initialization._owner;

        // Setup variables
        keeper = initialization._keeper;
        oracleWrapper = initialization._oracleWrapper;
        settlementEthOracle = initialization._settlementEthOracle;
        quoteToken = initialization._quoteToken;
        frontRunningInterval = initialization._frontRunningInterval;
        updateInterval = initialization._updateInterval;
        fee = PoolSwapLibrary.convertUIntToDecimal(initialization._fee);
        leverageAmount = PoolSwapLibrary.convertUIntToDecimal(initialization._leverageAmount);
        feeAddress = initialization._feeAddress;
        secondaryFeeAddress = initialization._secondaryFeeAddress;
        secondaryFeeSplitPercent = initialization._secondaryFeeSplitPercent;
        lastPriceTimestamp = block.timestamp;
        poolName = initialization._poolName;
        tokens[LONG_INDEX] = initialization._longToken;
        tokens[SHORT_INDEX] = initialization._shortToken;
        poolCommitter = initialization._poolCommitter;
        invariantCheckContract = initialization._invariantCheckContract;
        invariantCheck = IInvariantCheck(initialization._invariantCheckContract);
        emit PoolInitialized(
            initialization._longToken,
            initialization._shortToken,
            initialization._quoteToken,
            initialization._poolName
        );
    }

    /**
     * @notice Execute a price change
     * @param _oldPrice Previous price of the underlying asset
     * @param _newPrice New price of the underlying asset
     * @dev Throws if at least one update interval has not elapsed since last price update
     * @dev This is the entry point to upkeep a market
     * @dev Only callable by the associated `PoolKeeper` contract
     * @dev Only callable if the market is *not* paused
     */
    function poolUpkeep(int256 _oldPrice, int256 _newPrice) external override onlyKeeper checkInvariantsAfterFunction {
        require(intervalPassed(), "Update interval hasn't passed");
        // perform price change and update pool balances
        executePriceChange(_oldPrice, _newPrice);
        IPoolCommitter(poolCommitter).executeCommitments();
        lastPriceTimestamp = block.timestamp;
    }

    /**
     * @notice Pay keeper some amount in the collateral token for the perpetual pools market
     * @param to Address of the pool keeper to pay
     * @param amount Amount to pay the pool keeper
     * @return Whether the keeper is going to be paid; false if the amount exceeds the balances of the
     *         long and short pool, and true if the keeper can successfully be paid out
     * @dev Only callable by the associated `PoolKeeper` contract
     * @dev Only callable when the market is *not* paused
     */
    function payKeeperFromBalances(address to, uint256 amount)
        external
        override
        onlyKeeper
        checkInvariantsAfterFunction
        returns (bool)
    {
        uint256 _shortBalance = shortBalance;
        uint256 _longBalance = longBalance;

        // If the rewards are greater than or equal to the balances of the pool, the keeper does not get paid
        if (amount > _shortBalance + _longBalance) {
            return false;
        }

        (uint256 shortBalanceAfterRewards, uint256 longBalanceAfterRewards) = PoolSwapLibrary.getBalancesAfterFees(
            amount,
            _shortBalance,
            _longBalance
        );

        shortBalance = shortBalanceAfterRewards;
        longBalance = longBalanceAfterRewards;

        // Pay keeper
        IERC20(quoteToken).safeTransfer(to, amount);

        return true;
    }

    /**
     * @notice Transfer settlement tokens from pool to user
     * @param to Address of account to transfer to
     * @param amount Amount of quote tokens being transferred
     * @dev Only callable by the associated `PoolCommitter` contract
     * @dev Only callable when the market is *not* paused
     */
    function quoteTokenTransfer(address to, uint256 amount)
        external
        override
        onlyPoolCommitter
        checkInvariantsBeforeFunction
    {
        IERC20(quoteToken).safeTransfer(to, amount);
    }

    /**
     * @notice Transfer pool tokens from pool to user
     * @param isLongToken True if transferring long pool token; False if transferring short pool token
     * @param to Address of account to transfer to
     * @param amount Amount of pool tokens being transferred
     * @dev Only callable by the associated `PoolCommitter` contract
     * @dev Only callable when the market is *not* paused
     */
    function poolTokenTransfer(
        bool isLongToken,
        address to,
        uint256 amount
    ) external override onlyPoolCommitter checkInvariantsBeforeFunction {
        if (isLongToken) {
            IERC20(tokens[LONG_INDEX]).safeTransfer(to, amount);
        } else {
            IERC20(tokens[SHORT_INDEX]).safeTransfer(to, amount);
        }
    }

    /**
     * @notice Transfer tokens from user to account
     * @param from The account that's transferring quote tokens
     * @param to Address of account to transfer to
     * @param amount Amount of quote tokens being transferred
     * @dev Only callable by the associated `PoolCommitter` contract
     * @dev Only callable when the market is *not* paused
     */
    function quoteTokenTransferFrom(
        address from,
        address to,
        uint256 amount
    ) external override onlyPoolCommitter {
        IERC20(quoteToken).safeTransferFrom(from, to, amount);
    }

    /**
     * @notice Execute the price change once the interval period ticks over, updating the long & short
     *         balances based on the change of the feed (upwards or downwards) and paying fees
     * @param _oldPrice Old price from the oracle
     * @param _newPrice New price from the oracle
     * @dev Can only be called by poolUpkeep
     * @dev Only callable when the market is *not* paused
     * @dev Emits `PoolRebalance` if execution succeeds
     * @dev Emits `PriceChangeError` if execution does not take place
     */
    function executePriceChange(int256 _oldPrice, int256 _newPrice) internal checkInvariantsBeforeFunction {
        // prevent a division by 0 in computing the price change
        // prevent negative pricing
        if (_oldPrice <= 0 || _newPrice <= 0) {
            emit PriceChangeError(_oldPrice, _newPrice);
        } else {
            uint256 _shortBalance = shortBalance;
            uint256 _longBalance = longBalance;
            PoolSwapLibrary.PriceChangeData memory priceChangeData = PoolSwapLibrary.PriceChangeData(
                _oldPrice,
                _newPrice,
                _longBalance,
                _shortBalance,
                leverageAmount,
                fee
            );
            (
                uint256 newLongBalance,
                uint256 newShortBalance,
                uint256 longFeeAmount,
                uint256 shortFeeAmount
            ) = PoolSwapLibrary.calculatePriceChange(priceChangeData);

            unchecked {
                emit PoolRebalance(
                    int256(newShortBalance) - int256(_shortBalance),
                    int256(newLongBalance) - int256(_longBalance),
                    shortFeeAmount,
                    longFeeAmount
                );
            }
            // Update pool balances
            longBalance = newLongBalance;
            shortBalance = newShortBalance;
            // Pay the fee
            feeTransfer(longFeeAmount + shortFeeAmount);
        }
    }

    /**
     * @notice Execute the fee transfer transactions. Transfers fees to primary fee address (DAO) and secondary (pool deployer).
     *         If the DAO is the fee deployer, secondary fee address should be address(0) and all fees go to DAO.
     * @param totalFeeAmount total amount of fees paid
     */
    function feeTransfer(uint256 totalFeeAmount) internal {
        if (secondaryFeeAddress == address(0)) {
            IERC20(quoteToken).safeTransfer(feeAddress, totalFeeAmount);
        } else {
            uint256 secondaryFee = PoolSwapLibrary.mulFraction(totalFeeAmount, secondaryFeeSplitPercent, 100);
            uint256 remainder;
            unchecked {
                // secondaryFee is calculated as totalFeeAmount * secondaryFeeSplitPercent / 100
                // secondaryFeeSplitPercent <= 100 and therefore secondaryFee <= totalFeeAmount - The following line can not underflow
                remainder = totalFeeAmount - secondaryFee;
            }
            IERC20 _quoteToken = IERC20(quoteToken);
            if (secondaryFee != 0) {
                _quoteToken.safeTransfer(secondaryFeeAddress, secondaryFee);
            }
            if (remainder != 0) {
                _quoteToken.safeTransfer(feeAddress, remainder);
            }
        }
    }

    /**
     * @notice Sets the long and short balances of the pools
     * @param _longBalance New balance of the long pool
     * @param _shortBalance New balance of the short pool
     * @dev Only callable by the associated `PoolCommitter` contract
     * @dev Only callable when the market is *not* paused
     * @dev Emits a `PoolBalancesChanged` event on success
     */
    function setNewPoolBalances(uint256 _longBalance, uint256 _shortBalance) external override onlyPoolCommitter {
        longBalance = _longBalance;
        shortBalance = _shortBalance;
        emit PoolBalancesChanged(_longBalance, _shortBalance);
    }

    /**
     * @notice Mint tokens to a user
     * @param tokenType LONG_INDEX (0) or SHORT_INDEX (1) for either minting the long or short  token respectively
     * @param amount Amount of tokens to mint
     * @param minter Address of user/minter
     * @dev Only callable by the associated `PoolCommitter` contract
     * @dev Only callable when the market is *not* paused
     */
    function mintTokens(
        uint256 tokenType,
        uint256 amount,
        address minter
    ) external override onlyPoolCommitter checkInvariantsBeforeFunction {
        IPoolToken(tokens[tokenType]).mint(minter, amount);
    }

    /**
     * @notice Burn tokens by a user
     * @dev Can only be called by & used by the pool committer
     * @param tokenType LONG_INDEX (0) or SHORT_INDEX (1) for either burning the long or short  token respectively
     * @param amount Amount of tokens to burn
     * @param burner Address of user/burner
     * @dev Only callable by the associated `PoolCommitter` contract
     * @dev Only callable when the market is *not* paused
     */
    function burnTokens(
        uint256 tokenType,
        uint256 amount,
        address burner
    ) external override onlyPoolCommitter checkInvariantsAfterFunction {
        IPoolToken(tokens[tokenType]).burn(burner, amount);
    }

    /**
     * @notice Indicates whether the price was last updated more than `updateInterval` seconds ago
     * @return Whether the price was last updated more than `updateInterval` seconds ago
     * @dev Unchecked
     */
    function intervalPassed() public view override returns (bool) {
        unchecked {
            return block.timestamp >= lastPriceTimestamp + updateInterval;
        }
    }

    /**
     * @notice Updates the fee address of the pool
     * @param account New address of the fee address/receiver
     * @dev Only callable by governance
     * @dev Only callable when the market is *not* paused
     * @dev Emits `FeeAddressUpdated` event on success
     */
    function updateFeeAddress(address account) external override onlyGov {
        require(account != address(0), "Account cannot be 0 address");
        address oldFeeAddress = feeAddress;
        feeAddress = account;
        emit FeeAddressUpdated(oldFeeAddress, account);
    }

    /**
     * @notice Updates the secondary fee address of the pool
     * @param account New address of the fee address/receiver
     */
    function updateSecondaryFeeAddress(address account) external override {
        address _oldSecondaryFeeAddress = secondaryFeeAddress;
        require(msg.sender == _oldSecondaryFeeAddress);
        secondaryFeeAddress = account;
        emit SecondaryFeeAddressUpdated(_oldSecondaryFeeAddress, account);
    }

    /**
     * @notice Updates the keeper contract of the pool
     * @param _keeper New address of the keeper contract
     */
    function setKeeper(address _keeper) external override onlyGov {
        require(_keeper != address(0), "Keeper address cannot be 0 address");
        address oldKeeper = keeper;
        keeper = _keeper;
        emit KeeperAddressChanged(oldKeeper, _keeper);
    }

    /**
     * @notice Starts to transfer governance of the pool. The new governance
     *          address must call `claimGovernance` in order for this to take
     *          effect. Until this occurs, the existing governance address
     *          remains in control of the pool.
     * @param _governance New address of the governance of the pool
     * @dev First step of the two-step governance transfer process
     * @dev Sets the governance transfer flag to true
     * @dev See `claimGovernance`
     */
    function transferGovernance(address _governance) external override onlyGov {
        require(_governance != governance, "New governance address cannot be same as old governance address");
        require(_governance != address(0), "Governance address cannot be 0 address");
        provisionalGovernance = _governance;
        governanceTransferInProgress = true;
        emit ProvisionalGovernanceChanged(_governance);
    }

    /**
     * @notice Completes transfer of governance by actually changing permissions
     *          over the pool.
     * @dev Second and final step of the two-step governance transfer process
     * @dev See `transferGovernance`
     * @dev Sets the governance transfer flag to false
     * @dev After a successful call to this function, the actual governance
     *      address and the provisional governance address MUST be equal.
     */
    function claimGovernance() external override {
        require(governanceTransferInProgress, "No governance change active");
        address _provisionalGovernance = provisionalGovernance;
        require(msg.sender == _provisionalGovernance, "Not provisional governor");
        address oldGovernance = governance; /* for later event emission */
        governance = _provisionalGovernance;
        governanceTransferInProgress = false;
        emit GovernanceAddressChanged(oldGovernance, _provisionalGovernance);
    }

    /**
     * @return _latestPrice The oracle price
     * @return _data The oracleWrapper's metadata. Implementations can choose what data to return here
     * @return _lastPriceTimestamp The timestamp of the last upkeep
     * @return _updateInterval The update frequency for this pool
     * @dev To save gas so PoolKeeper does not have to make three external calls
     */
    function getUpkeepInformation()
        external
        view
        override
        returns (
            int256,
            bytes memory,
            uint256,
            uint256
        )
    {
        (int256 _latestPrice, bytes memory _data) = IOracleWrapper(oracleWrapper).getPriceAndMetadata();
        return (_latestPrice, _data, lastPriceTimestamp, updateInterval);
    }

    /**
     * @return The price of the pool's feed oracle
     */
    function getOraclePrice() external view override returns (int256) {
        return IOracleWrapper(oracleWrapper).getPrice();
    }

    /**
     * @return Addresses of the pool tokens for this pool (long and short,
     *          respectively)
     */
    function poolTokens() external view override returns (address[2] memory) {
        return tokens;
    }

    /**
     * @return Quantities of pool tokens for this pool (short and long,
     *          respectively)
     */
    function balances() external view override returns (uint256, uint256) {
        return (shortBalance, longBalance);
    }

    /**
     * @notice Withdraws all available quote asset from the pool
     * @dev Pool must be paused
     * @dev ERC20 transfer
     * @dev Only callable by governance
     */
    function withdrawQuote() external onlyGov {
        require(paused, "Pool is live");
        IERC20 quoteERC = IERC20(quoteToken);
        uint256 balance = quoteERC.balanceOf(address(this));
        IERC20(quoteToken).safeTransfer(msg.sender, balance);
        emit QuoteWithdrawn(msg.sender, balance);
    }

    /**
     * @notice Pauses the pool
     * @dev Prevents all state updates until unpaused
     */
    function pause() external override onlyInvariantCheckContract {
        paused = true;
        emit Paused();
    }

    /**
     * @notice Unpauses the pool
     * @dev Prevents all state updates until unpaused
     */
    function unpause() external override onlyGov {
        paused = false;
        emit Unpaused();
    }
}
