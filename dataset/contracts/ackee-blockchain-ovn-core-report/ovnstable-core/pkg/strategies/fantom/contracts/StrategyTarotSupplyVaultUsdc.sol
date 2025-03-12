// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./core/Strategy.sol";
import "./connectors/tarot/interfaces/ISupplyVault.sol";
import "./connectors/tarot/interfaces/IBorrowable.sol";
import "./connectors/tarot/interfaces/ISupplyVaultRouter01.sol";

contract StrategyTarotSupplyVaultUsdc is Strategy {

    IERC20 public usdcToken;
    ISupplyVault public tUsdcToken;
    IBorrowable public bTarotSpiritToken;

    uint256 public bTarotSpiritTokenDenominator;

    ISupplyVaultRouter01 public tarotSupplyVaultRouter;


    // --- events

    event StrategyTarotSupplyVaultUsdcUpdatedTokens(address usdcToken, address tUsdcToken, address bTarotSpiritToken,
        uint256 bTarotSpiritTokenDenominator);

    event StrategyTarotSupplyVaultUsdcUpdatedParams(address tarotSupplyVaultRouter);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _tUsdcToken,
        address _bTarotSpiritToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_tUsdcToken != address(0), "Zero address not allowed");
        require(_bTarotSpiritToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        tUsdcToken = ISupplyVault(_tUsdcToken);
        bTarotSpiritToken = IBorrowable(_bTarotSpiritToken);

        bTarotSpiritTokenDenominator = 10 ** bTarotSpiritToken.decimals();

        emit StrategyTarotSupplyVaultUsdcUpdatedTokens(_usdcToken, _tUsdcToken, _bTarotSpiritToken, bTarotSpiritTokenDenominator);
    }

    function setParams(
        address _tarotSupplyVaultRouter
    ) external onlyAdmin {

        require(_tarotSupplyVaultRouter != address(0), "Zero address not allowed");

        tarotSupplyVaultRouter = ISupplyVaultRouter01(_tarotSupplyVaultRouter);

        emit StrategyTarotSupplyVaultUsdcUpdatedParams(_tarotSupplyVaultRouter);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        usdcToken.approve(address(tarotSupplyVaultRouter), _amount);

        tarotSupplyVaultRouter.enter(tUsdcToken, _amount, bTarotSpiritToken);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        _amount = _convertAmount(_amount, 10);

        uint256 tUsdcTokenAmount = tUsdcToken.underlyingValuedAsShare(_amount);

        IERC20(address(tUsdcToken)).approve(address(tarotSupplyVaultRouter), tUsdcTokenAmount);

        uint256 withdrawAmount = tarotSupplyVaultRouter.leave(tUsdcToken, tUsdcTokenAmount);

        return withdrawAmount;
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 tUsdcTokenAmount = IERC20(address(tUsdcToken)).balanceOf(address(this));

        IERC20(address(tUsdcToken)).approve(address(tarotSupplyVaultRouter), tUsdcTokenAmount);

        uint256 withdrawAmount = tarotSupplyVaultRouter.leave(tUsdcToken, tUsdcTokenAmount);

        return withdrawAmount;
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {

        uint256 totalUnderlyingAmount;
        for (uint8 i = 0; i < tUsdcToken.getBorrowablesLength(); i++) {
            IBorrowable borrowable = tUsdcToken.borrowables(i);
            uint256 borrowableAmount = borrowable.balanceOf(address(tUsdcToken));
            uint256 underlyingAmount = borrowableAmount * borrowable.exchangeRateLast() / 10 ** borrowable.decimals();
            totalUnderlyingAmount += underlyingAmount;
        }
        uint256 sharesAmount = IERC20(address(tUsdcToken)).balanceOf(address(this));
        uint256 totalSharesAmount = IERC20(address(tUsdcToken)).totalSupply();
        uint256 underlyingAmount = sharesAmount * totalUnderlyingAmount / totalSharesAmount;

        return underlyingAmount;
    }

    function _claimRewards(address _beneficiary) internal override returns (uint256) {
        return 0;
    }

}
