// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";
import "@overnight-contracts/connectors/contracts/stuff/Beethovenx.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/connectors/contracts/stuff/Gamma.sol";
import "@overnight-contracts/connectors/contracts/stuff/KyberSwap.sol";


contract StrategyGammaUsdcDai is Strategy {

    // --- events

    IERC20 public usdc;
    IERC20 public dai;
    IERC20 public op;

    IHypervisor public lpToken;
    IUniProxy public uniProxy;
    IMasterChef public masterChef;
    uint256 public pid;

    IVault public beethovenxVault;
    bytes32 public beethovenxPoolIdUsdc;
    bytes32 public beethovenxPoolIdDaiUsdtUsdc;
    bytes32 public beethovenxPoolIdDai;
    IERC20 public bbRfAUsdc;
    IERC20 public bbRfADai;

    ISwapRouter public uniswapV3Router;
    uint24 public poolFeeOpUsdc;

    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleDai;

    uint256 public usdcDm;
    uint256 public daiDm;

    IRouter public kyberSwapRouter;
    uint24 public poolUsdcDaiFee;

    // --- structs

    struct StrategyParams {
        address usdc;
        address dai;
        address op;
        address lpToken;
        address uniProxy;
        address masterChef;
        uint64 pid;
        address beethovenxVault;
        bytes32 beethovenxPoolIdUsdc;
        bytes32 beethovenxPoolIdDaiUsdtUsdc;
        bytes32 beethovenxPoolIdDai;
        address bbRfAUsdc;
        address bbRfADai;
        address uniswapV3Router;
        uint24 poolFeeOpUsdc;
        address oracleUsdc;
        address oracleDai;
        address kyberSwapRouter;
        uint24 poolUsdcDaiFee;
    }

    // --- events

    event StrategyUpdatedParams();

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }

    // --- Setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
        usdc = IERC20(params.usdc);
        dai = IERC20(params.dai);
        op = IERC20(params.op);

        lpToken = IHypervisor(params.lpToken);
        uniProxy = IUniProxy(params.uniProxy);
        masterChef = IMasterChef(params.masterChef);
        pid = params.pid;

        beethovenxVault = IVault(params.beethovenxVault);
        beethovenxPoolIdUsdc = params.beethovenxPoolIdUsdc;
        beethovenxPoolIdDaiUsdtUsdc = params.beethovenxPoolIdDaiUsdtUsdc;
        beethovenxPoolIdDai = params.beethovenxPoolIdDai;
        bbRfAUsdc = IERC20(params.bbRfAUsdc);
        bbRfADai = IERC20(params.bbRfADai);

        uniswapV3Router = ISwapRouter(params.uniswapV3Router);
        poolFeeOpUsdc = params.poolFeeOpUsdc;

        oracleUsdc = IPriceFeed(params.oracleUsdc);
        oracleDai = IPriceFeed(params.oracleDai);

        usdcDm = 10 ** IERC20Metadata(params.usdc).decimals();
        daiDm = 10 ** IERC20Metadata(params.dai).decimals();

        kyberSwapRouter = IRouter(params.kyberSwapRouter);
        poolUsdcDaiFee = params.poolUsdcDaiFee;

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdc), "Some token not compatible");

        // calculate needed USDC to swap to DAI
        (uint256 amountUsdcCurrent, uint256 amountDaiCurrent) = lpToken.getTotalAmounts();
        uint256 usdcBalance = usdc.balanceOf(address(this));
        uint256 daiBalance = dai.balanceOf(address(this));
        BeethovenLibrary.SwapParams memory swapParams = BeethovenLibrary.SwapParams({
            beethovenxVault: beethovenxVault,
            kind: IVault.SwapKind.GIVEN_IN,
            token0: address(usdc),
            token1: address(bbRfAUsdc),
            token2: address(bbRfADai),
            token3: address(dai),
            poolId0: beethovenxPoolIdUsdc,
            poolId1: beethovenxPoolIdDaiUsdtUsdc,
            poolId2: beethovenxPoolIdDai,
            amount: 0,
            sender: address(this),
            recipient: address(this)
        });
        BeethovenLibrary.CalculateParams memory calculateParams = BeethovenLibrary.CalculateParams({
            amount0Total: usdcBalance,
            totalLpBalance: 0,
            reserve0: amountUsdcCurrent,
            reserve1: amountDaiCurrent,
            denominator0: usdcDm,
            denominator1: daiDm,
            precision: 1
        });
        uint256 amountUsdcToSwap = BeethovenLibrary.getAmount1InToken0(swapParams, calculateParams);

        // swap USDC to needed DAI amount
        swapParams.amount = amountUsdcToSwap;
        BeethovenLibrary.batchSwap(swapParams);

        // add liquidity
        usdcBalance = usdc.balanceOf(address(this));
        daiBalance = dai.balanceOf(address(this));
        usdc.approve(address(lpToken), usdcBalance);
        dai.approve(address(lpToken), daiBalance);
        uint256 lpTokenAmount = uniProxy.deposit(usdcBalance, daiBalance, address(this), address(lpToken), [uint256(0), uint256(0), uint256(0), uint256(0)]);

        // stake
        lpToken.approve(address(masterChef), lpTokenAmount);
        masterChef.deposit(pid, lpTokenAmount, address(this));
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdc), "Some token not compatible");

        // calculating need amount lp - depends on amount USDC/DAI
        (uint256 amountUsdcCurrent, uint256 amountDaiCurrent) = lpToken.getTotalAmounts();
        uint256 totalLpBalance = lpToken.totalSupply();
        BeethovenLibrary.SwapParams memory swapParams = BeethovenLibrary.SwapParams({
            beethovenxVault: beethovenxVault,
            kind: IVault.SwapKind.GIVEN_IN,
            token0: address(dai),
            token1: address(bbRfADai),
            token2: address(bbRfAUsdc),
            token3: address(usdc),
            poolId0: beethovenxPoolIdDai,
            poolId1: beethovenxPoolIdDaiUsdtUsdc,
            poolId2: beethovenxPoolIdUsdc,
            amount: 0,
            sender: address(this),
            recipient: address(this)
        });
        BeethovenLibrary.CalculateParams memory calculateParams = BeethovenLibrary.CalculateParams({
            // add 1 bp and 10 for unstake more than requested
            amount0Total: OvnMath.addBasisPoints(_amount + 10, 1),
            totalLpBalance: totalLpBalance,
            reserve0: amountUsdcCurrent,
            reserve1: amountDaiCurrent,
            denominator0: usdcDm,
            denominator1: daiDm,
            precision: 1
        });
        uint256 amountLp = BeethovenLibrary.getAmountLpTokens(swapParams, calculateParams);
        if (amountLp > totalLpBalance) {
            amountLp = totalLpBalance;
        }

        // unstake
        masterChef.withdraw(pid, amountLp, address(this));

        // remove liquidity
        lpToken.approve(address(uniProxy), amountLp);
        lpToken.withdraw(amountLp, address(this), address(this), [uint256(0), uint256(0), uint256(0), uint256(0)]);

        // swap dai to usdc
        swapParams.amount = dai.balanceOf(address(this));
        BeethovenLibrary.batchSwap(swapParams);

        return usdc.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdc), "Some token not compatible");

        // count balanceLP for unstake
        (uint256 amountLp,) = masterChef.userInfo(pid, address(this));
        if (amountLp == 0) {
            return usdc.balanceOf(address(this));
        }

        // unstake
        masterChef.withdraw(pid, amountLp, address(this));

        // remove liquidity
        lpToken.approve(address(uniProxy), amountLp);
        lpToken.withdraw(amountLp, address(this), address(this), [uint256(0), uint256(0), uint256(0), uint256(0)]);

        // swap dai to usdc
        BeethovenLibrary.SwapParams memory swapParams = BeethovenLibrary.SwapParams({
            beethovenxVault: beethovenxVault,
            kind: IVault.SwapKind.GIVEN_IN,
            token0: address(dai),
            token1: address(bbRfADai),
            token2: address(bbRfAUsdc),
            token3: address(usdc),
            poolId0: beethovenxPoolIdDai,
            poolId1: beethovenxPoolIdDaiUsdtUsdc,
            poolId2: beethovenxPoolIdUsdc,
            amount: dai.balanceOf(address(this)),
            sender: address(this),
            recipient: address(this)
        });
        BeethovenLibrary.batchSwap(swapParams);

        return usdc.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 usdcBalance = usdc.balanceOf(address(this));
        uint256 daiBalance = dai.balanceOf(address(this));

        (uint256 amountLp,) = masterChef.userInfo(pid, address(this));
        if (amountLp > 0) {
            (uint256 amountUsdcCurrent, uint256 amountDaiCurrent) = lpToken.getTotalAmounts();
            usdcBalance += amountUsdcCurrent * amountLp / lpToken.totalSupply();
            daiBalance += amountDaiCurrent * amountLp / lpToken.totalSupply();
        }

        if (daiBalance > 0) {
            uint256 daiBalanceInUsdc = _oracleDaiToUsdc(daiBalance);
            if (!nav) {
                daiBalanceInUsdc = OvnMath.subBasisPoints(daiBalanceInUsdc, 1);
            }
            usdcBalance += daiBalanceInUsdc;
        }

        return usdcBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        (uint256 amountLp,) = masterChef.userInfo(pid, address(this));
        if (amountLp > 0) {
            masterChef.deposit(pid, 0, address(this));
        }

        // sell rewards
        uint256 totalUsdc;

        uint256 opBalance = op.balanceOf(address(this));
        if (opBalance > 0) {
            uint256 opUsdc = UniswapV3Library.singleSwap(
                uniswapV3Router,
                address(op),
                address(usdc),
                poolFeeOpUsdc,
                address(this),
                opBalance,
                0
            );
            totalUsdc += opUsdc;
        }

        if (totalUsdc > 0) {
            usdc.transfer(_to, totalUsdc);
        }

        return totalUsdc;
    }

    function _oracleDaiToUsdc(uint256 daiAmount) internal view returns (uint256) {
        uint256 priceDai = uint256(oracleDai.latestAnswer());
        uint256 priceUsdc = uint256(oracleUsdc.latestAnswer());
        return ChainlinkLibrary.convertTokenToToken(daiAmount, daiDm, usdcDm, priceDai, priceUsdc);
    }

    function _oracleUsdcToDai(uint256 usdcAmount) internal view returns (uint256) {
        uint256 priceDai = uint256(oracleDai.latestAnswer());
        uint256 priceUsdc = uint256(oracleUsdc.latestAnswer());
        return ChainlinkLibrary.convertTokenToToken(usdcAmount, usdcDm, daiDm, priceUsdc, priceDai);
    }

}
