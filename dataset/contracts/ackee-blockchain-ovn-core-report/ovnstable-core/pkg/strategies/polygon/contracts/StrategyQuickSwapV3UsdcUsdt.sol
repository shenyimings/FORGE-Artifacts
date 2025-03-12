// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Synapse.sol";
import "@overnight-contracts/connectors/contracts/stuff/QuickSwapV3.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV2.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";


contract StrategyQuickSwapV3UsdcUsdt is Strategy, IERC721Receiver {


    // --- structs

    struct StrategyParams {
        address usdcToken;
        address usdtToken;
        address wmaticToken;
        address dquickToken;
        address quickToken;
        address nonfungiblePositionManager;
        address farmingCenter;
        address pool;
        address synapseSwapRouter;
        address quickSwapRouter;
        address oracleUsdc;
        address oracleUsdt;
        int24 tickLower;
        int24 tickUpper;
    }
    
    
    // --- params

    IERC20 public usdcToken;
    IERC20 public usdtToken;
    IERC20 public wmaticToken;
    IDragonLair public dquickToken;
    IERC20 public quickToken;

    INonfungiblePositionManager public nonfungiblePositionManager;
    IFarmingCenter public farmingCenter;
    IAlgebraPool public pool;

    ISwap public synapseSwapRouter;
    IUniswapV2Router02 public quickSwapRouter;

    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleUsdt;

    int24 public tickLower;
    int24 public tickUpper;

    uint256 public usdcTokenDenominator;
    uint256 public usdtTokenDenominator;

    uint256 public tokenId;


    // --- events

    event StrategyUpdatedParams();


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
        usdcToken = IERC20(params.usdcToken);
        usdtToken = IERC20(params.usdtToken);
        wmaticToken = IERC20(params.wmaticToken);
        dquickToken = IDragonLair(params.dquickToken);
        quickToken = IERC20(params.quickToken);

        nonfungiblePositionManager = INonfungiblePositionManager(params.nonfungiblePositionManager);
        farmingCenter = IFarmingCenter(params.farmingCenter);
        pool = IAlgebraPool(params.pool);

        synapseSwapRouter = ISwap(params.synapseSwapRouter);
        quickSwapRouter = IUniswapV2Router02(params.quickSwapRouter);

        oracleUsdc = IPriceFeed(params.oracleUsdc);
        oracleUsdt = IPriceFeed(params.oracleUsdt);

        tickLower = params.tickLower;
        tickUpper = params.tickUpper;

        usdcTokenDenominator = 10 ** IERC20Metadata(params.usdcToken).decimals();
        usdtTokenDenominator = 10 ** IERC20Metadata(params.usdcToken).decimals();

        emit StrategyUpdatedParams();
    }


    // --- logic

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint128 totalLiquidity = pool.liquidity();
        (uint256 amount0, uint256 amount1) = _getAmounts(totalLiquidity);
        require(amount0 > 10 ** 3 && amount1 > 10 ** 3, 'Liquidity reserves too low');

        if (tokenId != 0) {
            // if we already farming then exit farm
            if (farmingCenter.balanceOf(address(this)) == 1) {
                _exitFarm();
            }

            _collectFees();
        }

        // count amount usdt to swap
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        uint256 amountUsdcFromUsdt;
        if (usdtBalance > 0) {
            amountUsdcFromUsdt = SynapseLibrary.calculateSwap(
                synapseSwapRouter,
                address(usdtToken),
                address(usdcToken),
                usdtBalance
            );
        }

        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 amountUsdcToSwap;
        if (usdcBalance > 0) {
            amountUsdcToSwap = SynapseLibrary.getAmount0(
                synapseSwapRouter,
                address(usdcToken),
                address(usdtToken),
                usdcBalance - amountUsdcFromUsdt,
                amount0,
                amount1,
                usdcTokenDenominator,
                usdtTokenDenominator,
                1
            );
        }

        // swap usdc to usdt
        SynapseLibrary.swap(
            synapseSwapRouter,
            address(usdcToken),
            address(usdtToken),
            amountUsdcToSwap
        );

        // increase liquidity
        usdcBalance = usdcToken.balanceOf(address(this));
        usdtBalance = usdtToken.balanceOf(address(this));
        usdcToken.approve(address(nonfungiblePositionManager), usdcBalance);
        usdtToken.approve(address(nonfungiblePositionManager), usdtBalance);

        if (tokenId == 0) {
            INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
                token0: address(usdcToken),
                token1: address(usdtToken),
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: usdcBalance,
                amount1Desired: usdtBalance,
                amount0Min: usdcBalance * 99 / 100,
                amount1Min: usdtBalance * 99 / 100,
                recipient: address(this),
                deadline: block.timestamp
            });

            (tokenId,,,) = nonfungiblePositionManager.mint(params);

            _enterFarm();

        } else {
            INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: usdcBalance,
                amount1Desired: usdtBalance,
                amount0Min: usdcBalance * 99 / 100,
                amount1Min: usdtBalance * 99 / 100,
                deadline: block.timestamp
            });

            nonfungiblePositionManager.increaseLiquidity(params);

            // if we are not farming then enter farm
            if (farmingCenter.balanceOf(address(this)) == 0) {
                _enterFarm();
            }
        }
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint128 totalLiquidity = pool.liquidity();
        (uint256 amount0, uint256 amount1) = _getAmounts(totalLiquidity);
        require(amount0 > 10 ** 3 && amount1 > 10 ** 3, 'Liquidity reserves too low');

        // if enough free usdc to unstake
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        if (usdcBalance >= _amount) {
            return usdcBalance;
        }

        (,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
        if (liquidity > 0) {

            _exitFarm();

            // count amount to unstake
            uint256 liquidityToWithdraw = SynapseLibrary.getAmountLpTokens(
                synapseSwapRouter,
                address(usdcToken),
                address(usdtToken),
                // add 10 to _amount for smooth withdraw
                _amount + 10,
                uint256(totalLiquidity),
                amount0,
                amount1,
                usdcTokenDenominator,
                usdtTokenDenominator,
                1
            );

            // decrease liquidity
            INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: uint128(liquidityToWithdraw),
                amount0Min: amount0 * liquidityToWithdraw / totalLiquidity * 99 / 100,
                amount1Min: amount1 * liquidityToWithdraw / totalLiquidity * 99 / 100,
                deadline: block.timestamp
            });

            nonfungiblePositionManager.decreaseLiquidity(params);

            _collectFees();

            (,,,,,, liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
            if (liquidity > 0) {
                _enterFarm();
            }
        }

        // swap usdt to usdc
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        if (usdtBalance > 0) {
            uint256 amountUsdcFromUsdt = SynapseLibrary.calculateSwap(
                synapseSwapRouter,
                address(usdtToken),
                address(usdcToken),
                usdtBalance
            );

            if (amountUsdcFromUsdt > 0) {
                SynapseLibrary.swap(
                    synapseSwapRouter,
                    address(usdtToken),
                    address(usdcToken),
                    usdtBalance
                );
            }
        }

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint128 totalLiquidity = pool.liquidity();
        (uint256 amount0, uint256 amount1) = _getAmounts(totalLiquidity);
        require(amount0 > 10 ** 3 && amount1 > 10 ** 3, 'Liquidity reserves too low');

        (,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
        if (liquidity > 0) {

            _exitFarm();

            // decrease liquidity
            INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: uint128(liquidity),
                amount0Min: amount0 * liquidity / totalLiquidity * 99 / 100,
                amount1Min: amount1 * liquidity / totalLiquidity * 99 / 100,
                deadline: block.timestamp
            });

            nonfungiblePositionManager.decreaseLiquidity(params);

            _collectFees();

            (,,,,,, liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
            if (liquidity > 0) {
                _enterFarm();
            }
        }

        // swap usdt to usdc
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        if (usdtBalance > 0) {
            uint256 amountUsdcFromUsdt = SynapseLibrary.calculateSwap(
                synapseSwapRouter,
                address(usdtToken),
                address(usdcToken),
                usdtBalance
            );

            if (amountUsdcFromUsdt > 0) {
                SynapseLibrary.swap(
                    synapseSwapRouter,
                    address(usdtToken),
                    address(usdcToken),
                    usdtBalance
                );
            }
        }

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 usdtBalance = usdtToken.balanceOf(address(this));

        if (tokenId > 0) {
            (,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
            if (liquidity > 0) {
                (uint256 amount0, uint256 amount1) = _getAmounts(liquidity);
                usdcBalance += amount0;
                usdtBalance += amount1;
            }
        }

        uint256 usdcBalanceFromUsdt;
        if (usdtBalance > 0) {
            if (nav) {
                uint256 priceUsdc = uint256(oracleUsdc.latestAnswer());
                uint256 priceUsdt = uint256(oracleUsdt.latestAnswer());
                usdcBalanceFromUsdt = (usdtBalance * usdcTokenDenominator * priceUsdt) / (usdtTokenDenominator * priceUsdc);
            } else {
                usdcBalanceFromUsdt = SynapseLibrary.calculateSwap(
                    synapseSwapRouter,
                    address(usdtToken),
                    address(usdcToken),
                    usdtBalance
                );
            }
        }

        return usdcBalance + usdcBalanceFromUsdt;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        if (tokenId == 0) {
            return 0;
        }

        // collect fees
        _exitFarm();
        _collectFees();
        _enterFarm();

        // claim rewards
        (,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
        if (liquidity > 0) {
            IFarmingCenter.IncentiveKey memory incentiveKey = _getIncentiveKey();
            farmingCenter.collectRewards(incentiveKey, tokenId);
            farmingCenter.claimReward(IERC20Minimal(address(dquickToken)), address(this), 0, type(uint256).max);
            farmingCenter.claimReward(IERC20Minimal(address(wmaticToken)), address(this), 0, type(uint256).max);
        }

        // sell rewards
        uint256 totalUsdc;

        // convert dquick to quick
        uint256 dquickBalance = dquickToken.balanceOf(address(this));
        if (dquickBalance > 0) {
            dquickToken.leave(dquickBalance);
        }

        // sell quick
        uint256 quickBalance = quickToken.balanceOf(address(this));
        if (quickBalance > 0) {
            uint256 amountOutMin = UniswapV2Library.getAmountsOut(
                quickSwapRouter,
                address(quickToken),
                address(usdcToken),
                quickBalance
            );

            if (amountOutMin > 0) {
                uint256 quickUsdc = UniswapV2Library.swapExactTokensForTokens(
                    quickSwapRouter,
                    address(quickToken),
                    address(usdcToken),
                    quickBalance,
                    amountOutMin * 99 / 100,
                    address(this)
                );

                totalUsdc += quickUsdc;
            }
        }

        // sell wmatic
        uint256 wmaticBalance = wmaticToken.balanceOf(address(this));
        if (wmaticBalance > 0) {
            uint256 amountOutMin = UniswapV2Library.getAmountsOut(
                quickSwapRouter,
                address(wmaticToken),
                address(usdcToken),
                wmaticBalance
            );

            if (amountOutMin > 0) {
                uint256 wmaticUsdc = UniswapV2Library.swapExactTokensForTokens(
                    quickSwapRouter,
                    address(wmaticToken),
                    address(usdcToken),
                    wmaticBalance,
                    amountOutMin * 99 / 100,
                    address(this)
                );

                totalUsdc += wmaticUsdc;
            }
        }

        if (totalUsdc > 0) {
            usdcToken.transfer(_to, totalUsdc);
        }

        return totalUsdc;
    }

    function _getAmounts(uint128 liquidity) internal view returns (uint256 amount0, uint256 amount1) {
        (uint160 price,,,,,,) = pool.globalState();
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            price,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity
        );
    }

    function _enterFarm() internal {
        IFarmingCenter.IncentiveKey memory incentiveKey = _getIncentiveKey();

        // transfer tokenId to farm
        nonfungiblePositionManager.safeTransferFrom(address(this), address(farmingCenter), tokenId, "");

        // enter farming
        farmingCenter.enterFarming(incentiveKey, tokenId, 0, false);
    }

    function _exitFarm() internal {
        IFarmingCenter.IncentiveKey memory incentiveKey = _getIncentiveKey();

        // exit farming
        farmingCenter.exitFarming(incentiveKey, tokenId, false);

        // withdraw token
        farmingCenter.withdrawToken(tokenId, address(this), "");
    }

    function _getIncentiveKey() internal view returns (IFarmingCenter.IncentiveKey memory incentiveKey) {
        incentiveKey = IFarmingCenter.IncentiveKey({
            rewardToken: IERC20Minimal(address(dquickToken)),
            bonusRewardToken: IERC20Minimal(address(wmaticToken)),
            pool: pool,
            startTime: uint256(1663631794),
            endTime: uint256(4104559500)
        });
    }

    function _collectFees() internal {
        INonfungiblePositionManager.CollectParams memory collectParams = INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        nonfungiblePositionManager.collect(collectParams);
    }
}
