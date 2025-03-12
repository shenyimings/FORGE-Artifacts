// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";

import "@overnight-contracts/connectors/contracts/stuff/Rubicon.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";

import "hardhat/console.sol";

contract StrategyRubiconDai is Strategy {

    IERC20 public usdcToken;
    IERC20 public daiToken;
    IERC20 public opToken;
    BathToken public rubiconDai;

    ISwapRouter public uniswapV3Router;
    uint24 public poolUsdcOpFee;
    uint24 public poolUsdcDaiFee;

    IPriceFeed public oracleDai;
    IPriceFeed public oracleUsdc;

    uint256 daiDm;
    uint256 usdcDm;



    // --- events
    event StrategyUpdatedParams();


    // --- structs

    struct StrategyParams {
        address usdcToken;
        address daiToken;
        address opToken;
        address rubiconDai;
        address uniswapV3Router;
        uint24 poolUsdcOpFee;
        uint24 poolUsdcDaiFee;
        address oracleDai;
        address oracleUsdc;
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
        daiToken = IERC20(params.daiToken);
        opToken = IERC20(params.opToken);
        rubiconDai = BathToken(params.rubiconDai);
        uniswapV3Router = ISwapRouter(params.uniswapV3Router);
        poolUsdcOpFee = params.poolUsdcOpFee;
        poolUsdcDaiFee = params.poolUsdcDaiFee;
        oracleDai = IPriceFeed(params.oracleDai);
        oracleUsdc = IPriceFeed(params.oracleUsdc);
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

        usdcToken.approve(address(uniswapV3Router), _amount);

        uint256 daiAmount = UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(usdcToken),
            address(daiToken),
            poolUsdcDaiFee,
            address(this),
            _amount,
            OvnMath.subBasisPoints(_oracleUsdcToDai(_amount), 20) // slippage 0.2%
        );

        daiToken.approve(address(rubiconDai), daiAmount);
        rubiconDai.deposit(daiAmount);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");


        // Uniswap V3 swap fee (100 = 0.01%) => 1
        uint256 swapFee = poolUsdcDaiFee / 100;
        // rubicon withdraw fee - 0.03% in 3 bp
        uint256 withdrawFee = 3;
        uint256 basicPoints = swapFee + withdrawFee;

        uint256 daiAmount = _oracleUsdcToDai(_amount);

        uint256 _shares = rubiconDai.previewWithdraw(OvnMath.addBasisPoints(daiAmount, basicPoints));
        rubiconDai.withdraw(_shares);

        daiAmount = daiToken.balanceOf(address(this));

        daiToken.approve(address(uniswapV3Router), daiAmount);

        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(daiToken),
            address(usdcToken),
            poolUsdcDaiFee,
            address(this),
            daiAmount,
            OvnMath.subBasisPoints(_oracleDaiToUsdc(daiAmount), 20) // slippage 0.2%
        );

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 shares = rubiconDai.balanceOf(address(this));
        if(shares == 0){
            return 0;
        }

        rubiconDai.withdraw(shares);

        uint256 daiAmount = daiToken.balanceOf(address(this));

        daiToken.approve(address(uniswapV3Router), daiAmount);

        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(daiToken),
            address(usdcToken),
            poolUsdcDaiFee,
            address(this),
            daiAmount,
            OvnMath.subBasisPoints(_oracleDaiToUsdc(daiAmount), 20) // slippage 0.2%
        );

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 daiBalance = daiToken.balanceOf(address(this));

        uint256 shares = rubiconDai.balanceOf(address(this));
        uint256 daiAmount = rubiconDai.convertToAssets(shares);
        usdcBalance += _oracleDaiToUsdc(daiAmount + daiBalance);

        return usdcBalance;
    }

    function liquidationValue() external view override returns (uint256) {
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 daiBalance = daiToken.balanceOf(address(this));

        uint256 shares = rubiconDai.balanceOf(address(this));
        uint256 daiAmount = rubiconDai.previewRedeem(shares);
        usdcBalance += OvnMath.subBasisPoints(_oracleDaiToUsdc(daiAmount + daiBalance), 4); // swap slippage 0.04%

        return usdcBalance;
    }

    function _claimRewards(address _beneficiary) internal override returns (uint256) {

        uint256 shares = rubiconDai.balanceOf(address(this));
        if(shares == 0){
            return 0;
        }

        // claim rewards - rewards get when withdraw
        rubiconDai.withdraw(0);

        uint256 totalUsdc;

        uint256 opBalance = opToken.balanceOf(address(this));
        if (opBalance > 0) {

            uint256 opUsdc = UniswapV3Library.singleSwap(
                uniswapV3Router,
                address(opToken),
                address(usdcToken),
                poolUsdcOpFee,
                address(this),
                opBalance,
                0
            );
            totalUsdc += opUsdc;
        }

        if (totalUsdc > 0) {
            usdcToken.transfer(_beneficiary, totalUsdc);
        }

        return totalUsdc;
    }

    function _oracleDaiToUsdc(uint256 _daiAmount) internal view returns (uint256){

        uint256 priceDai = uint256(oracleDai.latestAnswer());
        uint256 priceUsdc = uint256(oracleUsdc.latestAnswer());

        uint256 amount = ChainlinkLibrary.convertTokenToToken(_daiAmount, daiDm, usdcDm, priceDai, priceUsdc);

        return amount;
    }

    function _oracleUsdcToDai(uint256 _usdcAmount) internal view returns (uint256){

        uint256 priceDai = uint256(oracleDai.latestAnswer());
        uint256 priceUsdc = uint256(oracleUsdc.latestAnswer());

        return ChainlinkLibrary.convertTokenToToken(_usdcAmount, usdcDm, daiDm, priceUsdc, priceDai);
    }
}
