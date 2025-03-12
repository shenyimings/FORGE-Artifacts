// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/connectors/contracts/stuff/Reaper.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";


contract StrategyReaperSonneUsdt is Strategy {

    // --- structs

    struct StrategyParams {
        address usdcToken;
        address usdtToken;
        address soUsdt;
        address oracleUsdc;
        address oracleUsdt;
        address uniswapV3Router;
        uint24 poolUsdcUsdtFee;
    }

    // --- params

    IERC20 public usdcToken;
    IERC20 public usdtToken;
    IReaperVault public soUsdt;
    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleUsdt;
    ISwapRouter public uniswapV3Router;
    uint24 public poolUsdcUsdtFee;
    uint256 usdcDm;
    uint256 usdtDm;

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
        usdcToken = IERC20(params.usdcToken);
        usdtToken = IERC20(params.usdtToken);
        soUsdt = IReaperVault(params.soUsdt);
        oracleUsdc = IPriceFeed(params.oracleUsdc);
        oracleUsdt = IPriceFeed(params.oracleUsdt);
        uniswapV3Router = ISwapRouter(params.uniswapV3Router);
        poolUsdcUsdtFee = params.poolUsdcUsdtFee;
        usdcDm = 10 ** IERC20Metadata(params.usdcToken).decimals();
        usdtDm = 10 ** IERC20Metadata(params.usdtToken).decimals();

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        usdcToken.approve(address(uniswapV3Router), usdcBalance);
        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(usdcToken),
            address(usdtToken),
            poolUsdcUsdtFee,
            address(this),
            usdcBalance,
            OvnMath.subBasisPoints(_oracleUsdcToUsdt(usdcBalance), 20) // slippage 0.2%
        );

        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        usdtToken.approve(address(soUsdt), usdtBalance);
        soUsdt.deposit(usdtBalance);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 sharesBalance = soUsdt.balanceOf(address(this));
        if (sharesBalance == 0) {
            return 0;
        }

        // add 20 bp and 10 for unstake more than requested
        uint256 usdtAmount = OvnMath.addBasisPoints(_oracleUsdcToUsdt(_amount + 10), 20);
        uint256 shares = usdtAmount * soUsdt.totalSupply() / soUsdt.balance();

        if (shares >= sharesBalance) {
            soUsdt.withdrawAll();
        } else {
            soUsdt.withdraw(shares);
        }

        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        usdtToken.approve(address(uniswapV3Router), usdtBalance);
        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(usdtToken),
            address(usdcToken),
            poolUsdcUsdtFee,
            address(this),
            usdtBalance,
            OvnMath.subBasisPoints(_oracleUsdtToUsdc(usdtBalance), 20) // slippage 0.2%
        );

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 sharesBalance = soUsdt.balanceOf(address(this));
        if (sharesBalance == 0) {
            return 0;
        }

        soUsdt.withdrawAll();

        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        usdtToken.approve(address(uniswapV3Router), usdtBalance);
        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(usdtToken),
            address(usdcToken),
            poolUsdcUsdtFee,
            address(this),
            usdtBalance,
            OvnMath.subBasisPoints(_oracleUsdtToUsdc(usdtBalance), 20) // slippage 0.2%
        );

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return OvnMath.subBasisPoints(_totalValue(), 4); // swap slippage 0.04%
    }

    function _totalValue() internal view returns (uint256) {
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 usdtBalance = usdtToken.balanceOf(address(this));

        uint256 sharesBalance = soUsdt.balanceOf(address(this));
        usdcBalance += _oracleUsdtToUsdc(sharesBalance * soUsdt.balance() / soUsdt.totalSupply() + usdtBalance);

        return usdcBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {
        return 0;
    }

    function _oracleUsdtToUsdc(uint256 usdtAmount) internal view returns (uint256) {
        uint256 priceUsdt = uint256(oracleUsdt.latestAnswer());
        uint256 priceUsdc = uint256(oracleUsdc.latestAnswer());
        return ChainlinkLibrary.convertTokenToToken(usdtAmount, usdtDm, usdcDm, priceUsdt, priceUsdc);
    }

    function _oracleUsdcToUsdt(uint256 usdcAmount) internal view returns (uint256) {
        uint256 priceUsdt = uint256(oracleUsdt.latestAnswer());
        uint256 priceUsdc = uint256(oracleUsdc.latestAnswer());
        return ChainlinkLibrary.convertTokenToToken(usdcAmount, usdcDm, usdtDm, priceUsdc, priceUsdt);
    }
}
