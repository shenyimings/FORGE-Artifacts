// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Gains.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";

contract StrategyGainsDai is Strategy {

    IERC20 public usdc;
    IERC20 public dai;
    GainsVault public gainsVault;

    ISwapRouter public uniswapV3Router;
    uint24 public poolUsdcDaiFee;

    IPriceFeed public oracleDai;
    IPriceFeed public oracleUsdc;

    uint256 daiDm;
    uint256 usdcDm;

    // --- events
    event StrategyUpdatedParams();


    // --- structs

    struct StrategyParams {
        address usdc;
        address dai;
        address gainsVault;
        address uniswapV3Router;
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
        usdc = IERC20(params.usdc);
        dai = IERC20(params.dai);
        gainsVault = GainsVault(params.gainsVault);
        uniswapV3Router = ISwapRouter(params.uniswapV3Router);
        poolUsdcDaiFee = params.poolUsdcDaiFee;

        oracleDai = IPriceFeed(params.oracleDai);
        oracleUsdc = IPriceFeed(params.oracleUsdc);

        usdcDm = 10 ** IERC20Metadata(params.usdc).decimals();
        daiDm = 10 ** IERC20Metadata(params.dai).decimals();

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {
        require(_asset == address(usdc), "Some token not compatible");

        uint256 usdcAmount = usdc.balanceOf(address(this));
        usdc.approve(address(uniswapV3Router), usdcAmount);

        uint256 daiAmount = UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(usdc),
            address(dai),
            poolUsdcDaiFee,
            address(this),
            usdcAmount,
            OvnMath.subBasisPoints(_oracleUsdcToDai(usdcAmount), 10) // slippage 0.1%
        );

        dai.approve(address(gainsVault), daiAmount);
        gainsVault.depositDai(daiAmount);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdc), "Some token not compatible");

        // Uniswap V3 swap fee (100 = 0.01%) => 1
        uint256 swapFee = poolUsdcDaiFee / 100;
        // UniswapV3 slippage - 10 bb = 0.1%
        uint256 slippage = 10;

        // 11 bb - 0.11%
        uint256 basicPoints = swapFee + slippage;

        uint256 daiAmount = _oracleUsdcToDai(OvnMath.addBasisPoints(_amount, basicPoints));
        gainsVault.withdrawDai(daiAmount);

        dai.approve(address(uniswapV3Router), daiAmount);

        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(dai),
            address(usdc),
            poolUsdcDaiFee,
            address(this),
            daiAmount,
            OvnMath.subBasisPoints(_oracleDaiToUsdc(daiAmount), basicPoints)
        );

        return usdc.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdc), "Some token not compatible");

        uint256 daiAmount = gainsVault.users(address(this)).daiDeposited;
        if(daiAmount == 0){
            return 0;
        }

        gainsVault.withdrawDai(daiAmount);

        dai.approve(address(uniswapV3Router), daiAmount);

        UniswapV3Library.singleSwap(
            uniswapV3Router,
            address(dai),
            address(usdc),
            poolUsdcDaiFee,
            address(this),
            daiAmount,
            OvnMath.subBasisPoints(_oracleDaiToUsdc(daiAmount), 10) // 0.1%
        );

        return usdc.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {

        uint256 daiAmount = gainsVault.users(address(this)).daiDeposited;
        return _oracleDaiToUsdc(daiAmount);
    }

    function liquidationValue() external view override returns (uint256) {
        uint256 daiAmount = gainsVault.users(address(this)).daiDeposited;
        return OvnMath.subBasisPoints(_oracleDaiToUsdc(daiAmount), 4);
    }

    function _claimRewards(address _beneficiary) internal override returns (uint256) {

        if (gainsVault.users(address(this)).daiDeposited == 0) {
            return 0;
        }

        gainsVault.harvest();

        uint256 daiAmount = dai.balanceOf(address(this));

        uint256 totalUsdc;
        if (daiAmount > 0) {
            uint256 amountUsdc = UniswapV3Library.singleSwap(
                uniswapV3Router,
                address(dai),
                address(usdc),
                poolUsdcDaiFee,
                address(this),
                daiAmount,
                0
            );

            if (amountUsdc > 0) {
                usdc.transfer(_beneficiary, amountUsdc);
                totalUsdc += amountUsdc;
            }
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

    // Gains vault check payable function and can send MATIC
    receive() external payable {
    }
}
