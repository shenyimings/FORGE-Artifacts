// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "./interfaces/external/IWETH9.sol";
import "./utils/ReentrancyGuard.sol";
import './libraries/TransferHelper.sol';
import "./libraries/SqrtPriceMath.sol";
import "./base/ERC20Permit.sol";
import "./libraries/Babylonian.sol";
import "./libraries/PriceMath.sol";
import "./libraries/PoolActions.sol";
import "./interfaces/ISorbettoStrategy.sol";
import "./interfaces/IsorbettoFragola.sol";

/// @title Sorbetto Fragola is a yield enchancement v3 contract
/// @dev Sorbetto fragola is a Uniswap V3 yield enchancement contract which acts as
/// intermediary between the user who wants to provide liquidity to specific pools
/// and earn fees from such actions. The contract ensures that user position is in 
/// range and earns maximum amount of fees available at current liquidity utilization
/// rate. 
contract SorbettoFragola is ERC20Permit, ReentrancyGuard, ISorbettoFragola {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for uint160;
    using LowGasSafeMath for uint128;
    using UnsafeMath for uint256;
    using SafeCast for uint256;
    using PoolVariables for IUniswapV3Pool;
    using PoolActions for IUniswapV3Pool;
    
    //Any data passed through by the caller via the IUniswapV3PoolActions#mint call
    struct MintCallbackData {
        address payer;
    }
    //Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    struct SwapCallbackData {
        bool zeroForOne;
    }
    // Info of each user
    struct UserInfo {
        uint256 token0Rewards; // The amount of fees in token 0
        uint256 token1Rewards; // The amount of fees in token 1
        uint256 token0PerSharePaid; // Token 0 reward debt 
        uint256 token1PerSharePaid; // Token 1 reward debt
    }

    /// @notice Emitted when user adds liquidity
    /// @param sender The address that minted the liquidity
    /// @param liquidity The amount of liquidity added by the user to position
    /// @param amount0 How much token0 was required for the added liquidity
    /// @param amount1 How much token1 was required for the added liquidity
    event Deposit(
        address indexed sender,
        uint256 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    
    /// @notice Emitted when user withdraws liquidity
    /// @param sender The address that minted the liquidity
    /// @param shares of liquidity withdrawn by the user from the position
    /// @param amount0 How much token0 was required for the added liquidity
    /// @param amount1 How much token1 was required for the added liquidity
    event Withdraw(
        address indexed sender,
        uint256 shares,
        uint256 amount0,
        uint256 amount1
    );
    
    /// @notice Emitted when fees was collected from the pool
    /// @param feesFromPool0 Total amount of fees collected in terms of token 0
    /// @param feesFromPool1 Total amount of fees collected in terms of token 1
    /// @param usersFees0 Total amount of fees collected by users in terms of token 0
    /// @param usersFees1 Total amount of fees collected by users in terms of token 1
    event CollectFees(
        uint256 feesFromPool0,
        uint256 feesFromPool1,
        uint256 usersFees0,
        uint256 usersFees1
    );

    /// @notice Emitted when sorbetto fragola changes the position in the pool
    /// @param tickLower Lower price tick of the positon
    /// @param tickUpper Upper price tick of the position
    /// @param amount0 Amount of token 0 deposited to the position
    /// @param amount1 Amount of token 1 deposited to the position
    event Rerange(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    );
    
    /// @notice Emitted when user collects his fee share
    /// @param sender User address
    /// @param fees0 Exact amount of fees claimed by the users in terms of token 0 
    /// @param fees1 Exact amount of fees claimed by the users in terms of token 1
    event RewardPaid(
        address indexed sender,
        uint256 fees0,
        uint256 fees1
    );
    
    /// @notice Shows current Sorbetto's balances
    /// @param totalAmount0 Current token0 Sorbetto's balance
    /// @param totalAmount1 Current token1 Sorbetto's balance
    event Snapshot(uint256 totalAmount0, uint256 totalAmount1);

    event TransferGovernance(address indexed previousGovernance, address indexed newGovernance);
    
    /// @notice Prevents calls from users
    modifier onlyGovernance {
        require(msg.sender == governance, "OG");
        _;
    }
    
    mapping(address => UserInfo) public userInfo; // Info of each user that provides liquidity tokens.

    // token 0 fraction
    uint256 public immutable token0DecimalPower = 1e18; //WETH
    // token 1 fraction
    uint256 public immutable token1DecimalPower = 1e6; //USDT
    /// @inheritdoc ISorbettoFragola
    address public immutable override token0;
    /// @inheritdoc ISorbettoFragola
    address public immutable override token1;
    // WETH address
    address public immutable weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // @inheritdoc ISorbettoFragola
    int24 public immutable override tickSpacing;
    uint24 immutable GLOBAL_DIVISIONER = 1e6; // for basis point (0.0001%)

    // @inheritdoc ISorbettoFragola
    IUniswapV3Pool public override pool03;
    // Maximum total supply of the PLP (69M)
    uint256 public maxTotalSupply;
    // Accrued protocol fees in terms of token0
    uint256 public accruedProtocolFees0;
    // Accrued protocol fees in terms of token1
    uint256 public accruedProtocolFees1;
    // Total lifetime accrued users fees in terms of token0
    uint256 public usersFees0;
    // Total lifetime accrued users fees in terms of token1
    uint256 public usersFees1;
    // intermediate variable for user fee token0 calculation
    uint256 public token0PerShareStored;
    // intermediate variable for user fee token1 calculation
    uint256 public token1PerShareStored;
    //Universal multiplier used to properly calculate user share
    uint256 public override universalMultiplier;
    
    // Address of the Sorbetto's owner
    address public governance;
    // Pending to claim ownership address
    address public pendingGovernance;
    //Sorbetto fragola settings address
    address public strategy;
    // Current tick lower of sorbetto pool position
    int24 public override tickLower;
    // Current tick higher of sorbetto pool position
    int24 public override tickUpper;
    // Checks if sorbetto is initialized
    bool public finalized;
    
    /**
     * @dev After deploying, strategy can be set via `setStrategy()`
     * @param _pool03 Underlying Uniswap V3 pool with fee = 3000
     * @param _strategy Underlying Sorbetto Strategy for Sorbetto settings
     * @param _maxTotalSupply max total supply of PLP
     */
     constructor(
        address _pool03,
        address _strategy,
        uint256 _maxTotalSupply
    ) ERC20("Popsicle LP V3 WETH/USDT", "PLP") ERC20Permit("Popsicle LP V3 WETH/USDT") {
        pool03 = IUniswapV3Pool(_pool03);
        strategy = _strategy;
        token0 = pool03.token0();
        token1 = pool03.token1();
        tickSpacing = pool03.tickSpacing();
        maxTotalSupply = _maxTotalSupply;
        governance = msg.sender;
    }
    //initialize strategy
    function init() external onlyGovernance {
        require(!finalized, "F");
        finalized = true;
        int24 baseThreshold = tickSpacing * ISorbettoStrategy(strategy).tickRangeMultiplier();
        (uint160 sqrtPriceX96, int24 currentTick, , , , , ) = pool03.slot0();
        int24 tickFloor = PoolVariables.floor(currentTick, tickSpacing);
        
        tickLower = tickFloor - baseThreshold;
        tickUpper = tickFloor + baseThreshold;
        PoolVariables.checkRange(tickLower, tickUpper); //check ticks also for overflow/underflow
        universalMultiplier = PriceMath.token0ValuePrice(sqrtPriceX96, token0DecimalPower);
    }
    
    /// @inheritdoc ISorbettoFragola
     function deposit(
        uint256 amount0Desired,
        uint256 amount1Desired
    )
        external
        payable
        override
        nonReentrant
        checkDeviation
        updateVault(msg.sender)
        returns (
            uint256 shares,
            uint256 amount0,
            uint256 amount1
        )
    {
        require(amount0Desired > 0 && amount1Desired > 0, "ANV");

        // compute the liquidity amount
        uint128 liquidity = pool03.liquidityForAmounts(amount0Desired, amount1Desired, tickLower, tickUpper);
        
        (amount0, amount1) = pool03.mint(
            address(this),
            tickLower,
            tickUpper,
            liquidity,
            abi.encode(MintCallbackData({payer: msg.sender})));

        shares = amount0.mul(universalMultiplier).unsafeDiv(token1DecimalPower).add(amount1.mul(1e12));

        _mint(msg.sender, shares);
        require(totalSupply() <= maxTotalSupply, "MTS");
        refundETH();
        emit Deposit(msg.sender, shares, amount0, amount1);
    }
    
    /// @inheritdoc ISorbettoFragola
    function withdraw(
        uint256 shares
    ) 
        external
        override
        nonReentrant
        checkDeviation
        updateVault(msg.sender)
        returns (
            uint256 amount0,
            uint256 amount1
        )
    {
        require(shares > 0, "S");


        (amount0, amount1) = pool03.burnLiquidityShare(tickLower, tickUpper, totalSupply(), shares,  msg.sender);
        
        // Burn shares
        _burn(msg.sender, shares);
        emit Withdraw(msg.sender, shares, amount0, amount1);
    }
    
    /// @inheritdoc ISorbettoFragola
    function rerange() external override nonReentrant checkDeviation updateVault(address(0)) {

        //Burn all liquidity from pool to rerange for Sorbetto's balances.
        pool03.burnAllLiquidity(tickLower, tickUpper);
        

        // Emit snapshot to record balances
        uint256 balance0 = _balance0();
        uint256 balance1 = _balance1();
        emit Snapshot(balance0, balance1);

        int24 baseThreshold = tickSpacing * ISorbettoStrategy(strategy).tickRangeMultiplier();

        //Get exact ticks depending on Sorbetto's balances
        (tickLower, tickUpper) = pool03.getPositionTicks(balance0, balance1, baseThreshold, tickSpacing);

        //Get Liquidity for Sorbetto's balances
        uint128 liquidity = pool03.liquidityForAmounts(balance0, balance1, tickLower, tickUpper);
        
        // Add liquidity to the pool
        (uint256 amount0, uint256 amount1) = pool03.mint(
            address(this),
            tickLower,
            tickUpper,
            liquidity,
            abi.encode(MintCallbackData({payer: address(this)})));
        
        emit Rerange(tickLower, tickUpper, amount0, amount1);
    }

    /// @inheritdoc ISorbettoFragola
    function rebalance() external override onlyGovernance nonReentrant checkDeviation updateVault(address(0))  {

        //Burn all liquidity from pool to rerange for Sorbetto's balances.
        pool03.burnAllLiquidity(tickLower, tickUpper);
        
        //Calc base ticks
        (uint160 sqrtPriceX96, int24 currentTick, , , , , ) = pool03.slot0();
        PoolVariables.Info memory cache = 
            PoolVariables.Info(0, 0, 0, 0, 0, 0, 0);
        int24 baseThreshold = tickSpacing * ISorbettoStrategy(strategy).tickRangeMultiplier();
        (cache.tickLower, cache.tickUpper) = PoolVariables.baseTicks(currentTick, baseThreshold, tickSpacing);
        
        cache.amount0Desired = _balance0();
        cache.amount1Desired = _balance1();
        emit Snapshot(cache.amount0Desired, cache.amount1Desired);
        // Calc liquidity for base ticks
        cache.liquidity = pool03.liquidityForAmounts(cache.amount0Desired, cache.amount1Desired, cache.tickLower, cache.tickUpper);

        // Get exact amounts for base ticks
        (cache.amount0, cache.amount1) = pool03.amountsForLiquidity(cache.liquidity, cache.tickLower, cache.tickUpper);

        // Get imbalanced token
        bool zeroForOne = PoolVariables.amountsDirection(cache.amount0Desired, cache.amount1Desired, cache.amount0, cache.amount1);
        // Calculate the amount of imbalanced token that should be swapped. Calculations strive to achieve one to one ratio
        int256 amountSpecified = 
            zeroForOne
                ? int256(cache.amount0Desired.sub(cache.amount0).unsafeDiv(2))
                : int256(cache.amount1Desired.sub(cache.amount1).unsafeDiv(2)); // always positive. "overflow" safe convertion cuz we are dividing by 2

        // Calculate Price limit depending on price impact
        uint160 exactSqrtPriceImpact = sqrtPriceX96.mul160(ISorbettoStrategy(strategy).priceImpactPercentage() / 2) / 1e6;
        uint160 sqrtPriceLimitX96 = zeroForOne ?  sqrtPriceX96.sub160(exactSqrtPriceImpact) : sqrtPriceX96.add160(exactSqrtPriceImpact);

        //Swap imbalanced token as long as we haven't used the entire amountSpecified and haven't reached the price limit
        pool03.swap(
            address(this),
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            abi.encode(SwapCallbackData({zeroForOne: zeroForOne}))
        );


        (sqrtPriceX96, currentTick, , , , , ) = pool03.slot0();

        // Emit snapshot to record balances
        cache.amount0Desired = _balance0();
        cache.amount1Desired = _balance1();
        emit Snapshot(cache.amount0Desired, cache.amount1Desired);
        //Get exact ticks depending on Sorbetto's new balances
        (tickLower, tickUpper) = pool03.getPositionTicks(cache.amount0Desired, cache.amount1Desired, baseThreshold, tickSpacing);

        cache.liquidity = pool03.liquidityForAmounts(cache.amount0Desired, cache.amount1Desired, tickLower, tickUpper);

        // Add liquidity to the pool
        (cache.amount0, cache.amount1) = pool03.mint(
            address(this),
            tickLower,
            tickUpper,
            cache.liquidity,
            abi.encode(MintCallbackData({payer: address(this)})));
        emit Rerange(tickLower, tickUpper, cache.amount0, cache.amount1);
    }
    
    /// @dev Amount of token0 held as unused balance.
    function _balance0() internal view returns (uint256) {
        return IERC20(token0).balanceOf(address(this));
    }

    /// @dev Amount of token1 held as unused balance.
    function _balance1() internal view returns (uint256) {
        return IERC20(token1).balanceOf(address(this));
    }
    
    /// @dev collects fees from the pool
    function _earnFees() internal returns (uint256 userCollect0, uint256 userCollect1) {
         // Do zero-burns to poke the Uniswap pools so earned fees are updated
        pool03.burn(tickLower, tickUpper, 0);
        
        (uint256 collect0, uint256 collect1) =
            pool03.collect(
                address(this),
                tickLower,
                tickUpper,
                type(uint128).max,
                type(uint128).max
            );

        // Calculate protocol's and users share of fees
        uint256 feeToProtocol0 = collect0.mul(ISorbettoStrategy(strategy).protocolFee()).unsafeDiv(GLOBAL_DIVISIONER);
        uint256 feeToProtocol1 = collect1.mul(ISorbettoStrategy(strategy).protocolFee()).unsafeDiv(GLOBAL_DIVISIONER);
        accruedProtocolFees0 = accruedProtocolFees0.add(feeToProtocol0);
        accruedProtocolFees1 = accruedProtocolFees1.add(feeToProtocol1);
        userCollect0 = collect0.sub(feeToProtocol0);
        userCollect1 = collect1.sub(feeToProtocol1);
        usersFees0 = usersFees0.add(userCollect0);
        usersFees1 = usersFees1.add(userCollect1);
        emit CollectFees(collect0, collect1, usersFees0, usersFees1);
    }

    /// @notice Returns current Sorbetto's position in pool
    function position() external view returns (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1) {
        bytes32 positionKey = PositionKey.compute(address(this), tickLower, tickUpper);
        (liquidity, feeGrowthInside0LastX128, feeGrowthInside1LastX128, tokensOwed0, tokensOwed1) = pool03.positions(positionKey);
    }
    
    /// @notice Pull in tokens from sender. Called to `msg.sender` after minting liquidity to a position from IUniswapV3Pool#mint.
    /// @dev In the implementation you must pay to the pool for the minted liquidity.
    /// @param amount0 The amount of token0 due to the pool for the minted liquidity
    /// @param amount1 The amount of token1 due to the pool for the minted liquidity
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#mint call
    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        require(msg.sender == address(pool03), "FP");
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));
        if (amount0 > 0) pay(token0, decoded.payer, msg.sender, amount0);
        if (amount1 > 0) pay(token1, decoded.payer, msg.sender, amount1);
    }

    /// @notice Called to `msg.sender` after minting swaping from IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay to the pool for swap.
    /// @param amount0 The amount of token0 due to the pool for the swap
    /// @param amount1 The amount of token1 due to the pool for the swap
    /// @param _data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata _data
    ) external {
        require(msg.sender == address(pool03), "FP");
        require(amount0 > 0 || amount1 > 0); // swaps entirely within 0-liquidity regions are not supported
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        bool zeroForOne = data.zeroForOne;

        if (zeroForOne) pay(token0, address(this), msg.sender, uint256(amount0)); 
        else pay(token1, address(this), msg.sender, uint256(amount1));
    }

    /// @param token The token to pay
    /// @param payer The entity that must pay
    /// @param recipient The entity that will receive payment
    /// @param value The amount to pay
    function pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        if (token == weth && address(this).balance >= value) {
            // pay with WETH9
            IWETH9(weth).deposit{value: value}(); // wrap only what is needed to pay
            IWETH9(weth).transfer(recipient, value);
        } else if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            TransferHelper.safeTransfer(token, recipient, value);
        } else {
            // pull payment
            TransferHelper.safeTransferFrom(token, payer, recipient, value);
        }
    }
    
    
    /**
     * @notice Used to withdraw accumulated protocol fees.
     */
    function collectProtocolFees(
        uint256 amount0,
        uint256 amount1
    ) external nonReentrant onlyGovernance updateVault(address(0)) {
        require(accruedProtocolFees0 >= amount0, "A0F");
        require(accruedProtocolFees1 >= amount1, "A1F");
        
        uint256 balance0 = _balance0();
        uint256 balance1 = _balance1();
        
        if (balance0 >= amount0 && balance1 >= amount1)
        {
            if (amount0 > 0) pay(token0, address(this), msg.sender, amount0);
            if (amount1 > 0) pay(token1, address(this), msg.sender, amount1);
        }
        else
        {
            uint128 liquidity = pool03.liquidityForAmounts(amount0, amount1, tickLower, tickUpper);
            pool03.burnExactLiquidity(tickLower, tickUpper, liquidity, msg.sender);
        
        }
        
        accruedProtocolFees0 = accruedProtocolFees0.sub(amount0);
        accruedProtocolFees1 = accruedProtocolFees1.sub(amount1);
        emit RewardPaid(msg.sender, amount0, amount1);
    }
    
    /**
     * @notice Used to withdraw accumulated user's fees.
     */
    function collectFees(uint256 amount0, uint256 amount1) external nonReentrant updateVault(msg.sender) {
        UserInfo storage user = userInfo[msg.sender];

        require(user.token0Rewards >= amount0, "A0R");
        require(user.token1Rewards >= amount1, "A1R");

        uint256 balance0 = _balance0();
        uint256 balance1 = _balance1();

        if (balance0 >= amount0 && balance1 >= amount1) {

            if (amount0 > 0) pay(token0, address(this), msg.sender, amount0);
            if (amount1 > 0) pay(token1, address(this), msg.sender, amount1);
        }
        else {
            
            uint128 liquidity = pool03.liquidityForAmounts(amount0, amount1, tickLower, tickUpper);
            (amount0, amount1) = pool03.burnExactLiquidity(tickLower, tickUpper, liquidity, msg.sender);
        }
        user.token0Rewards = user.token0Rewards.sub(amount0);
        user.token1Rewards = user.token1Rewards.sub(amount1);
        emit RewardPaid(msg.sender, amount0, amount1);
    }
    
    // Function modifier that calls update fees reward function
    modifier updateVault(address account) {
        _updateFeesReward(account);
        _;
    }

    // Function modifier that checks if price has not moved a lot recently.
    // This mitigates price manipulation during rebalance and also prevents placing orders
    // when it's too volatile.
    modifier checkDeviation() {
        pool03.checkDeviation(ISorbettoStrategy(strategy).maxTwapDeviation(), ISorbettoStrategy(strategy).twapDuration());
        _;
    }
    
    // Updates user's fees reward
    function _updateFeesReward(address account) internal {
        uint liquidity = pool03.positionLiquidity(tickLower, tickUpper);
        if (liquidity == 0) return; // we can't poke when liquidity is zero
        (uint256 collect0, uint256 collect1) = _earnFees();
        
        
        token0PerShareStored = _tokenPerShare(collect0, token0PerShareStored);
        token1PerShareStored = _tokenPerShare(collect1, token1PerShareStored);

        if (account != address(0)) {
            UserInfo storage user = userInfo[msg.sender];
            user.token0Rewards = _fee0Earned(account, token0PerShareStored);
            user.token0PerSharePaid = token0PerShareStored;
            
            user.token1Rewards = _fee1Earned(account, token1PerShareStored);
            user.token1PerSharePaid = token1PerShareStored;
        }
    }
    
    // Calculates how much token0 is entitled for a particular user
    function _fee0Earned(address account, uint256 fee0PerShare_) internal view returns (uint256) {
        UserInfo memory user = userInfo[account];
        return
            balanceOf(account)
            .mul(fee0PerShare_.sub(user.token0PerSharePaid))
            .unsafeDiv(1e18)
            .add(user.token0Rewards);
    }
    
    // Calculates how much token1 is entitled for a particular user
    function _fee1Earned(address account, uint256 fee1PerShare_) internal view returns (uint256) {
        UserInfo memory user = userInfo[account];
        return
            balanceOf(account)
            .mul(fee1PerShare_.sub(user.token1PerSharePaid))
            .unsafeDiv(1e18)
            .add(user.token1Rewards);
    }
    
    // Calculates how much token is provided per LP token 
    function _tokenPerShare(uint256 collected, uint256 tokenPerShareStored) internal view returns (uint256) {
        uint _totalSupply = totalSupply();
        if (_totalSupply > 0) {
            return tokenPerShareStored
            .add(
                collected
                .mul(1e18)
                .unsafeDiv(_totalSupply)
            );
        }
        return tokenPerShareStored;
    }
    
    /// @notice Refunds any ETH balance held by this contract to the `msg.sender`
    /// @dev Useful for bundling with mint or increase liquidity that uses ether, or exact output swaps
    /// that use ether for the input amount
    function refundETH() internal {
        if (address(this).balance > 0) TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    }

    /**
     * @notice `setGovernance()` should be called by the existing governance
     * address prior to calling this function.
     */
    function setGovernance(address _governance) external onlyGovernance {
        pendingGovernance = _governance;
    }

    /**
     * @notice Governance address is not updated until the new governance
     * address has called `acceptGovernance()` to accept this responsibility.
     */
    function acceptGovernance() external {
        require(msg.sender == pendingGovernance, "PG");
        emit TransferGovernance(governance, pendingGovernance);
        pendingGovernance = address(0);
        governance = msg.sender;
    }

    // Sets maximum total supply of the PLP
    function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyGovernance {
        maxTotalSupply = _maxTotalSupply;
    }

    // Sets new strategy contract address for new settings
    function setStrategy(address _strategy) external onlyGovernance {
        require(_strategy != address(0), "NA");
        strategy = _strategy;
    }
}
