// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./core/Strategy.sol";
import "./connectors/scream/interfaces/ICErc20Delegator.sol";
import "./exchanges/UniswapV2Exchange.sol";
import "./connectors/scream/interfaces/IScreamUnitroller.sol";

contract StrategyScream is Strategy, UniswapV2Exchange {

    IERC20 public usdcToken;
    IERC20 public screamToken;

    uint256 constant public SCREAM_EXCHANGE_RATE_SCALING = 10 ** 18;
    uint256 public screamTokenDenominator;

    ICErc20Delegator public cErc20Delegator;
    IScreamUnitroller public screamUnitroller;


    // --- events

    event StrategyUpdatedTokens(address usdcToken, address screamToken, uint256 screamTokenDenominator);

    event StrategyUpdatedParams(address creamProvider, address screamUnitroller, address uniswapRouter);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _screamToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_screamToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        screamToken = IERC20(_screamToken);

        screamTokenDenominator = 10 ** IERC20Metadata(_screamToken).decimals();

        emit StrategyUpdatedTokens(_usdcToken, _screamToken, screamTokenDenominator);
    }

    function setParams(
        address _cErc20Delegator,
        address _screamUnitroller,
        address _uniswapRouter
    ) external onlyAdmin {

        require(_cErc20Delegator != address(0), "Zero address not allowed");
        require(_screamUnitroller != address(0), "Zero address not allowed");
        require(_uniswapRouter != address(0), "Zero address not allowed");

        cErc20Delegator = ICErc20Delegator(_cErc20Delegator);
        screamUnitroller = IScreamUnitroller(_screamUnitroller);

        _setUniswapRouter(_uniswapRouter);

        emit StrategyUpdatedParams(_cErc20Delegator, _screamUnitroller, _uniswapRouter);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        usdcToken.approve(address(cErc20Delegator), _amount);
        cErc20Delegator.mint(_amount);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        cErc20Delegator.redeemUnderlying(_amount);
        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 amount = cErc20Delegator.balanceOf(address(this));

        if (amount > 0) {
            cErc20Delegator.redeem(amount);
        }
        
        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {
        uint256 balance = cErc20Delegator.balanceOf(address(this));
        uint256 exchange = cErc20Delegator.exchangeRateStored();
        return balance * exchange / SCREAM_EXCHANGE_RATE_SCALING;
    }

    function _claimRewards(address _beneficiary) internal override returns (uint256) {
        screamUnitroller.claimComp(address(this));

        uint256 screamBalance = screamToken.balanceOf(address(this));
        uint256 screamUsdc;

        if (screamBalance > 0) {
            screamUsdc = _swapExactTokensForTokens(
                address(screamToken),
                address(usdcToken),
                screamBalance,
                address(this)
            );
        }
        
        uint256 usdcBalance = usdcToken.balanceOf(address(this));

        if (usdcBalance > 0) {
            usdcToken.transfer(_beneficiary, usdcBalance);
        }

        return screamUsdc;
    }
    
}