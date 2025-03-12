// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Wombex.sol";
import "@overnight-contracts/connectors/contracts/stuff/PancakeV2.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";


contract StrategyWombexBusd is Strategy {

    // --- structs

    struct StrategyParams {
        address busd;
        address wom;
        address wmx;
        address lpBusd;
        address wmxLpBusd;
        address poolDepositor;
        address pool;
        address pancakeRouter;
    }

    // --- params

    IERC20 public busd;
    IERC20 public wom;
    IERC20 public wmx;

    IAsset public lpBusd;
    IBaseRewardPool public wmxLpBusd;
    IPoolDepositor public poolDepositor;
    IPool public pool;

    IPancakeRouter02 public pancakeRouter;

    uint256 public lpBusdDm;

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
        busd = IERC20(params.busd);
        wom = IERC20(params.wom);
        wmx = IERC20(params.wmx);

        lpBusd = IAsset(params.lpBusd);
        wmxLpBusd = IBaseRewardPool(params.wmxLpBusd);
        poolDepositor = IPoolDepositor(params.poolDepositor);
        pool = IPool(lpBusd.pool());

        pancakeRouter = IPancakeRouter02(params.pancakeRouter);

        lpBusdDm = 10 ** IERC20Metadata(params.lpBusd).decimals();

        busd.approve(address(poolDepositor), type(uint256).max);
        wmxLpBusd.approve(address(poolDepositor), type(uint256).max);

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(busd), "Some token not compatible");

        // get potential deposit amount
        uint256 busdBalance = busd.balanceOf(address(this));
        (uint256 lpBusdAmount,) = poolDepositor.getDepositAmountOut(address(lpBusd), busdBalance);
        // deposit
        poolDepositor.deposit(address(lpBusd), busdBalance, OvnMath.subBasisPoints(lpBusdAmount, 1), true);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(busd), "Some token not compatible");

        // get withdraw amount for 1 LP
        (uint256 busdAmountOneAsset,) = poolDepositor.getWithdrawAmountOut(address(lpBusd), lpBusdDm);
        // add 1bp for smooth withdraw
        uint256 lpBusdAmount = OvnMath.addBasisPoints(_amount, 1) * lpBusdDm / busdAmountOneAsset;
        // withdraw
        poolDepositor.withdraw(address(lpBusd), lpBusdAmount, _amount, address(this));

        return busd.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(busd), "Some token not compatible");

        uint256 lpBusdBalance = wmxLpBusd.balanceOf(address(this));
        if (lpBusdBalance > 0) {
            // get withdraw amount
            (uint256 busdAmount,) = poolDepositor.getWithdrawAmountOut(address(lpBusd), lpBusdBalance);
            // withdraw
            poolDepositor.withdraw(address(lpBusd), lpBusdBalance, OvnMath.subBasisPoints(busdAmount, 1), address(this));
        }

        return busd.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {
        uint256 busdBalance = busd.balanceOf(address(this));

        uint256 lpBusdBalance = wmxLpBusd.balanceOf(address(this));
        if (lpBusdBalance > 0) {
            (uint256 busdAmount,) = poolDepositor.getWithdrawAmountOut(address(lpBusd), lpBusdBalance);
            busdBalance += busdAmount;
        }

        return busdBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        uint256 lpBusdBalance = wmxLpBusd.balanceOf(address(this));
        if (lpBusdBalance > 0) {
            wmxLpBusd.getReward(address(this), false);
        }

        // sell rewards
        uint256 totalBusd;

        uint256 womBalance = wom.balanceOf(address(this));
        if (womBalance > 0) {
            uint256 amountOut = PancakeSwapLibrary.getAmountsOut(
                pancakeRouter,
                address(wom),
                address(busd),
                womBalance
            );

            if (amountOut > 0) {
                uint256 womBusd = PancakeSwapLibrary.swapExactTokensForTokens(
                    pancakeRouter,
                    address(wom),
                    address(busd),
                    womBalance,
                    amountOut * 99 / 100,
                    address(this)
                );

                totalBusd += womBusd;
            }
        }

        uint256 wmxBalance = wmx.balanceOf(address(this));
        if (wmxBalance > 0) {
            uint256 amountOut = PancakeSwapLibrary.getAmountsOut(
                pancakeRouter,
                address(wmx),
                address(busd),
                wmxBalance
            );

            if (amountOut > 0) {
                uint256 wmxBusd = PancakeSwapLibrary.swapExactTokensForTokens(
                    pancakeRouter,
                    address(wmx),
                    address(busd),
                    wmxBalance,
                    amountOut * 99 / 100,
                    address(this)
                );

                totalBusd += wmxBusd;
            }
        }

        if (totalBusd > 0) {
            busd.transfer(_to, totalBusd);
        }

        return totalBusd;
    }

}
