// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "../constants/addresses.sol";
import "../interfaces/IExchange.sol";
import "../interfaces/ILiquidityTokenMath.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/ITreasury.sol";
import "../AddressAccessor.sol";

contract TNGBLLiquidityManager is AddressAccessor, Pausable {
    uint256 public uniswapV3LPTokenId;

    uint256 private _minSizePercent; // percent of USDR market cap

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _pause();
    }

    function depositLPToken(uint256 tokenId)
        external
        whenPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IERC721(addressProvider.getAddress(UNISWAP_V3_NFT_MANAGER_ADDRESS))
            .transferFrom(msg.sender, address(this), tokenId);
        uniswapV3LPTokenId = tokenId;
        _unpause();
    }

    function getTokenAmounts()
        external
        view
        returns (uint256 tngblAmount, uint256 underlyingAmount)
    {
        (tngblAmount, underlyingAmount) = _getTokenAmounts(true);
    }

    function increaseLiquidity(uint256 underlyingAmount)
        external
        whenNotPaused
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        (
            address nonfungiblePositionManager,
            address underlying,
            address tngbl,
            address tngblOracle,
            address treasury
        ) = abi.decode(
                addressProvider.getAddresses(
                    abi.encode(
                        UNISWAP_V3_NFT_MANAGER_ADDRESS,
                        UNDERLYING_ADDRESS,
                        TNGBL_ADDRESS,
                        TNGBL_ORACLE_ADDRESS,
                        TREASURY_ADDRESS
                    )
                ),
                (address, address, address, address, address)
            );

        require(msg.sender == treasury, "caller is not treasury");

        IERC20(underlying).transferFrom(
            treasury,
            address(this),
            underlyingAmount
        );
        (address token0, address token1, ) = _getPoolInfo(
            nonfungiblePositionManager
        );

        _collectFees(nonfungiblePositionManager);

        amount0 = IERC20(token0).balanceOf(address(this));
        amount1 = IERC20(token1).balanceOf(address(this));

        uint8 underlyingDecimals = IERC20Metadata(underlying).decimals();
        if (token0 == underlying) {
            uint256 required = _toTNGBL(
                amount0,
                underlyingDecimals,
                tngblOracle
            );
            if (required > amount1) {
                IERC20(tngbl).transferFrom(
                    treasury,
                    address(this),
                    required - amount1
                );
                amount1 = required;
            }
        } else {
            uint256 required = _toTNGBL(
                amount1,
                underlyingDecimals,
                tngblOracle
            );
            if (required > amount0) {
                IERC20(tngbl).transferFrom(
                    treasury,
                    address(this),
                    required - amount0
                );
                amount1 = required;
            }
        }

        if (amount0 > 0 && amount1 > 0) {
            IERC20(token0).approve(nonfungiblePositionManager, amount0);
            IERC20(token1).approve(nonfungiblePositionManager, amount1);

            INonfungiblePositionManager.IncreaseLiquidityParams
                memory params = INonfungiblePositionManager
                    .IncreaseLiquidityParams({
                        tokenId: uniswapV3LPTokenId,
                        amount0Desired: amount0,
                        amount1Desired: amount1,
                        amount0Min: 1,
                        amount1Min: 1,
                        deadline: block.timestamp
                    });

            (liquidity, amount0, amount1) = INonfungiblePositionManager(
                nonfungiblePositionManager
            ).increaseLiquidity(params);
        }
    }

    function initializePool(
        uint160 sqrtPrice,
        uint24 fee,
        uint256 tngblAmount,
        uint256 underlyingAmount
    ) external whenPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        (
            address nonfungiblePositionManager,
            address underlying,
            address tngbl
        ) = abi.decode(
                addressProvider.getAddresses(
                    abi.encode(
                        UNISWAP_V3_NFT_MANAGER_ADDRESS,
                        UNDERLYING_ADDRESS,
                        TNGBL_ADDRESS
                    )
                ),
                (address, address, address)
            );
        IERC20(tngbl).transferFrom(msg.sender, address(this), tngblAmount);
        IERC20(underlying).transferFrom(
            msg.sender,
            address(this),
            underlyingAmount
        );
        if (tngbl < underlying) {
            _createPool(
                nonfungiblePositionManager,
                tngbl,
                underlying,
                sqrtPrice,
                fee
            );
            _addLiquidity(
                nonfungiblePositionManager,
                tngbl,
                underlying,
                tngblAmount,
                underlyingAmount,
                fee
            );
        } else {
            _createPool(
                nonfungiblePositionManager,
                underlying,
                tngbl,
                sqrtPrice,
                fee
            );
            _addLiquidity(
                nonfungiblePositionManager,
                underlying,
                tngbl,
                underlyingAmount,
                tngblAmount,
                fee
            );
        }
        _unpause();
    }

    function missingLiquidity() external view returns (uint256) {
        (address underlying, address usdr, address oracle) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(
                    UNDERLYING_ADDRESS,
                    USDR_ADDRESS,
                    TNGBL_ORACLE_ADDRESS
                )
            ),
            (address, address, address)
        );

        uint256 minSize = IERC20(usdr).totalSupply() * _minSizePercent * 1e7;
        uint256 liquidity;
        {
            (
                uint256 tngblBalance,
                uint256 underlyingBalance
            ) = _getTokenAmounts(false);
            uint8 underlyingDecimals = IERC20Metadata(underlying).decimals();
            liquidity =
                underlyingBalance +
                (tngblBalance * IPriceOracle(oracle).quote(1e18)) /
                (10**(36 - underlyingDecimals));
        }
        return liquidity < minSize ? (minSize - liquidity) : 0;
    }

    function setMinSize(uint256 percent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _minSizePercent = percent;
    }

    function sweepTokens() external onlyRole(DEFAULT_ADMIN_ROLE) {
        (address underlying, address tngbl) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(UNDERLYING_ADDRESS, TNGBL_ADDRESS)
            ),
            (address, address)
        );
        {
            uint256 amount = IERC20(underlying).balanceOf(address(this));
            if (amount > 0) {
                IERC20(underlying).transfer(msg.sender, amount);
            }
        }
        {
            uint256 amount = IERC20(tngbl).balanceOf(address(this));
            if (amount > 0) {
                IERC20(tngbl).transfer(msg.sender, amount);
            }
        }
    }

    function withdrawLPToken()
        external
        whenNotPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _pause();
        IERC721(addressProvider.getAddress(UNISWAP_V3_NFT_MANAGER_ADDRESS))
            .safeTransferFrom(address(this), msg.sender, uniswapV3LPTokenId);
        uniswapV3LPTokenId = 0;
    }

    function _addLiquidity(
        address nonfungiblePositionManager,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint24 fee
    ) private {
        int24 tickSpacing = int24(fee / 50);
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: (-887272 / tickSpacing) * tickSpacing,
                tickUpper: (887272 / tickSpacing) * tickSpacing,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 1,
                amount1Min: 1,
                recipient: address(this),
                deadline: block.timestamp
            });

        IERC20(token0).approve(nonfungiblePositionManager, amount0);
        IERC20(token1).approve(nonfungiblePositionManager, amount1);
        (uniswapV3LPTokenId, , , ) = INonfungiblePositionManager(
            nonfungiblePositionManager
        ).mint(params);
    }

    function _collectFees(address nonfungiblePositionManager)
        private
        returns (uint256, uint256)
    {
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: uniswapV3LPTokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });
        return
            INonfungiblePositionManager(nonfungiblePositionManager).collect(
                params
            );
    }

    function _createPool(
        address nonfungiblePositionManager,
        address token0,
        address token1,
        uint160 sqrtPrice,
        uint24 fee
    ) private returns (address pool) {
        pool = IPoolInitializer(nonfungiblePositionManager)
            .createAndInitializePoolIfNecessary(token0, token1, fee, sqrtPrice);
    }

    function _getPoolInfo(address nonfungiblePositionManager)
        private
        view
        returns (
            address token0,
            address token1,
            uint24 fee
        )
    {
        (, , token0, token1, fee, , , , , , , ) = INonfungiblePositionManager(
            nonfungiblePositionManager
        ).positions(uniswapV3LPTokenId);
    }

    function _getTokenAmounts(bool includeBalance)
        private
        view
        returns (uint256 tngblAmount, uint256 underlyingAmount)
    {
        (
            address pool,
            address nonfungiblePositionManager,
            address tngbl,
            address underlying,
            address tokenMath
        ) = abi.decode(
                addressProvider.getAddresses(
                    abi.encode(
                        UNISWAP_V3_POOL_ADDRESS,
                        UNISWAP_V3_NFT_MANAGER_ADDRESS,
                        TNGBL_ADDRESS,
                        UNDERLYING_ADDRESS,
                        UNISWAP_V3_TOKEN_MATH_ADDRESS
                    )
                ),
                (address, address, address, address, address)
            );
        (
            ,
            ,
            address token0,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(nonfungiblePositionManager).positions(
                uniswapV3LPTokenId
            );
        (uint256 amount0, uint256 amount1) = ILiquidityTokenMath(tokenMath)
            .getTokenAmounts(pool, liquidity, tickLower, tickUpper);
        if (token0 == tngbl) {
            tngblAmount = amount0;
            underlyingAmount = amount1;
        } else {
            tngblAmount = amount1;
            underlyingAmount = amount0;
        }
        if (includeBalance) {
            tngblAmount += IERC20(tngbl).balanceOf(address(this));
            underlyingAmount += IERC20(underlying).balanceOf(address(this));
        }
    }

    function _toTNGBL(
        uint256 amount,
        uint8 decimals,
        address oracle
    ) private view returns (uint256) {
        return
            (amount * 10**(36 - decimals)) / IPriceOracle(oracle).quote(1e18);
    }
}
