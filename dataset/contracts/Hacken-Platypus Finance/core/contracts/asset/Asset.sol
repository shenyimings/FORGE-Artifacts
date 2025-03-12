// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.9;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../interfaces/IAsset.sol';

/**
 * @title Asset
 * @notice Contract presenting an asset in a pool
 * @dev Expect to be owned by Timelock for management, and _pool links to Pool for coordination
 */
contract Asset is Initializable, OwnableUpgradeable, ERC20Upgradeable, IAsset {
    using SafeERC20 for IERC20; // underlying token is ERC20

    /// @notice The underlying underlyingToken represented by this asset
    address private _underlyingToken;
    /// @notice The Pool
    address private _pool;
    /// @notice Cash balance, normally it should align with IERC20(_underlyingToken).balanceOf(address(this))
    uint256 private _cash;
    /// @notice Total liability, equals to the sum of deposit and dividend
    uint256 private _liability;
    /// @notice Owner
    address private _owner;
    /// @notice Aggregate Account of the asset
    address private _aggregateAccount;
    /// @notice _maxSupply the maximum amount of asset the pool is allowed to mint.
    /// @dev if 0, means asset has no max
    uint256 private _maxSupply;

    /// @notice An event thats emitted when pool is updated
    event PoolUpdated(address indexed previousPool, address indexed newPool);

    /// @notice An event thats emitted when max supply is updated
    event MaxSupplyUpdated(uint256 previousMaxSupply, uint256 newMaxSupply);

    /// @notice An event thats emitted when cash is addedd
    event CashAdded(uint256 previousCashPosition, uint256 cashBeingAdded);

    /// @notice An event thats emitted when cash is removed
    event CashRemoved(uint256 previousCashPosition, uint256 cashBeingRemoved);

    /// @notice An event thats emitted when liability is added
    event LiabilityAdded(uint256 previousLiabilityPosition, uint256 liabilityBeingAdded);

    /// @notice An event thats emitted when liability is removed
    event LiabilityRemoved(uint256 previousLiabilityPosition, uint256 liabilityBeingRemoved);

    /**
     * @notice Initializer.
     * @dev _ suffix to avoid shadowing underlyingToken() name and  symbol
     * @dev max decimal points for underlying token is 18.
     * @param underlyingToken_ The token represented by the asset
     * @param name_ The name of the asset
     * @param symbol_ The symbol of the asset
     * @param aggregateAccount_ The aggregate account to which the the asset belongs
     */
    function initialize(
        address underlyingToken_,
        string memory name_,
        string memory symbol_,
        address aggregateAccount_
    ) external initializer {
        require(underlyingToken_ != address(0), 'PTL:Token address cannot be zero');
        require(aggregateAccount_ != address(0), 'PTL:Aggregate account address cannot be zero');
        require(ERC20(underlyingToken_).decimals() <= 18, 'PLT:Decimals must be under 18');

        __Ownable_init();
        __ERC20_init(name_, symbol_);

        _owner = msg.sender;
        _underlyingToken = underlyingToken_;
        _aggregateAccount = aggregateAccount_;
    }

    /// @dev Modifier ensuring that certain function can only be called by pool
    modifier onlyPool() {
        require(msg.sender == _pool, 'PTL:FORBIDDEN');
        _;
    }

    /**
     * @notice Gets current asset max supply
     * @return The current max supply of asset
     */
    function maxSupply() external view override returns (uint256) {
        return _maxSupply;
    }

    /**
     * @notice Changes asset max supply. Can only be set by the contract owner.
     * @param maxSupply_ the new asset's max supply
     */
    function setMaxSupply(uint256 maxSupply_) external onlyOwner {
        emit MaxSupplyUpdated(_maxSupply, maxSupply_);
        _maxSupply = maxSupply_;
    }

    /**
     * @notice Gets current Pool address
     * @return The current Pool address for Asset
     */
    function pool() external view override returns (address) {
        return _pool;
    }

    /**
     * @notice Changes the pool. Can only be set by the contract owner.
     * @param pool_ new pool's address
     */
    function setPool(address pool_) external onlyOwner {
        require(pool_ != address(0), 'PTL:Pool address cannot be zero');
        emit PoolUpdated(_pool, pool_);
        _pool = pool_;
    }

    /**
     * @notice Changes the aggregate account. Can only be set by the contract owner.
     * @param aggregateAccount_ new aggregate account address
     */
    function setAggregateAccount(address aggregateAccount_) external onlyOwner {
        require(aggregateAccount_ != address(0), 'PTL:Aggregate Account address cannot be zero');
        _aggregateAccount = aggregateAccount_;
    }

    /**
     * @notice Returns the address of the Aggregate Account 'holding' this asset
     * @return The current Aggregate Account address for Asset
     */
    function aggregateAccount() external view override returns (address) {
        return _aggregateAccount;
    }

    /**
     * @notice Returns the address of ERC20 underlyingToken represented by this asset
     * @return The current address of ERC20 underlyingToken for Asset
     */
    function underlyingToken() external view override returns (address) {
        return _underlyingToken;
    }

    /**
     * @notice Returns the decimals of ERC20 underlyingToken
     * @return The current decimals for underlying token
     */
    function decimals() public view override(IAsset, ERC20Upgradeable) returns (uint8) {
        // `decimals` not in IERC20
        return ERC20(_underlyingToken).decimals();
    }

    /**
     * @notice Get underlying Token Balance
     * @return Returns the actual balance of ERC20 underlyingToken
     */
    function underlyingTokenBalance() external view override returns (uint256) {
        return IERC20(_underlyingToken).balanceOf(address(this));
    }

    /**
     * @notice Transfers ERC20 underlyingToken from this contract to another account. Can only be called by Pool.
     * @dev Not to be confused with transferring platypus Assets.
     * @param to address to transfer the token to
     * @param amount amount to transfer
     */
    function transferUnderlyingToken(address to, uint256 amount) external onlyPool {
        IERC20(_underlyingToken).safeTransfer(to, amount);
    }

    /**
     * @notice Mint Asset Token, expect pool coordinates other state updates. Can only be called by Pool.
     * @param to address to transfer the token to
     * @param amount amount to transfer
     */
    function mint(address to, uint256 amount) external onlyPool {
        if (this.maxSupply() != 0) {
            // if maxSupply == 0, asset is uncapped.
            require(amount + this.totalSupply() <= this.maxSupply(), 'PTL:MAX_SUPPLY_REACHED');
        }
        return _mint(to, amount);
    }

    /**
     * @notice Burn Asset Token, expect pool coordinates other state updates. Can only be called by Pool.
     * @param to address holding the tokens
     * @param amount amount to burn
     */
    function burn(address to, uint256 amount) external onlyPool {
        return _burn(to, amount);
    }

    /**
     * @notice Returns the amount of underlyingToken transferrable, expect to match underlyingTokenBalance()
     */
    function cash() external view override returns (uint256) {
        return _cash;
    }

    /**
     * @notice Adds cash, expects actual ERC20 underlyingToken got transferred in. Can only be called by Pool.
     * @param amount amount to add
     */
    function addCash(uint256 amount) external onlyPool {
        _cash += amount;
        emit CashAdded(this.cash() - amount, amount);
    }

    /**
     * @notice Deducts cash, expect actual ERC20 got transferred out (by transferUnderlyingToken()).
     * Can only be called by Pool.
     * @param amount amount to remove
     */
    function removeCash(uint256 amount) external onlyPool {
        require(_cash >= amount, 'PTL:INSUFFICIENT_CASH');
        _cash -= amount;
        emit CashRemoved(this.cash() + amount, amount);
    }

    /**
     * @notice Returns the amount of liability, the total deposit and dividend
     */
    function liability() external view override returns (uint256) {
        return _liability;
    }

    /**
     * @notice Adds deposit or dividend, expect LP underlyingToken minted in case of deposit.
     * Can only be called by Pool.
     * @param amount amount to add
     */
    function addLiability(uint256 amount) external onlyPool {
        _liability += amount;
        emit LiabilityAdded(this.liability() - amount, amount);
    }

    /**
     * @notice Removes deposit and dividend earned, expect LP underlyingToken burnt.
     * Can only be called by Pool.
     * @param amount amount to remove
     */
    function removeLiability(uint256 amount) external onlyPool {
        require(_liability >= amount, 'PTL:INSUFFICIENT_LIABILITY');
        _liability -= amount;
        emit LiabilityRemoved(this.liability() + amount, amount);
    }
}
