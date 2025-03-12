// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/PancakeV2.sol";
import "@overnight-contracts/connectors/contracts/stuff/Synapse.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";

contract StrategySynapseUsdt is Strategy {
    using OvnMath for uint256;

    IERC20 public usdtToken;
    IERC20 public nUsdLPToken;
    IERC20 public synToken;
    IERC20 public busdToken;

    ISwap public swap;
    IMiniChefV2 public miniChefV2;
    IPancakeRouter02 public pancakeRouter;
    uint256 public pid;


    // --- events

    event StrategyUpdatedParams();


    // --- structs

    struct StrategyParams {
        address usdtToken;
        address nUsdLPToken;
        address synToken;
        address busdToken;
        address swap;
        address miniChefV2;
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
        nUsdLPToken = IERC20(params.nUsdLPToken);
        synToken = IERC20(params.synToken);
        busdToken = IERC20(params.busdToken);

        swap = ISwap(params.swap);
        miniChefV2 = IMiniChefV2(params.miniChefV2);
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
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 0;
        amounts[1] = 0;
        amounts[2] = 0;
        // sub 4 bp to calculate min amount
        amounts[3] = usdtBalance.subBasisPoints(4);
        uint256 minToMint = swap.calculateTokenAmount(amounts, true);
        amounts[3] = usdtBalance;
        usdtToken.approve(address(swap), usdtBalance);
        uint256 nUsdLPTokenAmount = swap.addLiquidity(amounts, minToMint, block.timestamp);

        // stake
        nUsdLPToken.approve(address(miniChefV2), nUsdLPTokenAmount);
        miniChefV2.deposit(pid, nUsdLPTokenAmount, address(this));
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdtToken), "Some token not compatible");

        // unstake
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 0;
        amounts[1] = 0;
        amounts[2] = 0;
        // add 4 bp to unstake more than requested
        amounts[3] = _amount.addBasisPoints(4) + 1;
        uint256 lpBalance = swap.calculateTokenAmount(amounts, false);
        (uint256 amount,) = miniChefV2.userInfo(pid, address(this));
        if (lpBalance > amount) {
            lpBalance = amount;
        }
        miniChefV2.withdraw(pid, lpBalance, address(this));

        // remove liquidity
        nUsdLPToken.approve(address(swap), lpBalance);
        swap.removeLiquidityOneToken(lpBalance, 3, _amount, block.timestamp);

        return usdtToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdtToken), "Some token not compatible");

        // unstake
        (uint256 amount,) = miniChefV2.userInfo(pid, address(this));
        if (amount == 0) {
            return usdtToken.balanceOf(address(this));
        }
        miniChefV2.withdraw(pid, amount, address(this));

        // remove liquidity
        uint256 usdtBalance = swap.calculateRemoveLiquidityOneToken(amount, 3);
        nUsdLPToken.approve(address(swap), amount);
        swap.removeLiquidityOneToken(amount, 3, usdtBalance, block.timestamp);

        return usdtToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 usdtBalance = usdtToken.balanceOf(address(this));

        (uint256 amount,) = miniChefV2.userInfo(pid, address(this));
        if (amount > 0) {
            if (nav) {
                usdtBalance += swap.calculateRemoveLiquidityOneToken(1e18, 3) * amount / 1e18;
            } else {
                usdtBalance += swap.calculateRemoveLiquidityOneToken(amount, 3);
            }
        }

        return usdtBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        (uint256 amount,) = miniChefV2.userInfo(pid, address(this));
        if (amount == 0) {
            return 0;
        }
        miniChefV2.harvest(pid, address(this));

        // sell rewards
        uint256 totalUsdt;

        uint256 synBalance = synToken.balanceOf(address(this));
        if (synBalance > 0) {
            uint256 amountOutMin = PancakeSwapLibrary.getAmountsOut(
                pancakeRouter,
                address(synToken),
                address(busdToken),
                address(usdtToken),
                synBalance
            );

            if (amountOutMin > 0) {
                uint256 synUsdt = PancakeSwapLibrary.swapExactTokensForTokens(
                    pancakeRouter,
                    address(synToken),
                    address(busdToken),
                    address(usdtToken),
                    synBalance,
                    amountOutMin,
                    address(this)
                );
                totalUsdt += synUsdt;
            }
        }

        if (totalUsdt > 0) {
            usdtToken.transfer(_to, totalUsdt);
        }

        return totalUsdt;
    }

}
