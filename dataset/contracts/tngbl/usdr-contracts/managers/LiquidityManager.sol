// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "../constants/addresses.sol";
import "../interfaces/IExchange.sol";
import "../interfaces/ILiquidityTokenMath.sol";
import "../interfaces/ITreasury.sol";
import "../AddressAccessor.sol";

interface ICurveFactory {
    function deploy_metapool(
        address base_pool,
        string calldata name,
        string calldata symbol,
        address coin,
        uint256 A,
        uint256 fee,
        uint256 implementation_idx
    ) external returns (address);

    function get_base_pool(address pool) external view returns (address);

    function get_meta_n_coins(address pool)
        external
        view
        returns (uint256, uint256);

    function get_underlying_balances(address pool)
        external
        view
        returns (uint256[8] memory);

    function get_underlying_decimals(address pool)
        external
        view
        returns (uint256[8] memory);
}

interface ICurvePool {
    function underlying_coins(uint256 index) external view returns (address);
}

interface ICurveZapper {
    function add_liquidity(
        address pool,
        uint256[4] calldata deposit_amounts,
        uint256 min_mint_amount
    ) external returns (uint256);

    function exchange_underlying(
        address pool,
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external returns (uint256);
}

bytes32 constant CURVE_3POOL_ADDRESS = bytes32(keccak256("curve3Pool"));
bytes32 constant CURVE_FACTORY_ADDRESS = bytes32(keccak256("curveFactory"));
bytes32 constant CURVE_ZAPPER_ADDRESS = bytes32(keccak256("curveZapper"));

contract LiquidityManager is AddressAccessor, Pausable {
    address public curvePool;

    uint256 private _minSizePercent; // percent of USDR market cap

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _pause();
    }

    function increaseLiquidity(uint256 underlyingAmount)
        external
        whenNotPaused
    {
        (
            address underlying,
            address usdr,
            address exchange,
            address treasury,
            address curveFactory,
            address curveZapper
        ) = abi.decode(
                addressProvider.getAddresses(
                    abi.encode(
                        UNDERLYING_ADDRESS,
                        USDR_ADDRESS,
                        USDR_EXCHANGE_ADDRESS,
                        TREASURY_ADDRESS,
                        CURVE_FACTORY_ADDRESS,
                        CURVE_ZAPPER_ADDRESS
                    )
                ),
                (address, address, address, address, address, address)
            );

        require(msg.sender == treasury, "caller is not treasury");

        IERC20(underlying).transferFrom(
            treasury,
            address(this),
            underlyingAmount
        );

        _rebalancePool(exchange, underlying);

        uint256[4] memory amounts;
        amounts[0] = IERC20(usdr).balanceOf(address(this));

        if (amounts[0] > 0) {
            IERC20(usdr).approve(curveZapper, amounts[0]);
        }

        address basePool = ICurveFactory(curveFactory).get_base_pool(curvePool);
        for (uint256 i; i < 3; ) {
            address token = ICurvePool(basePool).underlying_coins(i);
            uint256 balance = IERC20(token).balanceOf(address(this));
            i++;
            IERC20(token).approve(curveZapper, balance);
            amounts[i] = balance;
        }

        ICurveZapper(curveZapper).add_liquidity(curvePool, amounts, 0);
    }

    function initializePool(uint256 a, uint256 fee)
        external
        whenPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        (address usdr, address curve3Pool, address curveFactory) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(
                    USDR_ADDRESS,
                    CURVE_3POOL_ADDRESS,
                    CURVE_FACTORY_ADDRESS
                )
            ),
            (address, address, address)
        );
        curvePool = ICurveFactory(curveFactory).deploy_metapool(
            curve3Pool,
            "USDR+3Pool",
            "USDR",
            usdr,
            a,
            fee,
            1
        );
        _unpause();
    }

    function liquidity() external view returns (uint256) {
        (uint256 usdrBalance, uint256 underlyingBalance) = _getPoolBalances();
        (address usdr, address underlying, address exchange) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(
                    USDR_ADDRESS,
                    UNDERLYING_ADDRESS,
                    USDR_EXCHANGE_ADDRESS
                )
            ),
            (address, address, address)
        );
        usdrBalance += IERC20(usdr).balanceOf(address(this));
        underlyingBalance += IERC20(underlying).balanceOf(address(this));
        return
            IExchange(exchange).scaleToUnderlying(usdrBalance) +
            underlyingBalance;
    }

    function missingLiquidity() external view returns (uint256) {
        (address exchange, address usdr) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(USDR_EXCHANGE_ADDRESS, USDR_ADDRESS)
            ),
            (address, address)
        );

        uint256 minSize = IExchange(exchange).scaleToUnderlying(
            (IERC20(usdr).totalSupply() * _minSizePercent) / 100
        );
        uint256 poolBalance;
        {
            (
                uint256 usdrBalance,
                uint256 underlyingBalance
            ) = _getPoolBalances();
            poolBalance =
                underlyingBalance +
                IExchange(exchange).scaleToUnderlying(usdrBalance);
        }
        return poolBalance < minSize ? (minSize - poolBalance) : 0;
    }

    function setMinSize(uint256 percent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _minSizePercent = percent;
    }

    function sweepToken(address token) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 amount = IERC20(token).balanceOf(address(this));
        if (amount > 0) {
            IERC20(token).transfer(msg.sender, amount);
        }
    }

    function sweepTokens() external onlyRole(DEFAULT_ADMIN_ROLE) {
        (address underlying, address usdr) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(UNDERLYING_ADDRESS, USDR_ADDRESS)
            ),
            (address, address)
        );
        sweepToken(underlying);
        sweepToken(usdr);
    }

    function withdrawLPToken() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 amount = IERC20(curvePool).balanceOf(address(this));
        require(amount > 0, "no tokens available");
        IERC20(curvePool).transfer(msg.sender, amount);
    }

    function _getCoinIndex(address token) private view returns (uint256 index) {
        address curveFactory = addressProvider.getAddress(
            CURVE_FACTORY_ADDRESS
        );
        address basePool = ICurveFactory(curveFactory).get_base_pool(curvePool);
        while (index < 3) {
            address coin = ICurvePool(basePool).underlying_coins(index);
            if (coin == token) break;
            index++;
        }
        require(index < 3, "invalid token");
        index++;
    }

    function _getPoolBalances()
        private
        view
        returns (uint256 usdrBalance, uint256 underlyingBalance)
    {
        address curveFactory = addressProvider.getAddress(
            CURVE_FACTORY_ADDRESS
        );
        address pool = curvePool;
        ICurveFactory factory = ICurveFactory(curveFactory);
        (, uint256 nCoins) = factory.get_meta_n_coins(curvePool);
        uint256[8] memory balances = factory.get_underlying_balances(pool);
        uint256[8] memory decimals = factory.get_underlying_decimals(pool);
        usdrBalance = balances[0];
        for (uint256 i = 1; i < nCoins; i++) {
            underlyingBalance += balances[i] * (10**(18 - decimals[i]));
        }
    }

    function _rebalancePool(address exchange, address underlying) private {
        (uint256 usdrBalance, uint256 underlyingBalance) = _getPoolBalances();
        uint256 scaledUSDRBalance = IExchange(exchange).scaleToUnderlying(
            usdrBalance
        );
        uint256 swapAmount;
        if (scaledUSDRBalance > underlyingBalance) {
            swapAmount = (scaledUSDRBalance - underlyingBalance) >> 1;
        }
        if (swapAmount > 0) {
            underlyingBalance = IERC20(underlying).balanceOf(address(this));
            if (underlyingBalance < swapAmount) {
                swapAmount = underlyingBalance;
            }
            if (swapAmount > 0) {
                address curveZapper = addressProvider.getAddress(
                    CURVE_ZAPPER_ADDRESS
                );
                IERC20(underlying).approve(curveZapper, swapAmount);
                uint128 i = uint128(_getCoinIndex(underlying));
                ICurveZapper(curveZapper).exchange_underlying(
                    curvePool,
                    int128(i),
                    0,
                    swapAmount,
                    1
                );
            }
        }
    }
}
