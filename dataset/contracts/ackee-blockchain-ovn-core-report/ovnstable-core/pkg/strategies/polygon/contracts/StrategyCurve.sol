// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Curve.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV2.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";

contract StrategyCurve is Strategy, UniswapV2Exchange {

    IERC20 public usdcToken;
    IERC20 public a3CrvToken;
    IERC20 public a3CrvGaugeToken;
    IERC20 public crvToken;
    IERC20 public wmaticToken;

    uint256 public usdcTokenDenominator;
    uint256 public a3CrvTokenDenominator;
    uint256 public crvTokenDenominator;
    uint256 public wmaticTokenDenominator;

    IStableSwapPool public crvPool;
    IRewardsOnlyGauge public rewardGauge;


    // --- events

    event StrategyCurveUpdatedTokens(
        address usdcToken,
        address a3CrvToken,
        address a3CrvGaugeToken,
        address crvToken,
        address wmaticToken,
        uint256 usdcTokenDenominator,
        uint256 a3CrvTokenDenominator,
        uint256 crvTokenDenominator,
        uint256 wmaticTokenDenominator
    );

    event StrategyCurveUpdatedParams(address crvPool, address rewardGauge, address uniswapRouter);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }



    // --- Setters

    function setTokens(
        address _usdcToken,
        address _a3CrvToken,
        address _a3CrvGaugeToken,
        address _crvToken,
        address _wmaticToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_a3CrvToken != address(0), "Zero address not allowed");
        require(_a3CrvGaugeToken != address(0), "Zero address not allowed");
        require(_crvToken != address(0), "Zero address not allowed");
        require(_wmaticToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        a3CrvToken = IERC20(_a3CrvToken);
        a3CrvGaugeToken = IERC20(_a3CrvGaugeToken);
        crvToken = IERC20(_crvToken);
        wmaticToken = IERC20(_wmaticToken);

        usdcTokenDenominator = 10 ** IERC20Metadata(_usdcToken).decimals();
        a3CrvTokenDenominator = 10 ** IERC20Metadata(_a3CrvToken).decimals();
        crvTokenDenominator = 10 ** IERC20Metadata(_crvToken).decimals();
        wmaticTokenDenominator = 10 ** IERC20Metadata(_wmaticToken).decimals();

        emit StrategyCurveUpdatedTokens(
            _usdcToken,
            _a3CrvToken,
            _a3CrvGaugeToken,
            _crvToken,
            _wmaticToken,
            usdcTokenDenominator,
            a3CrvTokenDenominator,
            crvTokenDenominator,
            wmaticTokenDenominator
        );
    }

    function setParams(
        address _crvPool,
        address _rewardGauge,
        address _uniswapRouter
    ) external onlyAdmin {

        require(_crvPool != address(0), "Zero address not allowed");
        require(_rewardGauge != address(0), "Zero address not allowed");
        require(_uniswapRouter != address(0), "Zero address not allowed");

        crvPool = IStableSwapPool(_crvPool);
        rewardGauge = IRewardsOnlyGauge(_rewardGauge);
        _setUniswapRouter(_uniswapRouter);

        emit StrategyCurveUpdatedParams(_crvPool, _rewardGauge, _uniswapRouter);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {
        require(_asset == address(usdcToken), "Some token not compatible");

        address current = address(this);

        _stakeCurve(address(usdcToken), _amount, current);

        uint256 a3CrvBalance = a3CrvToken.balanceOf(current);
        a3CrvToken.approve(address(rewardGauge), a3CrvBalance);
        rewardGauge.deposit(a3CrvBalance, current, false);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        address current = address(this);
        // gauge doesn't need approve on withdraw, but we should have amount token
        // on Strategy

        // 6 = 18 + 6 - 18
        uint256 price = crvPool.get_virtual_price() * usdcTokenDenominator / a3CrvTokenDenominator;

        // Add +1% - slippage curve
        uint256 amount = _amount + (_amount * 1 / 100);

        // 18 = 18 + 6 - 6
        uint256 tokenAmountToWithdrawFromGauge = a3CrvTokenDenominator * amount / price;

        rewardGauge.withdraw(tokenAmountToWithdrawFromGauge, false);

        uint256 withdrewAmount = _unstakeCurve();

        return withdrewAmount;
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 _amount = a3CrvGaugeToken.balanceOf(address(this));

        address current = address(this);
        // gauge doesn't need approve on withdraw, but we should have amount token
        // on Strategy

        rewardGauge.withdraw(_amount, false);

        uint256 withdrewAmount = _unstakeCurve();

        return withdrewAmount;
    }

    function netAssetValue() external view override returns (uint256){
        uint256 balance = a3CrvGaugeToken.balanceOf(address(this));
        if (balance == 0) {
            return 0;
        }
        // 6 = 18 + 6 - 18
        uint256 price = crvPool.get_virtual_price() * usdcTokenDenominator / a3CrvTokenDenominator;
        // 18 + 6 - 18 = 6
        return balance * price / a3CrvTokenDenominator;
    }

    function liquidationValue() external view override returns (uint256){
        uint256 balance = a3CrvGaugeToken.balanceOf(address(this));
        if (balance == 0) {
            return 0;
        }

        // get amount usdc that will be unstaked, gauge is 1:1 to am3Crv
        int128 usdcIndex = 1;
        // position of usdc token
        uint256 withdrawUsdcAmount = crvPool.calc_withdraw_one_coin(balance, usdcIndex);

        return withdrawUsdcAmount;
    }


    function _stakeCurve(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal {
        uint256[3] memory amounts;
        for (uint256 i = 0; i < 3; i++) {
            address coin = crvPool.underlying_coins(i);
            if (coin == _asset) {
                IERC20(_asset).approve(address(crvPool), _amount);
                // номер позиции в массиве (amounts) определяет какой актив (_asset) и в каком количестве (_amount)
                // на стороне керва будет застейкано
                amounts[i] = _amount;
                uint256 lpTokAmount = crvPool.calc_token_amount(amounts, true);
                //TODO: процентажи кудато вынести, slippage
                uint256 retAmount = crvPool.add_liquidity(amounts, (lpTokAmount * 99) / 100, true);
                if (_beneficiary != address(this)) {
                    IERC20(crvPool.lp_token()).transfer(_beneficiary, retAmount);
                }

                return;
            }
        }
        revert("can't find active for staking in curve");
    }


    function _unstakeCurve() internal returns (uint256) {

        // index got from curve.coins(i) for USDC
        uint256 index = 1;
        require(crvPool.underlying_coins(index) == address(usdcToken), "Invalid index for unstaking curve");

        uint256 lpTokenAmount = a3CrvToken.balanceOf(address(this));

        a3CrvToken.approve(address(crvPool), lpTokenAmount);

        //TODO: use withdrawAmount?
        uint256 retAmount = crvPool.remove_liquidity_one_coin(lpTokenAmount, int128(uint128(index)), 0, true);
        return retAmount;
    }

    function _claimRewards(address _to) internal override returns (uint256){
        rewardGauge.claim_rewards(address(this));

        uint256 totalUsdc;

        uint256 crvBalance = crvToken.balanceOf(address(this));
        if (crvBalance != 0) {
            uint256 crvUsdc = _swapExactTokensForTokens(
                address(crvToken),
                address(usdcToken),
                crvBalance,
                address(this)
            );
            totalUsdc += crvUsdc;
        }

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
