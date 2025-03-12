// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/connectors/contracts/stuff/Reaper.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";


contract StrategyReaperSonneDai is Strategy {

    // --- structs

    struct StrategyParams {
        address usdcToken;
        address daiToken;
        address soDai;
        address oracleUsdc;
        address oracleDai;
        address uniswapV3Router;
        uint24 poolUsdcDaiFee;
    }

    // --- params

    IERC20 public usdcToken;
    IERC20 public daiToken;
    IReaperVault public soDai;
    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleDai;
    ISwapRouter public uniswapV3Router;
    uint24 public poolUsdcDaiFee;
    uint256 usdcDm;
    uint256 daiDm;

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
        daiToken = IERC20(params.daiToken);
        soDai = IReaperVault(params.soDai);
        oracleUsdc = IPriceFeed(params.oracleUsdc);
        oracleDai = IPriceFeed(params.oracleDai);
        uniswapV3Router = ISwapRouter(params.uniswapV3Router);
        poolUsdcDaiFee = params.poolUsdcDaiFee;
        usdcDm = 10 ** IERC20Metadata(params.usdcToken).decimals();
        daiDm = 10 ** IERC20Metadata(params.daiToken).decimals();

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
            address(daiToken),
            poolUsdcDaiFee,
            address(this),
            usdcBalance,
            OvnMath.subBasisPoints(_oracleUsdcToDai(usdcBalance), 20) // slippage 0.2%
        );

        uint256 daiBalance = daiToken.balanceOf(address(this));
        daiToken.approve(address(soDai), daiBalance);
        soDai.deposit(daiBalance);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 sharesBalance = soDai.balanceOf(address(this));
        if (sharesBalance == 0) {
            return 0;
        }

        // add 20 bp and 10 for unstake more than requested
        uint256 daiAmount = OvnMath.addBasisPoints(_oracleUsdcToDai(_amount + 10), 20);
        uint256 shares = daiAmount * soDai.totalSupply() / soDai.balance();

        if (shares >= sharesBalance) {
            soDai.withdrawAll();
        } else {
            soDai.withdraw(shares);
        }

        uint256 daiBalance = daiToken.balanceOf(address(this));
        daiToken.approve(address(uniswapV3Router), daiBalance);
        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(daiToken),
            address(usdcToken),
            poolUsdcDaiFee,
            address(this),
            daiBalance,
            OvnMath.subBasisPoints(_oracleDaiToUsdc(daiBalance), 20) // slippage 0.2%
        );

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 sharesBalance = soDai.balanceOf(address(this));
        if (sharesBalance == 0) {
            return 0;
        }

        soDai.withdrawAll();

        uint256 daiBalance = daiToken.balanceOf(address(this));
        daiToken.approve(address(uniswapV3Router), daiBalance);
        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(daiToken),
            address(usdcToken),
            poolUsdcDaiFee,
            address(this),
            daiBalance,
            OvnMath.subBasisPoints(_oracleDaiToUsdc(daiBalance), 20) // slippage 0.2%
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
        uint256 daiBalance = daiToken.balanceOf(address(this));

        uint256 sharesBalance = soDai.balanceOf(address(this));
        usdcBalance += _oracleDaiToUsdc(sharesBalance * soDai.balance() / soDai.totalSupply() + daiBalance);

        return usdcBalance;
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
