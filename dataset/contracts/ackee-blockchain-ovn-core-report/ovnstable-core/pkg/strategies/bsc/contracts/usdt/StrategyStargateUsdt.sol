// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";

import "@overnight-contracts/connectors/contracts/stuff/PancakeV2.sol";
import "@overnight-contracts/connectors/contracts/stuff/Stargate.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";

contract StrategyStargateUsdt is Strategy {
    using OvnMath for uint256;

    IERC20 public usdtToken;
    IERC20 public stgToken;
    IERC20 public busdToken;

    IStargateRouter public stargateRouter;
    IStargatePool public pool;
    ILPStaking public lpStaking;
    IPancakeRouter02 public pancakeRouter;
    uint256 public pid;


    // --- events

    event StrategyUpdatedParams();


    // --- structs

    struct StrategyParams {
        address usdtToken;
        address stgToken;
        address busdToken;
        address stargateRouter;
        address pool;
        address lpStaking;
        address pancakeRouter;
        uint256 pid;
    }


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
        usdtToken = IERC20(params.usdtToken);
        stgToken = IERC20(params.stgToken);
        busdToken = IERC20(params.busdToken);

        stargateRouter = IStargateRouter(params.stargateRouter);
        pool = IStargatePool(params.pool);
        lpStaking = ILPStaking(params.lpStaking);
        pancakeRouter = IPancakeRouter02(params.pancakeRouter);
        pid = params.pid;

        emit StrategyUpdatedParams();
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdtToken), "Some token not compatible");

        // add liquidity
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        usdtToken.approve(address(stargateRouter), usdtBalance);
        stargateRouter.addLiquidity(uint16(pool.poolId()), usdtBalance, address(this));

        // stake
        uint256 lpBalance = pool.balanceOf(address(this));
        pool.approve(address(lpStaking), lpBalance);
        lpStaking.deposit(pid, lpBalance);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdtToken), "Some token not compatible");

        // unstake
        // add 1e13 to unstake more than requested
        // TODO Not working with big amounts: return less amount > 100 000 !!!!! Need FIXED before deploy to production
        uint256 usdtAmount = _amount + 1e13;
        uint256 lpBalance = usdtAmount * 1e6 / pool.amountLPtoLD(1e6);
        (uint256 amount,) = lpStaking.userInfo(pid, address(this));
        if (lpBalance > amount) {
            lpBalance = amount;
        }
        lpStaking.withdraw(pid, lpBalance);

        // remove liquidity
        pool.approve(address(stargateRouter), lpBalance);
        stargateRouter.instantRedeemLocal(uint16(pool.poolId()), lpBalance, address(this));

        return usdtToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdtToken), "Some token not compatible");

        // unstake
        (uint256 amount,) = lpStaking.userInfo(pid, address(this));
        if (amount == 0) {
            return usdtToken.balanceOf(address(this));
        }
        lpStaking.withdraw(pid, amount);

        // remove liquidity
        pool.approve(address(stargateRouter), amount);
        stargateRouter.instantRedeemLocal(uint16(pool.poolId()), amount, address(this));

        return usdtToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {
        uint256 usdtBalance = usdtToken.balanceOf(address(this));

        (uint256 amount,) = lpStaking.userInfo(pid, address(this));
        if (amount > 0) {
            usdtBalance += pool.amountLPtoLD(amount);
        }

        return usdtBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        (uint256 amount,) = lpStaking.userInfo(pid, address(this));
        if (amount == 0) {
            return 0;
        }
        lpStaking.withdraw(pid, 0);

        // sell rewards
        uint256 totalUsdt;

        uint256 stgBalance = stgToken.balanceOf(address(this));
        if (stgBalance > 0) {
            uint256 amountOutMin = PancakeSwapLibrary.getAmountsOut(
                pancakeRouter,
                address(stgToken),
                address(busdToken),
                address(usdtToken),
                stgBalance
            );

            if (amountOutMin > 0) {
                uint256 stgUsdt = PancakeSwapLibrary.swapExactTokensForTokens(
                    pancakeRouter,
                    address(stgToken),
                    address(busdToken),
                    address(usdtToken),
                    stgBalance,
                    amountOutMin,
                    address(this)
                );
                totalUsdt += stgUsdt;
            }
        }

        if (totalUsdt > 0) {
            usdtToken.transfer(_to, totalUsdt);
        }

        return totalUsdt;
    }

}
