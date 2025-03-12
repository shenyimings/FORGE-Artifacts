// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";
import "@overnight-contracts/connectors/contracts/stuff/Reaper.sol";


contract StrategyReaperSonneUsdc is Strategy {

    // --- structs

    struct StrategyParams {
        address usdcToken;
        address soUsdc;
    }

    // --- params

    IERC20 public usdcToken;
    IReaperVault public soUsdc;

    // --- events

    event StrategyUpdatedParams();

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }

    // --- Setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
        usdcToken = IERC20(params.usdcToken);
        soUsdc = IReaperVault(params.soUsdc);

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        usdcToken.approve(address(soUsdc), usdcBalance);
        soUsdc.deposit(usdcBalance);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 sharesBalance = soUsdc.balanceOf(address(this));
        if (sharesBalance == 0) {
            return 0;
        }

        // add 10 for unstake more than requested
        uint256 shares = (_amount + 10) * soUsdc.totalSupply() / soUsdc.balance();
        soUsdc.withdraw(shares);

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 sharesBalance = soUsdc.balanceOf(address(this));
        if (sharesBalance == 0) {
            return 0;
        }

        soUsdc.withdrawAll();

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {
        uint256 usdcBalance = usdcToken.balanceOf(address(this));

        uint256 sharesBalance = soUsdc.balanceOf(address(this));
        usdcBalance += sharesBalance * soUsdc.balance() / soUsdc.totalSupply();

        return usdcBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {
        return 0;
    }

}
