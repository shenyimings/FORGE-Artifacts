// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV2.sol";
import "@overnight-contracts/connectors/contracts/stuff/Tetu.sol";

contract StrategyTetuUsdc is Strategy, UniswapV2Exchange {

    IERC20 public usdcToken;
    IERC20 public tetuToken;

    ISmartVault public usdcSmartVault;
    ISmartVault public xTetuSmartVault;


    // --- events

    event StrategyUpdatedTokens(address usdcToken, address tetuToken);

    event StrategyUpdatedParams(address usdcSmartVault, address xTetuSmartVault, address tetuSwapRouter);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _tetuToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_tetuToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        tetuToken = IERC20(_tetuToken);

        emit StrategyUpdatedTokens(_usdcToken, _tetuToken);
    }

    function setParams(
        address _usdcSmartVault,
        address _xTetuSmartVault,
        address _tetuSwapRouter
    ) external onlyAdmin {

        require(_usdcSmartVault != address(0), "Zero address not allowed");
        require(_xTetuSmartVault != address(0), "Zero address not allowed");
        require(_tetuSwapRouter != address(0), "Zero address not allowed");

        usdcSmartVault = ISmartVault(_usdcSmartVault);
        xTetuSmartVault = ISmartVault(_xTetuSmartVault);
        _setUniswapRouter(_tetuSwapRouter);

        emit StrategyUpdatedParams(_usdcSmartVault, _xTetuSmartVault, _tetuSwapRouter);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        usdcToken.approve(address(usdcSmartVault), _amount);
        usdcSmartVault.depositAndInvest(_amount);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 numberOfShares = OvnMath.addBasisPoints(_amount, BASIS_POINTS_FOR_SLIPPAGE) * usdcSmartVault.totalSupply() / usdcSmartVault.underlyingBalanceWithInvestment();
        usdcSmartVault.withdraw(numberOfShares);

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        usdcSmartVault.exit();

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return usdcSmartVault.underlyingBalanceWithInvestmentForHolder(address(this));
    }

    function liquidationValue() external view override returns (uint256) {
        return usdcSmartVault.underlyingBalanceWithInvestmentForHolder(address(this));
    }

    function _claimRewards(address _beneficiary) internal override returns (uint256) {

        // claim rewards
        if (IERC20(address(usdcSmartVault)).balanceOf(address(this)) <= 0) {
            return 0;
        }
        usdcSmartVault.getAllRewards();

        if (IERC20(address(xTetuSmartVault)).balanceOf(address(this)) <= 0) {
            return 0;
        }
        xTetuSmartVault.exit();

        // sell rewards
        uint256 totalUsdc;

        uint256 tetuBalance = tetuToken.balanceOf(address(this));
        if (tetuBalance > 0) {
            uint256 tetuUsdc = _swapExactTokensForTokens(
                address(tetuToken),
                address(usdcToken),
                tetuBalance,
                address(this)
            );
            totalUsdc += tetuUsdc;
        }

        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        if (usdcBalance > 0) {
            usdcToken.transfer(_beneficiary, usdcBalance);
        }

        return totalUsdc;
    }

}
