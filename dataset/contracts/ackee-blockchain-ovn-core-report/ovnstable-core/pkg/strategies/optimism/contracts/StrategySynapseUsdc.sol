// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";

import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";
import "@overnight-contracts/connectors/contracts/stuff/Synapse.sol";

contract StrategySynapseUsdc is Strategy {

    IERC20 public usdcToken;
    IERC20 public nUsdLPToken;
    IERC20 public synToken;
    IERC20 public wethToken;

    ISwap public swap;
    IMiniChefV2 public miniChefV2;
    uint256 public pid;

    ISwapRouter public uniswapV3Router;
    uint24 public poolFee0;
    uint24 public poolFee1;


    // --- events

    event StrategyUpdatedParams();

    // --- structs

    struct StrategyParams {
        address usdcToken;
        address nUsdLPToken;
        address synToken;
        address wethToken;
        address swap;
        address miniChefV2;
        uint64 pid;
        address uniswapV3Router;
        uint24 poolFee0;
        uint24 poolFee1;
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
        nUsdLPToken = IERC20(params.nUsdLPToken);
        synToken = IERC20(params.synToken);
        wethToken = IERC20(params.wethToken);

        swap = ISwap(params.swap);
        miniChefV2 = IMiniChefV2(params.miniChefV2);
        pid = params.pid;
        uniswapV3Router = ISwapRouter(params.uniswapV3Router);
        poolFee0 = params.poolFee0;
        poolFee1 = params.poolFee1;

        emit StrategyUpdatedParams();
    }



    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        // add liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = OvnMath.subBasisPoints(_amount, 4); // 0.04%

        // calculating minimum LP tokens which we will receive at staking
        uint256 minToMint = swap.calculateTokenAmount(amounts, true);
        amounts[1] = _amount;
        usdcToken.approve(address(swap), _amount);
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

        require(_asset == address(usdcToken), "Some token not compatible");

        // unstake
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = OvnMath.addBasisPoints(_amount, 4) + 1; // 0.04% slippage + 1 for rounding
        uint256 balanceLP = swap.calculateTokenAmount(amounts, false);
        (uint256 amount,) = miniChefV2.userInfo(pid, address(this));
        if (balanceLP > amount) {
            balanceLP = amount;
        }
        miniChefV2.withdraw(pid, balanceLP, address(this));

        // remove liquidity
        nUsdLPToken.approve(address(swap), balanceLP);
        swap.removeLiquidityOneToken(balanceLP, 1, _amount, block.timestamp);

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        // unstake
        (uint256 amount,) = miniChefV2.userInfo(pid, address(this));
        if (amount == 0) {
            return usdcToken.balanceOf(address(this));
        }
        miniChefV2.withdraw(pid, amount, address(this));

        // remove liquidity
        uint256 usdcBalance = swap.calculateRemoveLiquidityOneToken(amount, 1);
        nUsdLPToken.approve(address(swap), amount);
        swap.removeLiquidityOneToken(amount, 1, usdcBalance, block.timestamp);

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 usdcBalance = usdcToken.balanceOf(address(this));

        (uint256 amount,) = miniChefV2.userInfo(pid, address(this));
        if (amount > 0) {
            if (nav) {
                usdcBalance += swap.calculateRemoveLiquidityOneToken(1e18, 1) * amount / 1e18;
            } else {
                usdcBalance += swap.calculateRemoveLiquidityOneToken(amount, 1);
            }
        }

        return usdcBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        (uint256 amount,) = miniChefV2.userInfo(pid, address(this));
        if (amount == 0) {
            return 0;
        }
        miniChefV2.harvest(pid, address(this));

        // sell rewards
        uint256 totalUsdc;

        uint256 synBalance = synToken.balanceOf(address(this));
        if (synBalance > 0) {
            uint256 synUsdc = UniswapV3Library.multiSwap(
                uniswapV3Router,
                address(synToken),
                address(wethToken),
                address(usdcToken),
                poolFee0,
                poolFee1,
                address(this),
                synBalance,
                0
            );
            totalUsdc += synUsdc;
        }

        if (totalUsdc > 0) {
            usdcToken.transfer(_to, totalUsdc);
        }

        return totalUsdc;
    }

}
