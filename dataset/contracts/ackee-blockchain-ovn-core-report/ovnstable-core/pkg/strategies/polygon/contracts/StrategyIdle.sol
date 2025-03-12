// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Idle.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV2.sol";

contract StrategyIdle is Strategy, UniswapV2Exchange {

    IERC20 public usdcToken;
    IIdleToken public idleToken;
    IERC20 public wmaticToken;

    uint256 public usdcTokenDenominator;
    uint256 public idleTokenDenominator;
    uint256 public wmaticTokenDenominator;


    // --- events

    event StrategyIdleUpdatedTokens(address usdcToken, address idleToken, address wmaticToken,
        uint256 usdcTokenDenominator, uint256 idleTokenDenominator, uint256 wmaticTokenDenominator);

    event StrategyIdleUpdatedParams(address uniswapRouter);

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _idleToken,
        address _wmaticToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_idleToken != address(0), "Zero address not allowed");
        require(_wmaticToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        idleToken = IIdleToken(_idleToken);
        wmaticToken = IERC20(_wmaticToken);

        usdcTokenDenominator = 10 ** IERC20Metadata(_usdcToken).decimals();
        idleTokenDenominator = 10 ** IERC20Metadata(_idleToken).decimals();
        wmaticTokenDenominator = 10 ** IERC20Metadata(_wmaticToken).decimals();

        emit StrategyIdleUpdatedTokens(_usdcToken, _idleToken, _wmaticToken,
            usdcTokenDenominator, idleTokenDenominator, wmaticTokenDenominator);
    }

    function setParams(
        address _uniswapRouter
    ) external onlyAdmin {

        require(_uniswapRouter != address(0), "Zero address not allowed");

        _setUniswapRouter(_uniswapRouter);

        emit StrategyIdleUpdatedParams(_uniswapRouter);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        usdcToken.approve(address(idleToken), _amount);
        uint256 mintedTokens = idleToken.mintIdleToken(_amount, true, address(this));
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        // fee 1% - misinformation
        uint256 fixedAmount = _amount * 101 / 100;

        // 18 = 18 + 6 - 6
        uint256 tokenAmount = idleTokenDenominator * fixedAmount / idleToken.tokenPrice();

        uint256 redeemedTokens = idleToken.redeemIdleToken(tokenAmount);

        return redeemedTokens;
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 _amount = idleToken.balanceOf(address(this));

        uint256 redeemedTokens = idleToken.redeemIdleToken(_amount);

        return redeemedTokens;
    }

    function netAssetValue() external override view returns (uint256) {
        uint256 balance = idleToken.balanceOf(address(this));
        if (balance == 0) {
            return 0;
        }
        uint256 price = idleToken.tokenPrice();
        // 18 + 6 - 18 = 6
        return balance * price / idleTokenDenominator;
    }

    function liquidationValue() external override view returns (uint256) {
        uint256 balance = idleToken.balanceOf(address(this));
        if (balance == 0) {
            return 0;
        }
        uint256 price = idleToken.tokenPrice();
        // 18 + 6 - 18 = 6
        return balance * price / idleTokenDenominator;
    }

    function _claimRewards(address _to) internal override returns (uint256) {
        uint256 totalUsdc;

        uint256 wmaticBalance = wmaticToken.balanceOf(address(this));
        if (wmaticBalance != 0) {
            uint256 wmaticUsdc = _swapExactTokensForTokens(
                address(wmaticToken),
                address(usdcToken),
                wmaticBalance,
                address(this)
            );
            totalUsdc += wmaticUsdc;
        }

        usdcToken.transfer(_to, usdcToken.balanceOf(address(this)));
        return totalUsdc;
    }
}
