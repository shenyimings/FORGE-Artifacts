// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";
import "@overnight-contracts/connectors/contracts/stuff/Reaper.sol";


contract StrategyReaperSonneDaiDai is Strategy {

    // --- params

    IERC20 public dai;
    IReaperVault public soDai;

    // --- structs

    struct StrategyParams {
        address dai;
        address soDai;
    }

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
        dai = IERC20(params.dai);
        soDai = IReaperVault(params.soDai);

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(dai), "Some token not compatible");

        uint256 daiBalance = dai.balanceOf(address(this));
        dai.approve(address(soDai), daiBalance);
        soDai.deposit(daiBalance);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(dai), "Some token not compatible");

        uint256 sharesBalance = soDai.balanceOf(address(this));
        if (sharesBalance == 0) {
            return 0;
        }

        // add 10 for unstake more than requested
        uint256 shares = (_amount + 10) * soDai.totalSupply() / soDai.balance();
        soDai.withdraw(shares);

        return dai.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(dai), "Some token not compatible");

        uint256 sharesBalance = soDai.balanceOf(address(this));
        if (sharesBalance == 0) {
            return 0;
        }

        soDai.withdrawAll();

        return dai.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {
        uint256 sharesBalance = soDai.balanceOf(address(this));
        return sharesBalance * soDai.balance() / soDai.totalSupply();
    }

    function _claimRewards(address _to) internal override returns (uint256) {
        return 0;
    }

}
