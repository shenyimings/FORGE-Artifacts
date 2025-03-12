// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV2.sol";
import "@overnight-contracts/common/contracts/libraries/LowGasSafeMath.sol";

contract StrategyQsMaiUsdt is Strategy, UniswapV2Exchange {
    using LowGasSafeMath for uint256;

    uint256 public constant minimumAmount = 1000;

    IUniswapV2Router01 public router;
    IUniswapV2Pair public pair;
    IERC20 public mai;
    IERC20 public usdt;
    IERC20 public usdc;

    // --- events

    event ConnectorQuickswapUsdtMaiUpdated(address router, address pair, address mai, address usdt, address usdc);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();

    }

    // --- setters

    function setParameters(
        address _mai,
        address _usdt,
        address _usdc,
        address _router,
        address _pair
    ) external onlyAdmin {
        require(_mai != address(0), "Zero address not allowed");
        require(_usdt != address(0), "Zero address not allowed");
        require(_usdc != address(0), "Zero address not allowed");
        require(_router != address(0), "Zero address not allowed");
        require(_pair != address(0), "Zero address not allowed");

        router = IUniswapV2Router01(_router);
        pair = IUniswapV2Pair(_pair);
        mai = IERC20(_mai);
        usdt = IERC20(_usdt);
        usdc = IERC20(_usdc);
        emit ConnectorQuickswapUsdtMaiUpdated(_router, _pair, _mai, _usdt, _usdc);
    }



    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdc), "Some token not compatible");

        (uint256 reserveA, uint256 reserveB,) = pair.getReserves();
        require(reserveA > minimumAmount && reserveB > minimumAmount, 'ConnectorQuickswapUsdtMai: Liquidity pair reserves too low');

        uint256 swapAmountUSDT = _swapToUSDT(_amount);

        uint256 amountMAI = _getSwapAmount(swapAmountUSDT, reserveB, reserveA);
        uint256 swapAmountMAI = _swapToMAI(amountMAI);

        _addLiquidity();

    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdc), "Some token not compatible");

        pair.approve(address(router), _amount);

        (uint amountA, uint amountB) = router.removeLiquidity(pair.token0(), pair.token1(), _amount, 0, 0, address(this), block.timestamp + 600);


        _swapToUSDC();


        return _amount;
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdc), "Some token not compatible");

        uint256 _amount = mai.balanceOf(address(this));

        //TODO
        return 0;
    }

    function _addLiquidity() private {

        address[] memory path = new address[](2);
        path[0] = address(mai);
        path[1] = address(usdt);

        uint256 amountUSDT = usdt.balanceOf(address(this));
        uint256 amountMAI = mai.balanceOf(address(this));
        usdt.approve(address(router), amountUSDT);
        mai.approve(address(router), amountMAI);

        (,, uint256 amountLiquidity) = router.addLiquidity(path[0], path[1], amountMAI, amountUSDT, 1, 1, address(this), block.timestamp + 600);

    }

    function _swapToMAI(uint256 amount) private returns (uint256 swapAmount) {

        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(mai);

        uint[] memory amountsOut = router.getAmountsOut(amount, path);

        usdt.approve(address(router), amount);

        uint256[] memory swapedAmounts = router.swapExactTokensForTokens(
            amount, //    uint amountIn,
            0, //          uint amountOutMin,
            path,
            address(this),
            block.timestamp + 600 // 10 mins
        );

        return swapedAmounts[1];
    }


    function _swapToUSDC() private returns (uint256 swapAmount) {

        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(usdc);

        uint256 amountUSDT = usdt.balanceOf(address(this));
        usdt.approve(address(router), amountUSDT);

        uint256[] memory swapedAmountsUSDT = router.swapExactTokensForTokens(
            amountUSDT, //    uint amountIn,
            0, //          uint amountOutMin,
            path,
            address(this),
            block.timestamp + 600 // 10 mins
        );

        path[0] = address(mai);
        path[1] = address(usdc);

        uint256 amountMAI = mai.balanceOf(address(this));
        mai.approve(address(router), amountMAI);

        uint256[] memory swapedAmountsMAI = router.swapExactTokensForTokens(
            amountMAI, //    uint amountIn,
            0, //          uint amountOutMin,
            path,
            address(this),
            block.timestamp + 600 // 10 mins
        );

        return swapedAmountsUSDT[1] + swapedAmountsMAI[1];
    }

    function _swapToUSDT(uint256 amount) private returns (uint256 swapAmount) {

        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(usdt);

        uint[] memory amountsOut = router.getAmountsOut(amount, path);

        usdc.approve(address(router), amount);

        uint256[] memory swapedAmounts = router.swapExactTokensForTokens(
            amount, //    uint amountIn,
            0, //          uint amountOutMin,
            path,
            address(this),
            block.timestamp + 600 // 10 mins
        );

        return swapedAmounts[1];
    }

    function _getSwapAmount(uint256 investmentA, uint256 reserveA, uint256 reserveB) private view returns (uint256 swapAmount) {
        uint256 halfInvestment = investmentA / 2;
        uint256 nominator = router.getAmountOut(halfInvestment, reserveA, reserveB);
        uint256 denominator = router.quote(halfInvestment, reserveA.add(halfInvestment), reserveB.sub(nominator));
        //        swapAmount = investmentA.sub(Babylonian.sqrt(halfInvestment * halfInvestment * nominator / denominator));
        return swapAmount;
    }


    function netAssetValue() external view override returns (uint256){
        return 0;
    }

    function liquidationValue() external view override returns (uint256){
        return 0;
    }

    function _claimRewards(address _to) internal override returns (uint256){
        return 0;
    }


}
