// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./core/Strategy.sol";
import "./connectors/tarot/interfaces/IBorrowable.sol";
import "./connectors/tarot/interfaces/IRouter02.sol";

contract StrategyTarotSpiritUsdcFtm is Strategy {

    IERC20 public usdcToken;
    IBorrowable public bTarotSpiritToken;

    uint256 public bTarotSpiritTokenDenominator;

    IRouter02 public tarotRouter;


    // --- events

    event StrategyTarotSpiritUsdcFtmUpdatedTokens(address usdcToken, address bTarotSpiritToken, uint256 bTarotSpiritTokenDenominator);

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
        address _bTarotSpiritToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_bTarotSpiritToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        bTarotSpiritToken = IBorrowable(_bTarotSpiritToken);

        bTarotSpiritTokenDenominator = 10 ** bTarotSpiritToken.decimals();

        emit StrategyTarotSpiritUsdcFtmUpdatedTokens(_usdcToken, _bTarotSpiritToken, bTarotSpiritTokenDenominator);
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

        tarotRouter.mint(address(bTarotSpiritToken), _amount, address(this), block.timestamp + 600);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        _amount = _convertAmount(_amount, 5);

        uint256 bTarotSpiritAmount = _amount * bTarotSpiritTokenDenominator / bTarotSpiritToken.exchangeRateLast();

        bTarotSpiritToken.approve(address(tarotRouter), bTarotSpiritAmount);

        uint256 withdrawAmount = tarotRouter.redeem(address(bTarotSpiritToken), bTarotSpiritAmount, address(this), block.timestamp + 600, "");

        return withdrawAmount;
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 bTarotSpiritAmount = bTarotSpiritToken.balanceOf(address(this));

        bTarotSpiritToken.approve(address(tarotRouter), bTarotSpiritAmount);

        uint256 withdrawAmount = tarotRouter.redeem(address(bTarotSpiritToken), bTarotSpiritAmount, address(this), block.timestamp + 600, "");

        return withdrawAmount;
    }

    function netAssetValue() external view override returns (uint256) {
        return bTarotSpiritToken.balanceOf(address(this)) * bTarotSpiritToken.exchangeRateLast() / bTarotSpiritTokenDenominator;
    }

    function liquidationValue() external view override returns (uint256) {
        return bTarotSpiritToken.balanceOf(address(this)) * bTarotSpiritToken.exchangeRateLast() / bTarotSpiritTokenDenominator;
    }

    function _claimRewards(address _beneficiary) internal override returns (uint256) {
        return 0;
    }

}
