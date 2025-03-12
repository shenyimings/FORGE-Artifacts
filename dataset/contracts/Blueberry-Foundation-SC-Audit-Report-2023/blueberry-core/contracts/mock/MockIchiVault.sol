// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title Provides functions for deriving a pool address from the factory, tokens, and the fee
library PoolAddress {
    bytes32 internal constant POOL_INIT_CODE_HASH =
        0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /// @notice The identifying key of the pool
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @notice Returns PoolKey: the ordered tokens with the matched fee levels
    /// @param tokenA The first token of a pool, unsorted
    /// @param tokenB The second token of a pool, unsorted
    /// @param fee The fee level of the pool
    /// @return Poolkey The pool details with ordered token0 and token1 assignments
    function getPoolKey(
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal pure returns (PoolKey memory) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolKey({token0: tokenA, token1: tokenB, fee: fee});
    }

    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param factory The Uniswap V3 factory contract address
    /// @param key The PoolKey
    /// @return pool The contract address of the V3 pool
    function computeAddress(
        address factory,
        PoolKey memory key
    ) internal pure returns (address pool) {
        require(key.token0 < key.token1);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(
                                abi.encode(key.token0, key.token1, key.fee)
                            ),
                            POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "../interfaces/ichi/IICHIVault.sol";
import "../interfaces/ichi/IICHIVaultFactory.sol";

import "../libraries/UniV3/UniV3WrappedLibMockup.sol";

/**
 @notice A Uniswap V2-like interface with fungible liquidity to Uniswap V3 
 which allows for either one-sided or two-sided liquidity provision.
 ICHIVaults should be deployed by the ICHIVaultFactory. 
 ICHIVaults should not be used with tokens that charge transaction fees.  
 */
contract MockIchiVault is
    IICHIVault,
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback,
    ERC20,
    ReentrancyGuard,
    Ownable
{
    using SafeERC20 for IERC20;

    address public ichiVaultFactory;
    address public immutable override pool;
    address public immutable override token0;
    address public immutable override token1;
    bool public immutable override allowToken0;
    bool public immutable override allowToken1;
    uint24 public immutable override fee;
    int24 public immutable override tickSpacing;

    address public override affiliate;
    int24 public override baseLower;
    int24 public override baseUpper;
    int24 public override limitLower;
    int24 public override limitUpper;

    // The following three variables serve the very ////important purpose of
    // limiting inventory risk and the arbitrage opportunities made possible by
    // instant deposit & withdrawal.
    // If, in the ETHUSDT pool at an ETH price of 2500 USDT, I deposit 100k
    // USDT in a pool with 40 WETH, and then directly afterwards withdraw 50k
    // USDT and 20 WETH (this is of equivalent dollar value), I drastically
    // change the pool composition and additionally decreases deployed capital
    // by 50%. Keeping a maxTotalSupply just above our current total supply
    // means that large amounts of funds can't be deposited all at once to
    // create a large imbalance of funds or to sideline many funds.
    // Additionally, deposit maximums prevent users from using the pool as
    // a counterparty to trade assets against while avoiding uniswap fees
    // & slippage--if someone were to try to do this with a large amount of
    // capital they would be overwhelmed by the gas fees necessary to call
    // deposit & withdrawal many times.

    uint256 public override deposit0Max;
    uint256 public override deposit1Max;
    uint256 public override maxTotalSupply;
    uint256 public override hysteresis;

    uint256 public constant PRECISION = 10 ** 18;
    uint256 constant PERCENT = 100;
    address constant NULL_ADDRESS = address(0);

    uint32 public twapPeriod;

    /**
     @notice creates an instance of ICHIVault based on the pool. 
            allowToken parameters control whether the ICHIVault allows one-sided or two-sided liquidity provision
     @param _pool Uniswap V3 pool for which liquidity is managed
     @param _allowToken0 flag that indicates whether token0 is accepted during deposit
     @param _allowToken1 flag that indicates whether token1 is accepted during deposit
     @param __owner Owner of the ICHIVault
     */
    constructor(
        address _pool,
        bool _allowToken0,
        bool _allowToken1,
        address __owner,
        address _factory,
        uint32 _twapPeriod
    ) ERC20("ICHI Vault Liquidity", "ICHI_Vault_LP") {
        require(_pool != NULL_ADDRESS, "IV.constructor: zero address");
        require(
            _allowToken0 || _allowToken1,
            "IV.constructor: no allowed tokens"
        );

        ichiVaultFactory = _factory;
        pool = _pool;
        token0 = IUniswapV3Pool(_pool).token0();
        token1 = IUniswapV3Pool(_pool).token1();
        fee = IUniswapV3Pool(_pool).fee();
        allowToken0 = _allowToken0;
        allowToken1 = _allowToken1;
        twapPeriod = _twapPeriod;
        tickSpacing = IUniswapV3Pool(_pool).tickSpacing();

        transferOwnership(__owner);

        maxTotalSupply = 0; // no cap
        hysteresis = PRECISION / PERCENT; // 1% threshold
        deposit0Max = type(uint256).max; // max uint256
        deposit1Max = type(uint256).max; // max uint256
        affiliate = NULL_ADDRESS; // by default there is no affiliate address
        emit DeployICHIVault(
            msg.sender,
            _pool,
            _allowToken0,
            _allowToken1,
            __owner,
            _twapPeriod
        );
    }

    function setTwapPeriod(uint32 newTwapPeriod) external onlyOwner {
        require(newTwapPeriod > 0, "IV.setTwapPeriod: missing period");
        twapPeriod = newTwapPeriod;
        emit SetTwapPeriod(msg.sender, newTwapPeriod);
    }

    /**
     @notice Distributes shares to depositor equal to the token1 value of his deposit multiplied 
            by the ratio of total liquidity shares issued divided by the pool's AUM measured in token1 value. 
     @param deposit0 Amount of token0 transfered from sender to ICHIVault
     @param deposit1 Amount of token0 transfered from sender to ICHIVault
     @param to Address to which liquidity tokens are minted
     @param shares Quantity of liquidity tokens minted as a result of deposit
     */
    function deposit(
        uint256 deposit0,
        uint256 deposit1,
        address to
    ) external override nonReentrant returns (uint256 shares) {
        require(allowToken0 || deposit0 == 0, "IV.deposit: token0 not allowed");
        require(allowToken1 || deposit1 == 0, "IV.deposit: token1 not allowed");
        require(
            deposit0 > 0 || deposit1 > 0,
            "IV.deposit: deposits must be > 0"
        );
        require(
            deposit0 < deposit0Max && deposit1 < deposit1Max,
            "IV.deposit: deposits too large"
        );
        require(to != NULL_ADDRESS && to != address(this), "IV.deposit: to");

        // update fees for inclusion in total pool amounts
        (uint128 baseLiquidity, , ) = _position(baseLower, baseUpper);
        if (baseLiquidity > 0) {
            (uint256 burn0, uint256 burn1) = IUniswapV3Pool(pool).burn(
                baseLower,
                baseUpper,
                0
            );
            require(
                burn0 == 0 && burn1 == 0,
                "IV.deposit: unexpected burn (1)"
            );
        }

        (uint128 limitLiquidity, , ) = _position(limitLower, limitUpper);
        if (limitLiquidity > 0) {
            (uint256 burn0, uint256 burn1) = IUniswapV3Pool(pool).burn(
                limitLower,
                limitUpper,
                0
            );
            require(
                burn0 == 0 && burn1 == 0,
                "IV.deposit: unexpected burn (2)"
            );
        }

        // Spot

        uint256 price = _fetchSpot(token0, token1, currentTick(), PRECISION);

        // TWAP

        uint256 twap = _fetchTwap(pool, token0, token1, twapPeriod, PRECISION);

        // if difference between spot and twap is too big, check if the price may have been manipulated in this block
        uint256 delta = (price > twap)
            ? ((price - twap) * PRECISION) / price
            : ((twap - price) * PRECISION) / twap;
        if (delta > hysteresis)
            require(checkHysteresis(), "IV.deposit: try later");

        (uint256 pool0, uint256 pool1) = getTotalAmounts();

        // aggregated deposit
        uint256 deposit0PricedInToken1 = (deposit0 *
            ((price < twap) ? price : twap)) / PRECISION;

        if (deposit0 > 0) {
            IERC20(token0).safeTransferFrom(
                msg.sender,
                address(this),
                deposit0
            );
        }
        if (deposit1 > 0) {
            IERC20(token1).safeTransferFrom(
                msg.sender,
                address(this),
                deposit1
            );
        }

        shares = deposit1 + deposit0PricedInToken1;

        if (totalSupply() != 0) {
            uint256 pool0PricedInToken1 = (pool0 *
                ((price > twap) ? price : twap)) / PRECISION;
            shares = (shares * totalSupply()) / (pool0PricedInToken1 + pool1);
        }
        _mint(to, shares);
        emit Deposit(msg.sender, to, shares, deposit0, deposit1);
        // Check total supply cap not exceeded. A value of 0 means no limit.
        require(
            maxTotalSupply == 0 || totalSupply() <= maxTotalSupply,
            "IV.deposit: maxTotalSupply"
        );
    }

    /**
     @notice Redeems shares by sending out a percentage of the ICHIVault's AUM - 
            this percentage is equal to the percentage of total issued shares represented by the redeeemed shares.
     @param shares Number of liquidity tokens to redeem as pool assets
     @param to Address to which redeemed pool assets are sent
     @param amount0 Amount of token0 redeemed by the submitted liquidity tokens
     @param amount1 Amount of token1 redeemed by the submitted liquidity tokens
     */
    function withdraw(
        uint256 shares,
        address to
    )
        external
        override
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        require(shares > 0, "IV.withdraw: shares");
        require(to != NULL_ADDRESS, "IV.withdraw: to");

        // Withdraw liquidity from Uniswap pool
        (uint256 base0, uint256 base1) = _burnLiquidity(
            baseLower,
            baseUpper,
            _liquidityForShares(baseLower, baseUpper, shares),
            to,
            false
        );
        (uint256 limit0, uint256 limit1) = _burnLiquidity(
            limitLower,
            limitUpper,
            _liquidityForShares(limitLower, limitUpper, shares),
            to,
            false
        );

        // Push tokens proportional to unused balances
        uint256 _totalSupply = totalSupply();
        uint256 unusedAmount0 = (IERC20(token0).balanceOf(address(this)) *
            shares) / _totalSupply;
        uint256 unusedAmount1 = (IERC20(token1).balanceOf(address(this)) *
            shares) / _totalSupply;
        if (unusedAmount0 > 0) IERC20(token0).safeTransfer(to, unusedAmount0);
        if (unusedAmount1 > 0) IERC20(token1).safeTransfer(to, unusedAmount1);

        amount0 = base0 + limit0 + unusedAmount0;
        amount1 = base1 + limit1 + unusedAmount1;

        _burn(msg.sender, shares);

        emit Withdraw(msg.sender, to, shares, amount0, amount1);
    }

    /**
     @notice Updates ICHIVault's LP positions.
     @dev The base position is placed first with as much liquidity as possible and
        is typically symmetric around the current price.
        This order should use up all of one token, leaving some unused quantity of the other.
        This unused amount is then placed as a single-sided order.
     @param _baseLower The lower tick of the base position
     @param _baseUpper The upper tick of the base position
     @param _limitLower The lower tick of the limit position
     @param _limitUpper The upper tick of the limit position
     @param swapQuantity Quantity of tokens to swap;
        if quantity is positive, `swapQuantity` token0 are swaped for token1,
        if negative, `swapQuantity` token1 is swaped for token0
     */
    function rebalance(
        int24 _baseLower,
        int24 _baseUpper,
        int24 _limitLower,
        int24 _limitUpper,
        int256 swapQuantity
    ) external override nonReentrant onlyOwner {
        require(
            _baseLower < _baseUpper &&
                _baseLower % tickSpacing == 0 &&
                _baseUpper % tickSpacing == 0,
            "IV.rebalance: base position invalid"
        );
        require(
            _limitLower < _limitUpper &&
                _limitLower % tickSpacing == 0 &&
                _limitUpper % tickSpacing == 0,
            "IV.rebalance: limit position invalid"
        );

        // update fees
        (uint128 baseLiquidity, , ) = _position(baseLower, baseUpper);
        if (baseLiquidity > 0) {
            IUniswapV3Pool(pool).burn(baseLower, baseUpper, 0);
        }
        (uint128 limitLiquidity, , ) = _position(limitLower, limitUpper);
        if (limitLiquidity > 0) {
            IUniswapV3Pool(pool).burn(limitLower, limitUpper, 0);
        }

        // Withdraw all liquidity and collect all fees from Uniswap pool
        (, uint256 feesBase0, uint256 feesBase1) = _position(
            baseLower,
            baseUpper
        );
        (, uint256 feesLimit0, uint256 feesLimit1) = _position(
            limitLower,
            limitUpper
        );

        uint256 fees0 = feesBase0 + feesLimit0;
        uint256 fees1 = feesBase1 + feesLimit1;

        _burnLiquidity(
            baseLower,
            baseUpper,
            baseLiquidity,
            address(this),
            true
        );
        _burnLiquidity(
            limitLower,
            limitUpper,
            limitLiquidity,
            address(this),
            true
        );

        emit Rebalance(
            currentTick(),
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            fees0,
            fees1,
            totalSupply()
        );

        // swap tokens if required
        if (swapQuantity != 0) {
            IUniswapV3Pool(pool).swap(
                address(this),
                swapQuantity > 0,
                swapQuantity > 0 ? swapQuantity : -swapQuantity,
                swapQuantity > 0
                    ? UniV3WrappedLibMockup.MIN_SQRT_RATIO + 1
                    : UniV3WrappedLibMockup.MAX_SQRT_RATIO - 1,
                abi.encode(address(this))
            );
        }

        baseLower = _baseLower;
        baseUpper = _baseUpper;
        baseLiquidity = _liquidityForAmounts(
            baseLower,
            baseUpper,
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
        _mintLiquidity(baseLower, baseUpper, baseLiquidity);

        limitLower = _limitLower;
        limitUpper = _limitUpper;
        limitLiquidity = _liquidityForAmounts(
            limitLower,
            limitUpper,
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
        _mintLiquidity(limitLower, limitUpper, limitLiquidity);
    }

    function setFactory(address _newFactory) external onlyOwner {
        ichiVaultFactory = _newFactory;
    }

    /**
     @notice Mint liquidity in Uniswap V3 pool.
     @param tickLower The lower tick of the liquidity position
     @param tickUpper The upper tick of the liquidity position
     @param liquidity Amount of liquidity to mint
     @param amount0 Used amount of token0
     @param amount1 Used amount of token1
     */
    function _mintLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal returns (uint256 amount0, uint256 amount1) {
        if (liquidity > 0) {
            (amount0, amount1) = IUniswapV3Pool(pool).mint(
                address(this),
                tickLower,
                tickUpper,
                liquidity,
                abi.encode(address(this))
            );
        }
    }

    /**
     @notice Burn liquidity in Uniswap V3 pool.
     @param tickLower The lower tick of the liquidity position
     @param tickUpper The upper tick of the liquidity position
     @param liquidity amount of liquidity to burn
     @param to The account to receive token0 and token1 amounts
     @param collectAll Flag that indicates whether all token0 and token1 tokens should be collected 
                        or only the ones released during this burn
     @param amount0 released amount of token0
     @param amount1 released amount of token1
     */
    function _burnLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        address to,
        bool collectAll
    ) internal returns (uint256 amount0, uint256 amount1) {
        if (liquidity > 0) {
            // Burn liquidity
            (uint256 owed0, uint256 owed1) = IUniswapV3Pool(pool).burn(
                tickLower,
                tickUpper,
                liquidity
            );

            // Collect amount owed
            uint128 collect0 = collectAll
                ? type(uint128).max
                : _uint128Safe(owed0);
            uint128 collect1 = collectAll
                ? type(uint128).max
                : _uint128Safe(owed1);
            if (collect0 > 0 || collect1 > 0) {
                (amount0, amount1) = IUniswapV3Pool(pool).collect(
                    to,
                    tickLower,
                    tickUpper,
                    collect0,
                    collect1
                );
            }
        }
    }

    /**
     @notice Calculates liquidity amount for the given shares.
     @param tickLower The lower tick of the liquidity position
     @param tickUpper The upper tick of the liquidity position
     @param shares number of shares
     */
    function _liquidityForShares(
        int24 tickLower,
        int24 tickUpper,
        uint256 shares
    ) internal view returns (uint128) {
        (uint128 position, , ) = _position(tickLower, tickUpper);
        return _uint128Safe((uint256(position) * shares) / totalSupply());
    }

    /**
     @notice Returns information about the liquidity position.
     @param tickLower The lower tick of the liquidity position
     @param tickUpper The upper tick of the liquidity position
     @param liquidity liquidity amount
     @param tokensOwed0 amount of token0 owed to the owner of the position
     @param tokensOwed1 amount of token1 owed to the owner of the position
     */
    function _position(
        int24 tickLower,
        int24 tickUpper
    )
        internal
        view
        returns (uint128 liquidity, uint128 tokensOwed0, uint128 tokensOwed1)
    {
        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), tickLower, tickUpper)
        );
        (liquidity, , , tokensOwed0, tokensOwed1) = IUniswapV3Pool(pool)
            .positions(positionKey);
    }

    /**
     @notice Callback function for mint
     @dev this is where the payer transfers required token0 and token1 amounts
     @param amount0 required amount of token0
     @param amount1 required amount of token1
     @param data encoded payer's address
     */
    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        require(msg.sender == address(pool), "cb1");
        address payer = abi.decode(data, (address));

        if (payer == address(this)) {
            if (amount0 > 0) IERC20(token0).safeTransfer(msg.sender, amount0);
            if (amount1 > 0) IERC20(token1).safeTransfer(msg.sender, amount1);
        } else {
            if (amount0 > 0)
                IERC20(token0).safeTransferFrom(payer, msg.sender, amount0);
            if (amount1 > 0)
                IERC20(token1).safeTransferFrom(payer, msg.sender, amount1);
        }
    }

    /**
     @notice Callback function for swap
     @dev this is where the payer transfers required token0 and token1 amounts
     @param amount0Delta required amount of token0
     @param amount1Delta required amount of token1
     @param data encoded payer's address
     */
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        require(msg.sender == address(pool), "cb2");
        address payer = abi.decode(data, (address));

        if (amount0Delta > 0) {
            if (payer == address(this)) {
                IERC20(token0).safeTransfer(msg.sender, uint256(amount0Delta));
            } else {
                IERC20(token0).safeTransferFrom(
                    payer,
                    msg.sender,
                    uint256(amount0Delta)
                );
            }
        } else if (amount1Delta > 0) {
            if (payer == address(this)) {
                IERC20(token1).safeTransfer(msg.sender, uint256(amount1Delta));
            } else {
                IERC20(token1).safeTransferFrom(
                    payer,
                    msg.sender,
                    uint256(amount1Delta)
                );
            }
        }
    }

    /**
     @notice Checks if the last price change happened in the current block
     */
    function checkHysteresis() private view returns (bool) {
        (, , uint16 observationIndex, , , , ) = IUniswapV3Pool(pool).slot0();
        (uint32 blockTimestamp, , , ) = IUniswapV3Pool(pool).observations(
            observationIndex
        );
        return (block.timestamp != blockTimestamp);
    }

    /**
     @notice Sets the maximum liquidity token supply the contract allows
     @dev onlyOwner
     @param _maxTotalSupply The maximum liquidity token supply the contract allows
     */
    function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyOwner {
        maxTotalSupply = _maxTotalSupply;
        emit MaxTotalSupply(msg.sender, _maxTotalSupply);
    }

    /**
     @notice Sets the hysteresis threshold (in percentage points, 10**16 = 1%).
        When difference between spot price and TWAP exceeds the threshold, a check for a flashloan attack is executed
     @dev onlyOwner
     @param _hysteresis hysteresis threshold
     */
    function setHysteresis(uint256 _hysteresis) external onlyOwner {
        hysteresis = _hysteresis;
        emit Hysteresis(msg.sender, _hysteresis);
    }

    /**
     @notice Sets the affiliate account address where portion of the collected swap fees will be distributed
     @dev onlyOwner
     @param _affiliate The affiliate account address
     */
    function setAffiliate(address _affiliate) external override onlyOwner {
        affiliate = _affiliate;
        emit Affiliate(msg.sender, _affiliate);
    }

    /**
     @notice Sets the maximum token0 and token1 amounts the contract allows in a deposit
     @dev onlyOwner
     @param _deposit0Max The maximum amount of token0 allowed in a deposit
     @param _deposit1Max The maximum amount of token1 allowed in a deposit
     */
    function setDepositMax(
        uint256 _deposit0Max,
        uint256 _deposit1Max
    ) external override onlyOwner {
        deposit0Max = _deposit0Max;
        deposit1Max = _deposit1Max;
        emit DepositMax(msg.sender, _deposit0Max, _deposit1Max);
    }

    /**
     @notice Calculates token0 and token1 amounts for liquidity in a position
     @param tickLower The lower tick of the liquidity position
     @param tickUpper The upper tick of the liquidity position
     @param liquidity Amount of liquidity in the position
     */
    function _amountsForLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal view returns (uint256, uint256) {
        (uint160 sqrtRatioX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
        return
            UniV3WrappedLibMockup.getAmountsForLiquidity(
                sqrtRatioX96,
                UniV3WrappedLibMockup.getSqrtRatioAtTick(tickLower),
                UniV3WrappedLibMockup.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
    }

    /**
     @notice Calculates amount of liquidity in a position for given token0 and token1 amounts
     @param tickLower The lower tick of the liquidity position
     @param tickUpper The upper tick of the liquidity position
     @param amount0 token0 amount
     @param amount1 token1 amount
     */
    function _liquidityForAmounts(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (uint128) {
        (uint160 sqrtRatioX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
        return
            UniV3WrappedLibMockup.getLiquidityForAmounts(
                sqrtRatioX96,
                UniV3WrappedLibMockup.getSqrtRatioAtTick(tickLower),
                UniV3WrappedLibMockup.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
    }

    /**
     @notice uint128Safe function
     @param x input value
     */
    function _uint128Safe(uint256 x) internal pure returns (uint128) {
        require(x <= type(uint128).max, "IV.128_OF");
        return uint128(x);
    }

    /**
     @notice Calculates total quantity of token0 and token1 in both positions (and unused in the ICHIVault)
     @param total0 Quantity of token0 in both positions (and unused in the ICHIVault)
     @param total1 Quantity of token1 in both positions (and unused in the ICHIVault)
     */
    function getTotalAmounts()
        public
        view
        override
        returns (uint256 total0, uint256 total1)
    {
        (, uint256 base0, uint256 base1) = getBasePosition();
        (, uint256 limit0, uint256 limit1) = getLimitPosition();
        total0 = IERC20(token0).balanceOf(address(this)) + base0 + limit0;
        total1 = IERC20(token1).balanceOf(address(this)) + base1 + limit1;
    }

    /**
     @notice Calculates amount of total liquidity in the base position
     @param liquidity Amount of total liquidity in the base position
     @param amount0 Estimated amount of token0 that could be collected by burning the base position
     @param amount1 Estimated amount of token1 that could be collected by burning the base position
     */
    function getBasePosition()
        public
        view
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        (
            uint128 positionLiquidity,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = _position(baseLower, baseUpper);
        (amount0, amount1) = _amountsForLiquidity(
            baseLower,
            baseUpper,
            positionLiquidity
        );
        liquidity = positionLiquidity;
        amount0 += uint256(tokensOwed0);
        amount1 += uint256(tokensOwed1);
    }

    /**
     @notice Calculates amount of total liquidity in the limit position
     @param liquidity Amount of total liquidity in the base position
     @param amount0 Estimated amount of token0 that could be collected by burning the limit position
     @param amount1 Estimated amount of token1 that could be collected by burning the limit position
     */
    function getLimitPosition()
        public
        view
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        (
            uint128 positionLiquidity,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = _position(limitLower, limitUpper);
        (amount0, amount1) = _amountsForLiquidity(
            limitLower,
            limitUpper,
            positionLiquidity
        );
        liquidity = positionLiquidity;
        amount0 += uint256(tokensOwed0);
        amount1 += uint256(tokensOwed1);
    }

    /**
     @notice Returns current price tick
     @param tick Uniswap pool's current price tick
     */
    function currentTick() public view returns (int24 tick) {
        (, int24 tick_, , , , , bool unlocked_) = IUniswapV3Pool(pool).slot0();
        require(unlocked_, "IV.currentTick: the pool is locked");
        tick = tick_;
    }

    /**
     @notice returns equivalent _tokenOut for _amountIn, _tokenIn using spot price
     @param _tokenIn token the input amount is in
     @param _tokenOut token for the output amount
     @param _tick tick for the spot price
     @param _amountIn amount in _tokenIn
     @param amountOut equivalent anount in _tokenOut
     */
    function _fetchSpot(
        address _tokenIn,
        address _tokenOut,
        int24 _tick,
        uint256 _amountIn
    ) internal pure returns (uint256 amountOut) {
        return
            UniV3WrappedLibMockup.getQuoteAtTick(
                _tick,
                uint128(_amountIn),
                _tokenIn,
                _tokenOut
            );
    }

    /**
     @notice returns equivalent _tokenOut for _amountIn, _tokenIn using TWAP price
     @param _pool Uniswap V3 pool address to be used for price checking
     @param _tokenIn token the input amount is in
     @param _tokenOut token for the output amount
     @param _twapPeriod the averaging time period
     @param _amountIn amount in _tokenIn
     @param amountOut equivalent anount in _tokenOut
     */
    function _fetchTwap(
        address _pool,
        address _tokenIn,
        address _tokenOut,
        uint32 _twapPeriod,
        uint256 _amountIn
    ) internal view returns (uint256 amountOut) {
        // Leave twapTick as a int256 to avoid solidity casting
        (int256 twapTick, ) = UniV3WrappedLibMockup.consult(_pool, _twapPeriod);
        return
            UniV3WrappedLibMockup.getQuoteAtTick(
                int24(twapTick), // can assume safe being result from consult()
                uint128(_amountIn),
                _tokenIn,
                _tokenOut
            );
    }
}
