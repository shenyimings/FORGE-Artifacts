// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";
import "@overnight-contracts/connectors/contracts/stuff/Velodrome.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";


//TODO insert slippage to all needed places
//TODO calculate swap amount on Stake
//TODO calculate swap amount on Untake
//TODO check getAmountOut in _totalValue method

contract StrategyVelodromeUsdcWeth is Strategy {

    IERC20 public usdcToken;
    IERC20 public wethToken;
    IERC20 public veloToken;

    uint256 public usdcTokenDenominator;
    uint256 public wethTokenDenominator;

    IRouter public router;
    IGauge public gauge;
    IPair public pair;

    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleWeth;

    ISwapRouter public uniswapV3Router;
    uint24 public poolFee0;
    uint24 public poolFee1;


    // --- events

    event StrategyUpdatedParams();


    // --- structs

    struct StrategyParams {
        address usdcToken;
        address wethToken;
        address veloToken;
        address router;
        address gauge;
        address pair;
        address oracleUsdc;
        address oracleWeth;
        address uniswapV3Router;
        uint24 poolFee0;
        uint24 poolFee1;
    }


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
        usdcToken = IERC20(params.usdcToken);
        wethToken = IERC20(params.wethToken);
        veloToken = IERC20(params.veloToken);

        usdcTokenDenominator = 10 ** IERC20Metadata(params.usdcToken).decimals();
        wethTokenDenominator = 10 ** IERC20Metadata(params.wethToken).decimals();

        router = IRouter(params.router);
        gauge = IGauge(params.gauge);
        pair = IPair(params.pair);

        oracleUsdc = IPriceFeed(params.oracleUsdc);
        oracleWeth = IPriceFeed(params.oracleWeth);

        uniswapV3Router = ISwapRouter(params.uniswapV3Router);
        poolFee0 = params.poolFee0;
        poolFee1 = params.poolFee1;

        emit StrategyUpdatedParams();
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {
        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 reserveWeth, uint256 reserveUsdc,) = pair.getReserves();
        require(reserveUsdc > 10 ** 3 && reserveWeth > 10 ** 15, 'Liquidity lpToken reserves too low');

        //TODO calculate swap amount on Stake
        uint256 swapAmount = 1000000000;

        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(usdcToken),
            address(wethToken),
            poolFee1,
            address(this),
            swapAmount,
            0
        );

        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 wethBalance = wethToken.balanceOf(address(this));
        
        usdcToken.approve(address(router), usdcBalance);
        wethToken.approve(address(router), wethBalance);

        router.addLiquidity(
            address(wethToken),
            address(usdcToken),
            false,
            wethBalance,
            usdcBalance,
            0,
            0,
            address(this),
            block.timestamp
        );

        uint256 lpTokenBalance = pair.balanceOf(address(this));
        pair.approve(address(gauge), lpTokenBalance);
        gauge.deposit(lpTokenBalance, 0);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 reserveWeth, uint256 reserveUsdc,) = pair.getReserves();
        require(reserveUsdc > 10 ** 3 && reserveWeth > 10 ** 15, 'Liquidity lpToken reserves too low');

        uint256 lpTokenBalance = gauge.balanceOf(address(this));

        if (lpTokenBalance > 0) {

            //TODO calculate swap amount on Untake
            uint256 lpTokensToWithdraw = 12495438346477;

            if (lpTokensToWithdraw > lpTokenBalance) {
                lpTokensToWithdraw = lpTokenBalance;
            }

            pair.approve(address(router), lpTokensToWithdraw);
            gauge.withdraw(lpTokensToWithdraw);
            router.removeLiquidity(
                address(wethToken),
                address(usdcToken),
                false,
                lpTokensToWithdraw,
                0,
                0,
                address(this),
                block.timestamp
            );
        }

        uint256 wethBalance = wethToken.balanceOf(address(this));

        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(wethToken),
            address(usdcToken),
            poolFee1,
            address(this),
            wethBalance,
            0
        );

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 reserveWeth, uint256 reserveUsdc,) = pair.getReserves();
        require(reserveUsdc > 10 ** 3 && reserveWeth > 10 ** 15, 'Liquidity lpToken reserves too low');

        uint256 lpTokenBalance = gauge.balanceOf(address(this));
        pair.approve(address(router), lpTokenBalance);
        gauge.withdraw(lpTokenBalance);
        router.removeLiquidity(
            address(wethToken),
            address(usdcToken),
            false,
            lpTokenBalance,
            0,
            0,
            address(this),
            block.timestamp
        );

        uint256 wethBalance = wethToken.balanceOf(address(this));

        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(wethToken),
            address(usdcToken),
            poolFee1,
            address(this),
            wethBalance,
            0
        );

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 wethBalance = wethToken.balanceOf(address(this));
        uint256 usdcBalance = usdcToken.balanceOf(address(this));

        uint256 lpTokenBalance = gauge.balanceOf(address(this));
        if (lpTokenBalance > 0) {
            uint256 totalLpBalance = pair.totalSupply();
            (uint256 reserveWeth, uint256 reserveUsdc,) = pair.getReserves();
            usdcBalance += reserveUsdc * lpTokenBalance / totalLpBalance;
            wethBalance += reserveWeth * lpTokenBalance / totalLpBalance;
        }

        uint256 usdcBalanceFromWeth;
        if (wethBalance > 0) {
            if (nav) {
                usdcBalanceFromWeth = ChainlinkLibrary.convertTokenToToken(wethBalance, wethTokenDenominator, usdcTokenDenominator, oracleWeth, oracleUsdc);
            } else {
                //TODO check this code
                usdcBalanceFromWeth = pair.getAmountOut(wethBalance, address(wethToken));
            }
        }

        return usdcBalance + usdcBalanceFromWeth;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        address[] memory tokens = new address[](1);
        tokens[0] = address(veloToken);
        gauge.getReward(address(this), tokens);

        // sell rewards
        uint256 totalUsdc;

        uint256 veloBalance = veloToken.balanceOf(address(this));
        if (veloBalance > 0) {
            uint256 veloUsdc = UniswapV3Library.multiSwap(
                uniswapV3Router,
                address(veloToken),
                address(wethToken),
                address(usdcToken),
                poolFee0,
                poolFee1,
                address(this),
                veloBalance,
                0
            );

            totalUsdc += veloUsdc;
        }

        if (totalUsdc > 0) {
            usdcToken.transfer(_to, totalUsdc);
        }

        return totalUsdc;
    }

}
