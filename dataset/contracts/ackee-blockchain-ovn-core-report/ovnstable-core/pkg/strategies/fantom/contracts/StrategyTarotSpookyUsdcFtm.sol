// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./core/Strategy.sol";
import "./connectors/tarot/interfaces/IBorrowable.sol";
import "./connectors/tarot/interfaces/IRouter02.sol";

contract StrategyTarotSpookyUsdcFtm is Strategy {

    IERC20 public usdcToken;
    IBorrowable public bTarotSpookyToken;

    uint256 public bTarotSpookyTokenDenominator;

    IRouter02 public tarotRouter;


    // --- events

    event StrategyTarotSpiritUsdcFtmUpdatedTokens(address usdcToken, address bTarotSpookyToken, uint256 bTarotSpookyTokenDenominator);

    event StrategyTarotSpiritUsdcFtmUpdatedParams(address tarotRouter);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _bTarotSpookyToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_bTarotSpookyToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        bTarotSpookyToken = IBorrowable(_bTarotSpookyToken);

        bTarotSpookyTokenDenominator = 10 ** bTarotSpookyToken.decimals();

        emit StrategyTarotSpiritUsdcFtmUpdatedTokens(_usdcToken, _bTarotSpookyToken, bTarotSpookyTokenDenominator);
    }

    function setParams(
        address _tarotRouter
    ) external onlyAdmin {

        require(_tarotRouter != address(0), "Zero address not allowed");

        tarotRouter = IRouter02(_tarotRouter);

        emit StrategyTarotSpiritUsdcFtmUpdatedParams(_tarotRouter);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        usdcToken.approve(address(tarotRouter), _amount);

        tarotRouter.mint(address(bTarotSpookyToken), _amount, address(this), block.timestamp + 600);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        _amount = _convertAmount(_amount, 5);

        uint256 bTarotSpookyAmount = _amount * bTarotSpookyTokenDenominator / bTarotSpookyToken.exchangeRateLast();

        bTarotSpookyToken.approve(address(tarotRouter), bTarotSpookyAmount);

        uint256 withdrawAmount = tarotRouter.redeem(address(bTarotSpookyToken), bTarotSpookyAmount, address(this), block.timestamp + 600, "");

        return withdrawAmount;
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 bTarotSpookyAmount = bTarotSpookyToken.balanceOf(address(this));

        bTarotSpookyToken.approve(address(tarotRouter), bTarotSpookyAmount);

        uint256 withdrawAmount = tarotRouter.redeem(address(bTarotSpookyToken), bTarotSpookyAmount, address(this), block.timestamp + 600, "");

        return withdrawAmount;
    }

    function netAssetValue() external view override returns (uint256) {
        return bTarotSpookyToken.balanceOf(address(this)) * bTarotSpookyToken.exchangeRateLast() / bTarotSpookyTokenDenominator;
    }

    function liquidationValue() external view override returns (uint256) {
        return bTarotSpookyToken.balanceOf(address(this)) * bTarotSpookyToken.exchangeRateLast() / bTarotSpookyTokenDenominator;
    }

    function _claimRewards(address _beneficiary) internal override returns (uint256) {
        return 0;
    }

}
