// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV2.sol";
import "@overnight-contracts/connectors/contracts/stuff/Izumi.sol";
import "@overnight-contracts/connectors/contracts/stuff/Balancer.sol";
import "@overnight-contracts/connectors/contracts/stuff/Curve.sol";

contract StrategyIzumi is Strategy, UniswapV2Exchange, IERC721Receiver {

    uint160 internal constant MIN_SQRT_RATIO = 79188560314459151373725315960; // TickMath.getSqrtRatioAtTick(-10)
    uint160 internal constant MAX_SQRT_RATIO = 79267784519130042428790663799; // TickMath.getSqrtRatioAtTick(10)
    int256 public constant MAX_VALUE = 10 ** 27;

    IERC20 public usdcToken;
    IERC20 public usdtToken;
    IERC20 public iziToken;
    IERC20 public yinToken;
    IERC20 public wethToken;

    IERC721 public uniswapToken;

    uint256 public usdcTokenDenominator;
    uint256 public usdtTokenDenominator;
    uint256 public iziTokenDenominator;
    uint256 public yinTokenDenominator;

    uint256 public tokenId;

    INonfungiblePositionManager public uniswapPositionManager;
    IUniswapV3Pool public uniswapV3Pool;
    IMiningFixRangeBoost public izumiBoost;
    ISwapRouter public uniswapV3Router;

    IVault public balancerVault;
    bytes32 public balancerPoolId;

    IStableSwapPool public aavePool;


    // --- events

    event StrategyUpdatedTokens(address usdcToken, address usdtToken, address iziToken, address yinToken, address uniswapToken, address wethToken);
    event StrategyUpdatedParams(address uniswapPositionManager, address uniswapV3Pool, address izumiBoost, address uniswapV3Router, address balancerVault, bytes32 balancerPoolId, address aavePool);

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _usdtToken,
        address _iziToken,
        address _yinToken,
        address _uniswapToken,
        address _wethToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_usdtToken != address(0), "Zero address not allowed");
        require(_iziToken != address(0), "Zero address not allowed");
        require(_yinToken != address(0), "Zero address not allowed");
        require(_uniswapToken != address(0), "Zero address not allowed");
        require(_wethToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        usdtToken = IERC20(_usdtToken);
        iziToken = IERC20(_iziToken);
        yinToken = IERC20(_yinToken);
        wethToken = IERC20(_wethToken);
        uniswapToken = IERC721(_uniswapToken);

        usdcTokenDenominator = 10 ** IERC20Metadata(_usdcToken).decimals();
        usdtTokenDenominator = 10 ** IERC20Metadata(_usdtToken).decimals();
        iziTokenDenominator = 10 ** IERC20Metadata(_iziToken).decimals();
        yinTokenDenominator = 10 ** IERC20Metadata(_yinToken).decimals();

        emit StrategyUpdatedTokens(_usdcToken, _usdtToken, _iziToken, _yinToken, _uniswapToken, _wethToken);

    }

    function setParams(
        address _uniswapPositionManager,
        address _uniswapV3Pool,
        address _izumiBoost,
        address _uniswapV3Router,
        bytes32 _balancerPoolId,
        address _balancerVault,
        address _aavePool,
        address _uniswapV2Router
    ) external onlyAdmin {

        require(_uniswapPositionManager != address(0), "Zero address not allowed");
        require(_uniswapV3Pool != address(0), "Zero address not allowed");
        require(_uniswapV3Router != address(0), "Zero address not allowed");
        require(_izumiBoost != address(0), "Zero address not allowed");
        require(_balancerPoolId != 0, "Zero address not allowed");
        require(_balancerVault != address(0), "Zero address not allowed");
        require(_aavePool != address(0), "Zero address not allowed");

        uniswapPositionManager = INonfungiblePositionManager(_uniswapPositionManager);
        uniswapV3Pool = IUniswapV3Pool(_uniswapV3Pool);
        izumiBoost = IMiningFixRangeBoost(_izumiBoost);
        uniswapV3Router = ISwapRouter(_uniswapV3Router);

        _setUniswapRouter(_uniswapV2Router);

        balancerPoolId = _balancerPoolId;
        balancerVault = IVault(_balancerVault);

        aavePool = IStableSwapPool(_aavePool);

        emit StrategyUpdatedParams(_uniswapPositionManager, _uniswapV3Pool,  _izumiBoost, _uniswapV3Router, _balancerVault, _balancerPoolId, _aavePool);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {
        require(_asset == address(usdcToken), "Some token not compatible");
        if (tokenId == 0) {
            // create NFT in UniswapV3
            _mint();
        } else {
            _addLiquidity();
        }
    }


    function _removeLiquidity(uint256 _amount) internal {

        izumiBoost.withdraw(tokenId, false);

        uint256 usdtAmount = _getNeedToByUsdt(_amount);
        uint256 usdcAmount = _amount - usdtAmount;

        (uint160 sqrtPriceX96,,,,,,) = uniswapV3Pool.slot0();
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(sqrtPriceX96, MIN_SQRT_RATIO, MAX_SQRT_RATIO, usdcAmount, usdtAmount);
        INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager.DecreaseLiquidityParams(
            tokenId,
            liquidity,
            0,
            0,
            block.timestamp + 600
        );

        uniswapPositionManager.decreaseLiquidity(params);

        _collectLiquidityAndSwap();

        uniswapToken.approve(address(izumiBoost), tokenId);

        izumiBoost.deposit(tokenId, 0);
    }

    function _addLiquidity() internal {

        _buyNeedAmountUsdt();

        uint256 amount0Desired = usdcToken.balanceOf(address(this));
        uint256 amount1Desired = usdtToken.balanceOf(address(this));

        INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager.IncreaseLiquidityParams(
            tokenId,
            amount0Desired,
            amount1Desired,
            0, // TODO UPDATE slippage
            0, // TODO UPDATE slippage
            block.timestamp + 600
        );

        usdcToken.approve(address(uniswapPositionManager), amount0Desired);
        usdtToken.approve(address(uniswapPositionManager), amount1Desired);

        (uint128 liquidity, uint256 amount0, uint256 amount1) = uniswapPositionManager.increaseLiquidity(params);
    }


    function _getNeedToByUsdt(uint256 _amount) internal returns (uint256){

        (uint160 sqrtPriceX96,,,,,,) = uniswapV3Pool.slot0();

        (uint256 amountLiq0, uint256 amountLiq1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            MIN_SQRT_RATIO,
            MAX_SQRT_RATIO,
            uniswapV3Pool.liquidity());

        uint256 needUsdtValue = (_amount * amountLiq1) / (amountLiq0 + amountLiq1);
        return needUsdtValue;
    }


    function _buyNeedAmountUsdt() internal {

        uint256 neededUsdtBalance = _getNeedToByUsdt(usdcToken.balanceOf(address(this)));
        uint256 currentUsdtBalance = usdtToken.balanceOf(address(this));

        if (currentUsdtBalance <= neededUsdtBalance) {
            neededUsdtBalance = neededUsdtBalance - currentUsdtBalance;
            swap(balancerPoolId, IVault.SwapKind.GIVEN_OUT, IAsset(address(usdcToken)), IAsset(address(usdtToken)), address(this), address(this), neededUsdtBalance);
        }

    }

    function _mint() internal {

        _buyNeedAmountUsdt();

        uint256 amount0Desired = usdcToken.balanceOf(address(this));
        uint256 amount1Desired = usdtToken.balanceOf(address(this));

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams(
            address(usdcToken),
            address(usdtToken),
            uniswapV3Pool.fee(),
            - 10, // price 0.999
            10, // price 1.001
            amount0Desired,
            amount1Desired,
            (amount0Desired * 95 / 100), // slippage 1%
            (amount1Desired * 95 / 100), // slippage 1%
            address(this),
            block.timestamp + 600
        );

        usdcToken.approve(address(uniswapPositionManager), amount0Desired);
        usdtToken.approve(address(uniswapPositionManager), amount1Desired);

        (uint256 _tokenId, ,uint256 amount0, uint256 amount1) = uniswapPositionManager.mint(params);

        tokenId = _tokenId;

        uniswapToken.approve(address(izumiBoost), _tokenId);
        izumiBoost.deposit(_tokenId, 0);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {
        require(_asset == address(usdcToken), "Some token not compatible");

        if (usdcToken.balanceOf(address(this)) <= _amount) {
            _removeLiquidity(_amount);
        }

        return _amount;
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {
        require(_asset == address(usdcToken), "Some token not compatible");

        _claimRewards(address(this));

        if (tokenId == 0) {
            return usdcToken.balanceOf(address(this));
        } else {
            izumiBoost.withdraw(tokenId, false);

            (uint160 sqrtPriceX96,,,,,,) = uniswapV3Pool.slot0();
            (,,,,,,,uint128 liquidity,,,,) = uniswapPositionManager.positions(tokenId);


            (uint256 amountLiq0, uint256 amountLiq1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                MIN_SQRT_RATIO,
                MAX_SQRT_RATIO,
                liquidity);

            INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager.DecreaseLiquidityParams(
                tokenId,
                liquidity,
                (amountLiq0 * 99 / 100),
                (amountLiq1 * 99 / 100),
                block.timestamp + 600
            );

            uniswapPositionManager.decreaseLiquidity(params);

            _collectLiquidityAndSwap();
            uniswapPositionManager.burn(tokenId);

            tokenId = 0;

            return usdcToken.balanceOf(address(this));
        }
    }


    function _collectLiquidityAndSwap() internal {
        INonfungiblePositionManager.CollectParams memory collectParam = INonfungiblePositionManager.CollectParams(tokenId, address(this), type(uint128).max, type(uint128).max);

        uniswapPositionManager.collect(collectParam);


        uint256 balanceUSDT = usdtToken.balanceOf(address(this));
        usdtToken.approve(address(aavePool), balanceUSDT);

        // index 2 - USDT send coin
        // index 1 - USDC received coin
        uint256 minAmount = (aavePool.get_dy_underlying(2, 1, balanceUSDT) * 99 / 100); // slippage 1%;


        aavePool.exchange_underlying(2, 1, balanceUSDT, minAmount);

    }

    function netAssetValue() external override view returns (uint256) {
        return _getTotal();
    }

    function liquidationValue() external override view returns (uint256) {
        return _getTotal();
    }

    function _getTotal() internal view returns (uint256){

        if (tokenId == 0)
            return 0;

        (,,,,,,,uint128 liquidity,,,,) = uniswapPositionManager.positions(tokenId);
        (uint160 sqrtPriceX96,,,,,,) = uniswapV3Pool.slot0();


        (uint256 amountLiq0, uint256 amountLiq1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            MIN_SQRT_RATIO,
            MAX_SQRT_RATIO,
            liquidity);


        uint256 totalUsdc = usdcToken.balanceOf(address(this)) + amountLiq0;
        uint256 totalUsdt = usdtToken.balanceOf(address(this)) + amountLiq1;

        // index 2 - USDT
        // index 1 - USDC
        return totalUsdc + aavePool.get_dy_underlying(2, 1, totalUsdt);
    }



    function _swapIziWeth() internal  {

        uint256 balanceIzi = iziToken.balanceOf(address(this));

        if (balanceIzi == 0){
            return;
        }

        _swapExactTokensForTokens(
            address(iziToken),
            address(wethToken),
            balanceIzi,
            address(this)
        );
    }

    function _swapYinWeth() internal {

        uint256 balanceYin = yinToken.balanceOf(address(this));

        if (balanceYin == 0){
            return;
        }

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
            address(yinToken),
            address(wethToken),
            3000, // pool fee 0.3%
            address(this),
            balanceYin,
            0,
            0
        );

        yinToken.approve(address(uniswapV3Router), balanceYin);
        uint256 amountOut = uniswapV3Router.exactInputSingle(params);
    }


    function _swapWethUsdc() internal {

        uint256 balanceWeth = wethToken.balanceOf(address(this));
        if(balanceWeth == 0){
            return;
        }

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
            address(wethToken),
            address(usdcToken),
            500, // pool fee 0.05%
            address(this),
            balanceWeth,
            0,
            0
        );

        wethToken.approve(address(uniswapV3Router), balanceWeth);
        uint256 amountOut = uniswapV3Router.exactInputSingle(params);
    }

    function _claimRewards(address _to) internal override returns (uint256) {
        izumiBoost.collectReward(tokenId);

        _swapIziWeth();
        _swapYinWeth();
        _swapWethUsdc();

        uint256 balanceUSDC = usdcToken.balanceOf(address(this));
        usdcToken.transfer(_to, balanceUSDC);
        return balanceUSDC;
    }

    /// @notice Used for ERC721 safeTransferFrom
    function onERC721Received(address, address, uint256, bytes memory)
    public
    virtual
    override
    returns (bytes4)
    {
        return this.onERC721Received.selector;
    }


    function swap(
        bytes32 poolId,
        IVault.SwapKind kind,
        IAsset tokenIn,
        IAsset tokenOut,
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (uint256) {

        IERC20(address(tokenIn)).approve(address(balancerVault), IERC20(address(tokenIn)).balanceOf(address(this)));

        IVault.SingleSwap memory singleSwap;
        singleSwap.poolId = poolId;
        singleSwap.kind = kind;
        singleSwap.assetIn = tokenIn;
        singleSwap.assetOut = tokenOut;
        singleSwap.amount = amount;

        IVault.FundManagement memory fundManagement;
        fundManagement.sender = sender;
        fundManagement.fromInternalBalance = false;
        fundManagement.recipient = payable(recipient);
        fundManagement.toInternalBalance = false;

        uint256 amountReceived = balancerVault.swap(singleSwap, fundManagement, uint256(MAX_VALUE), block.timestamp + 600);
        return amountReceived;
    }
}
