// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/connectors/contracts/stuff/Synapse.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


contract StrategyUniV3DaiUsdt is Strategy, IERC721Receiver {

    // --- params

    IERC20 public usdc;
    IERC20 public usdt;
    IERC20 public dai;

    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleUsdt;
    IPriceFeed public oracleDai;

    ISwap public synapse;

    INonfungiblePositionManager public npm;
    uint24 public fee;
    IUniswapV3Pool public pool;

    int24 public tickLower;
    int24 public tickUpper;

    uint256 public tokenId;

    uint256 public usdcDm;
    uint256 public usdtDm;
    uint256 public daiDm;

    uint256 allowedSwapSlippage;
    uint256 allowedStakeSlippage;

    // --- events
    event StrategyUpdatedParams();


    // --- structs

    struct StrategyParams {
        address usdc;
        address usdt;
        address dai;
        address oracleUsdc;
        address oracleUsdt;
        address oracleDai;
        address synapse;
        address npm;
        uint24 fee;
        address pool;
        int24 tickLower;
        int24 tickUpper;
        uint256 allowedSwapSlippage;
        uint256 allowedStakeSlippage;
    }


    // --- constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- setters

    function setParams(StrategyParams calldata params) external onlyAdmin {

        usdc = IERC20(params.usdc);
        usdt = IERC20(params.usdt);
        dai = IERC20(params.dai);

        oracleUsdc = IPriceFeed(params.oracleUsdc);
        oracleUsdt = IPriceFeed(params.oracleUsdt);
        oracleDai = IPriceFeed(params.oracleDai);

        synapse = ISwap(params.synapse);

        npm = INonfungiblePositionManager(params.npm);
        pool = IUniswapV3Pool(params.pool);
        fee = params.fee;
        tickLower = params.tickLower;
        tickUpper = params.tickUpper;

        allowedSwapSlippage = params.allowedSwapSlippage;
        allowedStakeSlippage = params.allowedStakeSlippage;

        usdcDm = 10 ** IERC20Metadata(params.usdc).decimals();
        usdtDm = 10 ** IERC20Metadata(params.usdt).decimals();
        daiDm = 10 ** IERC20Metadata(params.dai).decimals();

        dai.approve(address(npm), type(uint256).max);
        usdt.approve(address(npm), type(uint256).max);

        emit StrategyUpdatedParams();
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(isSamePrices(), "The pool is very unbalanced");

        uint256 sellBound = 10**7;

        if (daiToUsd(dai.balanceOf(address(this))) > sellBound) {
            SynapseLibrary.swap(synapse, address(dai), address(usdc), dai.balanceOf(address(this)), 0);
        }

        if (usdtToUsd(usdt.balanceOf(address(this))) > sellBound) {
            SynapseLibrary.swap(synapse, address(usdt), address(usdc), usdt.balanceOf(address(this)), 0);
        }

        _amount = usdc.balanceOf(address(this));

        (uint256 am0, uint256 am1) = getPoolPrice(_amount);

        uint256 daiBalance = _amount * am0 / (am0 + am1);
        uint256 usdtBalance = _amount - daiBalance;
        uint256 daiAmountMin = OvnMath.subBasisPoints(usdToDai(usdcToUsd(daiBalance)), allowedSwapSlippage);
        uint256 usdtAmountMin = OvnMath.subBasisPoints(usdToUsdt(usdcToUsd(usdtBalance)), allowedSwapSlippage);
        SynapseLibrary.swap(synapse, address(usdc), address(dai), daiBalance, daiAmountMin);
        SynapseLibrary.swap(synapse, address(usdc), address(usdt), usdtBalance, usdtAmountMin);

        uint256 daiAmount = dai.balanceOf(address(this));
        uint256 usdtAmount = usdt.balanceOf(address(this));

        if (tokenId == 0) {
            INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
                token0 : address(dai),
                token1 : address(usdt),
                fee: fee,
                tickLower : tickLower,
                tickUpper : tickUpper,
                amount0Desired : daiAmount,
                amount1Desired : usdtAmount,
                amount0Min : 0,
                amount1Min : 0,
                recipient : address(this),
                deadline : block.timestamp
            });

            (tokenId,,,) = npm.mint(params);

        } else {
            INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: daiAmount,
                amount1Desired: usdtAmount,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

            npm.increaseLiquidity(params);
        }

    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        if (tokenId == 0) {
            return 0;
        }

        require(isSamePrices(), "The pool is very unbalanced");

        uint256 _realAmount = _amount;
        _amount = OvnMath.reverseSubBasisPoints(_amount, allowedSwapSlippage + allowedStakeSlippage);


        (uint256 am0, uint256 am1) = getAssetPoolRatio();
        uint256 p = _amount * am0 / (am0 + am1);

        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            usdToDai(usdcToUsd(p)),
            10**20
        );

        INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager.DecreaseLiquidityParams({
            tokenId: tokenId,
            liquidity: liquidity,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });

        npm.decreaseLiquidity(params);

        INonfungiblePositionManager.CollectParams memory collectParam = INonfungiblePositionManager.CollectParams(tokenId, address(this), type(uint128).max, type(uint128).max);
        npm.collect(collectParam);


        uint256 daiBalance = dai.balanceOf(address(this));
        uint256 usdtBalance = usdt.balanceOf(address(this));
        uint256 daiAmountMin = OvnMath.subBasisPoints(usdToUsdc(daiToUsd(daiBalance)), allowedSwapSlippage);
        uint256 usdtAmountMin = OvnMath.subBasisPoints(usdToUsdc(usdtToUsd(usdtBalance)), allowedSwapSlippage);
        SynapseLibrary.swap(synapse, address(dai), address(usdc), daiBalance, daiAmountMin);
        SynapseLibrary.swap(synapse, address(usdt), address(usdc), usdtBalance, usdtAmountMin);


        return _realAmount;
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {


        if (tokenId != 0) {
            require(isSamePrices(), "The pool is very unbalanced");

            (,,,,,,,uint128 liquidity,,,,) = npm.positions(tokenId);
            INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

            npm.decreaseLiquidity(params);

            INonfungiblePositionManager.CollectParams memory collectParam = INonfungiblePositionManager.CollectParams(tokenId, address(this), type(uint128).max, type(uint128).max);
            npm.collect(collectParam);
            tokenId = 0;
        }

        uint256 daiBalance = dai.balanceOf(address(this));
        uint256 usdtBalance = usdt.balanceOf(address(this));
        uint256 daiAmountMin = OvnMath.subBasisPoints(usdToUsdc(daiToUsd(daiBalance)), allowedSwapSlippage);
        uint256 usdtAmountMin = OvnMath.subBasisPoints(usdToUsdc(usdtToUsd(usdtBalance)), allowedSwapSlippage);
        SynapseLibrary.swap(synapse, address(dai), address(usdc), daiBalance, daiAmountMin);
        SynapseLibrary.swap(synapse, address(usdt), address(usdc), usdtBalance, usdtAmountMin);

        return usdc.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {
        (uint256 balance0, uint256 balance1) = (0, 0);
        if (tokenId > 0) {
            (,,,,,,,uint128 liquidity,,,,) = npm.positions(tokenId);
            if (liquidity > 0) {
                (uint160 sqrtRatioX96,,,,,,) = pool.slot0();
                uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
                uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
                (balance0, balance1) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity);
            }
        }
        uint256 daiBalance = usdToUsdc(daiToUsd(balance0 + dai.balanceOf(address(this))));
        uint256 usdtBalance = usdToUsdc(usdtToUsd(balance1 + usdt.balanceOf(address(this))));
        return daiBalance + usdtBalance + usdc.balanceOf(address(this));
    }

    function getAssetPoolRatio() internal view returns (uint256, uint256) {

        (uint256 amount0, uint256 amount1) = (0, 0);
        (,,,,,,,uint128 liquidity,,,,) = npm.positions(tokenId);
        if (liquidity > 0) {
            (uint160 sqrtRatioX96,,,,,,) = pool.slot0();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
            (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity);
        }

        return (daiToUsd(amount0), usdtToUsd(amount1));
    }

    function isSamePrices() internal view returns (bool) {
        (uint160 sqrtRatioX96,,,,,,) = pool.slot0();
        uint256 poolPrice = getPriceBySqrtRatio(sqrtRatioX96);
        uint256 oraclePrice = usdToUsdt(daiToUsd(daiDm));
        uint256 deltaPrice;
        if (poolPrice > oraclePrice) {
            deltaPrice = poolPrice - oraclePrice;
        } else {
            deltaPrice = oraclePrice - poolPrice;
        }
        return (deltaPrice * 10000 / oraclePrice <= allowedStakeSlippage);
    }

    function daiToUsd(uint256 amount) public view returns (uint256) {
        return amount * uint256(oracleDai.latestAnswer()) / daiDm / 100;
    }

    function usdtToUsd(uint256 amount) public view returns (uint256) {
        return amount * uint256(oracleUsdt.latestAnswer()) / usdtDm / 100;
    }

    function usdcToUsd(uint256 amount) public view returns (uint256) {
        return amount * uint256(oracleUsdc.latestAnswer()) / usdcDm / 100;
    }

    function usdToUsdc(uint256 amount) public view returns (uint256) {
        return amount * 100 * usdcDm / uint256(oracleUsdc.latestAnswer());
    }

    function usdToDai(uint256 amount) public view returns (uint256) {
        return amount * 100 * daiDm / uint256(oracleDai.latestAnswer());
    }

    function usdToUsdt(uint256 amount) public view returns (uint256) {
        return amount * 100 * usdtDm / uint256(oracleUsdt.latestAnswer());
    }

    function getPoolPrice(uint256 _amount) internal view returns (uint256, uint256) {

        (uint160 sqrtRatioX96,,,,,,) = pool.slot0();
        uint160 sa = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sb = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(sqrtRatioX96, sa, sb, 10**30, _amount);
        uint256 amount0 = uint256(SqrtPriceMath.getAmount0Delta(sqrtRatioX96, sb, int128(liquidity)));
        uint256 amount1 = uint256(SqrtPriceMath.getAmount1Delta(sa, sqrtRatioX96, int128(liquidity)));

        return (daiToUsd(amount0), usdtToUsd(amount1));
    }


    function getPriceBySqrtRatio(uint160 sqrtRatio) public view returns (uint256) {
        uint256 price = FullMath.mulDiv(uint256(sqrtRatio) * 10**10, uint256(sqrtRatio) * 10**8, 2 ** (96+96));
        return price;
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = x / 2 + 1;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function getPriceByTick(int24 tick) public view returns (uint256) {
        uint160 sqrtRatio = TickMath.getSqrtRatioAtTick(tick);
        uint256 price = FullMath.mulDiv(uint256(sqrtRatio) * 10**10, uint256(sqrtRatio) * 10**8, 2 ** (96+96));
        return price;
    }

    function _claimRewards(address _beneficiary) internal override returns (uint256) {

        INonfungiblePositionManager.CollectParams memory collectParam = INonfungiblePositionManager.CollectParams(tokenId, address(this), type(uint128).max, type(uint128).max);
        npm.collect(collectParam);

        return 0;
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

}
