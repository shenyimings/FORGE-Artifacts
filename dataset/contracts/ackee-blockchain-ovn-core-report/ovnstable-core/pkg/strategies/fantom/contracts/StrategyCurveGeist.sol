// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/Strings.sol";

import "./core/Strategy.sol";
import "./exchanges/UniswapV2Exchange.sol";
import "./connectors/curve/interfaces/IStableSwapPool.sol";
import "./connectors/curve/interfaces/IRewardsOnlyGauge.sol";

contract StrategyCurveGeist is Strategy, UniswapV2Exchange {

    IERC20 public usdcToken;
    IERC20 public crvPoolToken;
    IERC20 public crvGaugeToken;
    IERC20 public geistToken;
    IERC20 public crvToken;
    IERC20 public wFtmToken;

    uint256 public usdcTokenDenominator;
    uint256 public crvPoolTokenDenominator;
    uint256 public geistTokenDenominator;
    uint256 public crvTokenDenominator;
    uint256 public wFtmTokenDenominator;

    IStableSwapPool public crvPool;
    IRewardsOnlyGauge public rewardGauge;


    // --- events

    event StrategyCurveGeistUpdatedTokens(
        address usdcToken,
        address crvPoolToken,
        address crvGaugeToken,
        address geistToken,
        address crvToken,
        address wFtmToken,
        uint256 usdcTokenDenominator,
        uint256 crvPoolTokenDenominator,
        uint256 geistTokenDenominator,
        uint256 crvTokenDenominator,
        uint256 wFtmTokenDenominator
    );

    event StrategyCurveGeistUpdatedParams(
        address crvPool,
        address rewardGauge,
        address uniswapRouter
    );


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }



    // --- Setters

    function setTokens(
        address _usdcToken,
        address _crvPoolToken,
        address _crvGaugeToken,
        address _geistToken,
        address _crvToken,
        address _wFtmToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_crvPoolToken != address(0), "Zero address not allowed");
        require(_crvGaugeToken != address(0), "Zero address not allowed");
        require(_geistToken != address(0), "Zero address not allowed");
        require(_crvToken != address(0), "Zero address not allowed");
        require(_wFtmToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        crvPoolToken = IERC20(_crvPoolToken);
        crvGaugeToken = IERC20(_crvGaugeToken);
        geistToken = IERC20(_geistToken);
        crvToken = IERC20(_crvToken);
        wFtmToken = IERC20(_wFtmToken);

        usdcTokenDenominator = 10 ** IERC20Metadata(_usdcToken).decimals();
        crvPoolTokenDenominator = 10 ** IERC20Metadata(_crvPoolToken).decimals();
        geistTokenDenominator = 10 ** IERC20Metadata(_geistToken).decimals();
        crvTokenDenominator = 10 ** IERC20Metadata(_crvToken).decimals();
        wFtmTokenDenominator = 10 ** IERC20Metadata(_wFtmToken).decimals();

        emit StrategyCurveGeistUpdatedTokens(
            _usdcToken,
            _crvPoolToken,
            _crvGaugeToken,
            _geistToken,
            _crvToken,
            _wFtmToken,
            usdcTokenDenominator,
            crvPoolTokenDenominator,
            geistTokenDenominator,
            crvTokenDenominator,
            wFtmTokenDenominator
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

        emit StrategyCurveGeistUpdatedParams(
            _crvPool,
            _rewardGauge,
            _uniswapRouter
        );
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {
        require(_asset == address(usdcToken), "Some token not compatible");

        require(crvPool.underlying_coins(1) == address(usdcToken), "Invalid index for staking curve");

        uint256[3] memory amounts;
        amounts[0] = 0;
        amounts[1] = _amount;
        amounts[2] = 0;
        usdcToken.approve(address(crvPool), _amount);
        uint256 lpTokAmount = crvPool.calc_token_amount(amounts, true);
        //TODO: процентажи кудато вынести, slippage
        uint256 retAmount = crvPool.add_liquidity(amounts, lpTokAmount * 99 / 100, true);

        uint256 crvPoolBalance = crvPoolToken.balanceOf(address(this));
        crvPoolToken.approve(address(rewardGauge), crvPoolBalance);
        rewardGauge.deposit(crvPoolBalance, address(this), false);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        address current = address(this);

        // 6 = 18 + 6 - 18
        uint256 price = crvPool.get_virtual_price() * usdcTokenDenominator / crvPoolTokenDenominator;

        // Add +1% - slippage curve
        uint256 amount = _amount * 101 / 100;

        // 18 = 18 + 6 - 6
        uint256 tokenAmountToWithdrawFromGauge = crvPoolTokenDenominator * amount / price;

        rewardGauge.withdraw(tokenAmountToWithdrawFromGauge, false);

        uint256 withdrewAmount = _unstakeCurve();

        return withdrewAmount;
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 _amount = crvGaugeToken.balanceOf(address(this));

        address current = address(this);
        // gauge doesn't need approve on withdraw, but we should have amount token
        // on Strategy

        rewardGauge.withdraw(_amount, false);

        uint256 withdrewAmount = _unstakeCurve();

        return withdrewAmount;
    }

    function netAssetValue() external view override returns (uint256) {
        uint256 balance = crvGaugeToken.balanceOf(address(this));
        if (balance == 0) {
            return 0;
        }

        // 6 = 18 + 6 - 18
        uint256 price = crvPool.get_virtual_price() * usdcTokenDenominator / crvPoolTokenDenominator;
        // 18 + 6 - 18 = 6
        return balance * price / crvPoolTokenDenominator;
    }

    function liquidationValue() external view override returns (uint256) {

        require(crvPool.underlying_coins(1) == address(usdcToken), "Invalid index for liquidationValue curve");

        uint256 balance = crvGaugeToken.balanceOf(address(this));
        if (balance == 0) {
            return 0;
        }

        uint256 withdrawUsdcAmount = crvPool.calc_withdraw_one_coin(balance, 1);
        return withdrawUsdcAmount;
    }

    function _unstakeCurve() internal returns (uint256) {

        require(crvPool.underlying_coins(1) == address(usdcToken), "Invalid index for unstaking curve");

        uint256 lpTokenAmount = crvPoolToken.balanceOf(address(this));

        crvPoolToken.approve(address(crvPool), lpTokenAmount);

        //TODO: use withdrawAmount?
        uint256 retAmount = crvPool.remove_liquidity_one_coin(lpTokenAmount, 1, 0, true);
        return retAmount;
    }

    function _claimRewards(address _to) internal override returns (uint256) {
        rewardGauge.claim_rewards(address(this));

        uint256 totalUsdc;

        uint256 geistBalance = geistToken.balanceOf(address(this));
        if (geistBalance != 0) {
            uint256 geistUsdc = _swapExactTokensForTokens(
                address(geistToken),
                address(usdcToken),
                geistBalance,
                address(this)
            );
            totalUsdc += geistUsdc;
        }

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

        uint256 wFtmBalance = wFtmToken.balanceOf(address(this));
        if (wFtmBalance != 0) {
            uint256 wFtmUsdc = _swapExactTokensForTokens(
                address(wFtmToken),
                address(usdcToken),
                wFtmBalance,
                address(this)
            );
            totalUsdc += wFtmUsdc;
        }

        usdcToken.transfer(_to, usdcToken.balanceOf(address(this)));
        return totalUsdc;
    }

}
