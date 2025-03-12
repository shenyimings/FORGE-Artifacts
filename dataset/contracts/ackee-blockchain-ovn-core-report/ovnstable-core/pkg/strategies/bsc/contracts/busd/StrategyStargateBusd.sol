// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";

import "@overnight-contracts/connectors/contracts/stuff/PancakeV2.sol";
import "@overnight-contracts/connectors/contracts/stuff/Stargate.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";

contract StrategyStargateBusd is Strategy {
    using OvnMath for uint256;

    IERC20 public busdToken;
    IERC20 public stgToken;

    IStargateRouter public stargateRouter;
    IStargatePool public pool;
    ILPStaking public lpStaking;
    IPancakeRouter02 public pancakeRouter;
    uint256 public pid;


    // --- events

    event StrategyUpdatedTokens(address busdToken, address stgToken);

    event StrategyUpdatedParams(address stargateRouter, address pool, address lpStaking, address pancakeRouter, uint256 pid);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _busdToken,
        address _stgToken
    ) external onlyAdmin {

        require(_busdToken != address(0), "Zero address not allowed");
        require(_stgToken != address(0), "Zero address not allowed");

        busdToken = IERC20(_busdToken);
        stgToken = IERC20(_stgToken);

        emit StrategyUpdatedTokens(_busdToken, _stgToken);
    }

    function setParams(
        address _stargateRouter,
        address _pool,
        address _lpStaking,
        address _pancakeRouter,
        uint256 _pid
    ) external onlyAdmin {

        require(_stargateRouter != address(0), "Zero address not allowed");
        require(_pool != address(0), "Zero address not allowed");
        require(_lpStaking != address(0), "Zero address not allowed");
        require(_pancakeRouter != address(0), "Zero address not allowed");

        stargateRouter = IStargateRouter(_stargateRouter);
        pool = IStargatePool(_pool);
        lpStaking = ILPStaking(_lpStaking);
        pancakeRouter = IPancakeRouter02(_pancakeRouter);
        pid = _pid;

        emit StrategyUpdatedParams(_stargateRouter, _pool, _lpStaking, _pancakeRouter, _pid);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(busdToken), "Some token not compatible");

        // add liquidity
        uint256 busdBalance = busdToken.balanceOf(address(this));
        busdToken.approve(address(stargateRouter), busdBalance);
        stargateRouter.addLiquidity(uint16(pool.poolId()), busdBalance, address(this));

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

        require(_asset == address(busdToken), "Some token not compatible");

        // unstake
        // add 1e13 to unstake more than requested
        uint256 busdAmount = _amount + 1e13;
        uint256 lpBalance = busdAmount * 1e6 / pool.amountLPtoLD(1e6);
        (uint256 amount,) = lpStaking.userInfo(pid, address(this));
        if (lpBalance > amount) {
            lpBalance = amount;
        }
        lpStaking.withdraw(pid, lpBalance);

        // remove liquidity
        pool.approve(address(stargateRouter), lpBalance);
        stargateRouter.instantRedeemLocal(uint16(pool.poolId()), lpBalance, address(this));

        return busdToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(busdToken), "Some token not compatible");

        // unstake
        (uint256 amount,) = lpStaking.userInfo(pid, address(this));
        if (amount == 0) {
            return busdToken.balanceOf(address(this));
        }
        lpStaking.withdraw(pid, amount);

        // remove liquidity
        pool.approve(address(stargateRouter), amount);
        stargateRouter.instantRedeemLocal(uint16(pool.poolId()), amount, address(this));

        return busdToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {
        uint256 busdBalance = busdToken.balanceOf(address(this));

        (uint256 amount,) = lpStaking.userInfo(pid, address(this));
        if (amount > 0) {
            busdBalance += pool.amountLPtoLD(amount);
        }

        return busdBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        (uint256 amount,) = lpStaking.userInfo(pid, address(this));
        if (amount == 0) {
            return 0;
        }
        lpStaking.withdraw(pid, 0);

        // sell rewards
        uint256 totalBusd;

        uint256 stgBalance = stgToken.balanceOf(address(this));
        if (stgBalance > 0) {
            uint256 amountOutMin = PancakeSwapLibrary.getAmountsOut(
                pancakeRouter,
                address(stgToken),
                address(busdToken),
                stgBalance
            );

            if (amountOutMin > 0) {
                uint256 stgBusd = PancakeSwapLibrary.swapExactTokensForTokens(
                    pancakeRouter,
                    address(stgToken),
                    address(busdToken),
                    stgBalance,
                    amountOutMin,
                    address(this)
                );
                totalBusd += stgBusd;
            }
        }

        if (totalBusd > 0) {
            busdToken.transfer(_to, totalBusd);
        }

        return totalBusd;
    }

}
