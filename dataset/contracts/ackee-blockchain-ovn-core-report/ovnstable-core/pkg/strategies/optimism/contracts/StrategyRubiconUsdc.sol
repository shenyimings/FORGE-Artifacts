// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";

import "@overnight-contracts/connectors/contracts/stuff/Rubicon.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";

contract StrategyRubiconUsdc is Strategy {

    IERC20 public usdcToken;
    IERC20 public opToken;
    BathToken public rubiconUsdc;

    ISwapRouter public uniswapV3Router;
    uint24 public poolFee;


    // --- events
    event StrategyUpdatedParams();


    // --- structs

    struct StrategyParams {
        address usdcToken;
        address opToken;
        address rubiconUsdc;
        address uniswapV3Router;
        uint24 poolFee;
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
        opToken = IERC20(params.opToken);
        rubiconUsdc = BathToken(params.rubiconUsdc);
        uniswapV3Router = ISwapRouter(params.uniswapV3Router);
        poolFee = params.poolFee;

        emit StrategyUpdatedParams();
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {
        require(_asset == address(usdcToken), "Some token not compatible");

        usdcToken.approve(address(rubiconUsdc), _amount);
        rubiconUsdc.deposit(_amount);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        // rubicon withdraw fee - 0.03% in 3 bp, but we used out default fee = 0.04%
        uint256 _shares = rubiconUsdc.previewWithdraw(OvnMath.addBasisPoints(_amount, 4));
        rubiconUsdc.withdraw(_shares);

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 shares = rubiconUsdc.balanceOf(address(this));
        if(shares == 0){
            return 0;
        }

        return rubiconUsdc.withdraw(shares);
    }

    function netAssetValue() external view override returns (uint256) {
        uint256 usdcBalance = usdcToken.balanceOf(address(this));

        uint256 shares = rubiconUsdc.balanceOf(address(this));
        usdcBalance += rubiconUsdc.convertToAssets(shares);

        return usdcBalance;
    }

    function liquidationValue() external view override returns (uint256) {
        uint256 usdcBalance = usdcToken.balanceOf(address(this));

        uint256 shares = rubiconUsdc.balanceOf(address(this));
        usdcBalance += rubiconUsdc.previewRedeem(shares);

        return usdcBalance;
    }

    function _claimRewards(address _beneficiary) internal override returns (uint256) {

        uint256 shares = rubiconUsdc.balanceOf(address(this));
        if(shares == 0){
            return 0;
        }

        // claim rewards - rewards get when withdraw
        rubiconUsdc.withdraw(0);

        uint256 totalUsdc;

        uint256 opBalance = opToken.balanceOf(address(this));
        if (opBalance > 0) {

            uint256 opUsdc = UniswapV3Library.singleSwap(
                uniswapV3Router,
                address(opToken),
                address(usdcToken),
                poolFee,
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

}
