// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";

import "@overnight-contracts/connectors/contracts/stuff/AaveV3.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";

contract StrategyAaveDai is Strategy {

    IERC20 public daiToken;
    IERC20 public usdcToken;
    IERC20 public aDaiToken;

    IPoolAddressesProvider public aaveProvider;

    IRewardsController public rewardsController;
    ISwapRouter public uniswapV3Router;

    IERC20 public opToken;
    uint24 public poolOpUsdcFee;
    uint24 public poolUsdcDaiFee;


    // --- events
    event StrategyUpdatedParams();


    // --- structs

    struct StrategyParams {
        address dai;
        address usdc;
        address aDai;
        address aaveProvider;
        address rewardsController;
        address uniswapV3Router;
        address op;
        uint24 poolOpUsdcFee;
        uint24 poolUsdcDaiFee;
    }


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
        daiToken = IERC20(params.dai);
        usdcToken = IERC20(params.usdc);
        aDaiToken = IERC20(params.aDai);
        aaveProvider = IPoolAddressesProvider(params.aaveProvider);
        rewardsController = IRewardsController(params.rewardsController);
        uniswapV3Router = ISwapRouter(params.uniswapV3Router);
        opToken = IERC20(params.op);
        poolOpUsdcFee = params.poolOpUsdcFee;
        poolUsdcDaiFee = params.poolUsdcDaiFee;

        emit StrategyUpdatedParams();
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(daiToken), "Some token not compatible");

        IPool pool = IPool(aaveProvider.getPool());
        daiToken.approve(address(pool), _amount);
        pool.deposit(address(daiToken), _amount, address(this), 0);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(daiToken), "Some token not compatible");

        IPool pool = IPool(aaveProvider.getPool());
        aDaiToken.approve(address(pool), _amount);
        uint256 withdrawAmount = pool.withdraw(_asset, _amount, address(this));

        return withdrawAmount;
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(daiToken), "Some token not compatible");

        uint256 _amount = aDaiToken.balanceOf(address(this));

        IPool pool = IPool(aaveProvider.getPool());
        aDaiToken.approve(address(pool), _amount);
        uint256 withdrawAmount = pool.withdraw(_asset, _amount, address(this));

        return withdrawAmount;
    }

    function netAssetValue() external view override returns (uint256) {
        return aDaiToken.balanceOf(address(this));
    }

    function liquidationValue() external view override returns (uint256) {
        return aDaiToken.balanceOf(address(this));
    }

    function _claimRewards(address _beneficiary) internal override returns (uint256) {

        // claim rewards
        uint256 aDaiBalance = aDaiToken.balanceOf(address(this));
        if (aDaiBalance == 0) {
            return 0;
        }

        address[] memory assets = new address[](1);
        assets[0] = address(aDaiToken);
        (address[] memory rewardsList, uint256[] memory claimedAmounts) = rewardsController.claimAllRewardsToSelf(assets);

        // sell rewards
        uint256 totalDai;

        uint256 opBalance = opToken.balanceOf(address(this));
        if (opBalance > 0) {
            uint256 opDai = UniswapV3Library.multiSwap(
                uniswapV3Router,
                address(opToken),
                address(usdcToken),
                address(daiToken),
                poolOpUsdcFee,
                poolUsdcDaiFee,
                address(this),
                opBalance,
                0
            );
            totalDai += opDai;
        }

        if (totalDai > 0) {
            daiToken.transfer(_beneficiary, totalDai);
        }

        return totalDai;
    }

}
