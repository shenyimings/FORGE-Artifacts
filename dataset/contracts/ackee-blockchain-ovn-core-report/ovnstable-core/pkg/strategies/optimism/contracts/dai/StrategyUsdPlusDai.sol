// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/core/contracts/interfaces/IUsdPlusToken.sol";
import "@overnight-contracts/core/contracts/interfaces/IExchange.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";


contract StrategyUsdPlusDai is Strategy {

    // --- structs

    struct StrategyParams {
        address usdcToken;
        address daiToken;
        address usdPlus;
        address exchange;
        address oracleDai;
        address oracleUsdc;
        address uniswapV3Router;
        uint24 poolUsdcDaiFee;
    }

    // --- params

    IERC20 public daiToken;
    IERC20 public usdcToken;
    IUsdPlusToken public usdPlus;
    IExchange public exchange;
    IPriceFeed public oracleDai;
    IPriceFeed public oracleUsdc;
    ISwapRouter public uniswapV3Router;
    uint24 public poolUsdcDaiFee;
    uint256 public daiDm;
    uint256 public usdcDm;
    uint256 public swapSlippage;

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
        daiToken = IERC20(params.daiToken);
        usdcToken = IERC20(params.usdcToken);
        usdPlus = IUsdPlusToken(params.usdPlus);
        exchange = IExchange(params.exchange);
        oracleDai = IPriceFeed(params.oracleDai);
        oracleUsdc = IPriceFeed(params.oracleUsdc);
        uniswapV3Router = ISwapRouter(params.uniswapV3Router);
        poolUsdcDaiFee = params.poolUsdcDaiFee;
        daiDm = 10 ** IERC20Metadata(params.daiToken).decimals();
        usdcDm = 10 ** IERC20Metadata(params.usdcToken).decimals();

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(daiToken), "Some token not compatible");

        // swap dai to usdc
        uint256 daiBalance = daiToken.balanceOf(address(this));
        daiToken.approve(address(uniswapV3Router), daiBalance);

        uint256 minAmount = OvnMath.subBasisPoints(_oracleDaiToUsdc(daiBalance), swapSlippageBP);

        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(daiToken),
            address(usdcToken),
            poolUsdcDaiFee,
            address(this),
            daiBalance,
            minAmount
        );

        // mint usdPlus
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        usdcToken.approve(address(exchange), usdcBalance);
        IExchange.MintParams memory params = IExchange.MintParams({
            asset: address(usdcToken),
            amount: usdcBalance,
            referral: ""
        });
        exchange.mint(params);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(daiToken), "Some token not compatible");

        uint256 usdPlusBalance = usdPlus.balanceOf(address(this));
        if (usdPlusBalance == 0) {
            return 0;
        }

        // add 1 bp and 1e13 for swap slippage
        uint256 usdPlusAmount = OvnMath.addBasisPoints(_oracleDaiToUsdc(_amount + 1e13), swapSlippageBP);
        if (usdPlusAmount >= usdPlusBalance) {
            usdPlusAmount = usdPlusBalance;
        }

        // redeem usdPlus
        exchange.redeem(address(usdcToken), usdPlusAmount);

        // swap usdc to dai
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        usdcToken.approve(address(uniswapV3Router), usdcBalance);

        uint256 minAmount = OvnMath.subBasisPoints(_oracleUsdcToDai(usdcBalance), swapSlippageBP);

        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(usdcToken),
            address(daiToken),
            poolUsdcDaiFee,
            address(this),
            usdcBalance,
            minAmount
        );

        return daiToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(daiToken), "Some token not compatible");

        uint256 usdPlusBalance = usdPlus.balanceOf(address(this));
        if (usdPlusBalance == 0) {
            return 0;
        }

        // redeem usdPlus
        exchange.redeem(address(usdcToken), usdPlusBalance);

        // swap usdc to dai
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        usdcToken.approve(address(uniswapV3Router), usdcBalance);

        uint256 minAmount = OvnMath.subBasisPoints(_oracleUsdcToDai(usdcBalance), swapSlippageBP);

        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(usdcToken),
            address(daiToken),
            poolUsdcDaiFee,
            address(this),
            usdcBalance,
            minAmount
        );

        return daiToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return OvnMath.subBasisPoints(_totalValue(), 4 + swapSlippageBP); // unstake 0.04% + swap slippage
    }

    function _totalValue() internal view returns (uint256) {
        uint256 usdPlusBalance = usdPlus.balanceOf(address(this));
        return _oracleUsdcToDai(usdPlusBalance);
    }

    function _claimRewards(address _to) internal override returns (uint256) {
        return 0;
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
