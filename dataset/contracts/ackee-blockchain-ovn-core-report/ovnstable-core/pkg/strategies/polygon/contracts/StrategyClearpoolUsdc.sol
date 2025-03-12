// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Clearpool.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";


contract StrategyClearpoolUsdc is Strategy {

    IERC20 public usdcToken;
    IERC20 public cpoolToken;

    IPoolBase public poolBase;
    IPoolMaster public poolMaster;

    ISwapRouter public uniswapV3Router;
    uint24 public poolFeeCpoolUsdc;

    // corporative address
    address public rewardWallet;


    // --- events

    event StrategyUpdatedParams();


    // --- structs

    struct StrategyParams {
        address usdcToken;
        address cpoolToken;
        address poolBase;
        address poolMaster;
        address uniswapV3Router;
        uint24 poolFeeCpoolUsdc;
        address rewardWallet;
    }


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setParams(StrategyParams calldata params) external onlyAdmin {

        usdcToken = IERC20(params.usdcToken);
        cpoolToken = IERC20(params.cpoolToken);

        poolBase = IPoolBase(params.poolBase);
        poolMaster = IPoolMaster(params.poolMaster);

        uniswapV3Router = ISwapRouter(params.uniswapV3Router);
        poolFeeCpoolUsdc = params.poolFeeCpoolUsdc;

        rewardWallet = params.rewardWallet;

        usdcToken.approve(address(poolBase), type(uint256).max);

        emit StrategyUpdatedParams();
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        poolBase.provide(usdcBalance);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        // add 10 to unstake more than requested _amount
        uint256 lpTokenAmount = (_amount + 10) * 1e18 / poolBase.getCurrentExchangeRate();
        poolBase.redeem(lpTokenAmount);
        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 lpTokenAmount = poolBase.balanceOf(address(this));
        poolBase.redeem(lpTokenAmount);
        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {
        return poolBase.balanceOf(address(this)) * poolBase.getCurrentExchangeRate() / 1e18;
    }

    function _claimRewards(address _beneficiary) internal override returns (uint256) {

        // claim rewards
        uint256 lpTokenAmount = poolBase.balanceOf(address(this));
        if (lpTokenAmount > 0) {
            address[] memory pools = new address[](1);
            pools[0] = address(poolBase);
            poolMaster.withdrawReward(pools);
        }

        // send rewards to rewardWallet
        uint256 cpoolBalance = cpoolToken.balanceOf(address(this));
        if (cpoolBalance > 0) {
            cpoolToken.transfer(rewardWallet, cpoolBalance);
        }

        return 0;
    }

}
