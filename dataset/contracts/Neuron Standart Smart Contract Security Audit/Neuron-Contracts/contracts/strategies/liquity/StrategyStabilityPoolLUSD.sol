// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IERC20} from  "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from  "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {StrategyBase} from "../StrategyBase.sol";
import {IStabilityPool} from "../../interfaces/IStabilityPool.sol";
import {ITroveManager} from "../../interfaces/ITroveManager.sol";
import {ILiquityPriceFeed} from "../../interfaces/ILiquityPriceFeed.sol";
import {ISortedTroves} from "../../interfaces/ISortedTroves.sol";

contract StrategyStabilityPoolLUSD is StrategyBase {
    using SafeERC20 for IERC20;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant LUSD = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    address public constant LQTY = 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D;
    address payable public constant STABILITY_POOL = payable(0x66017D22b0f8556afDd19FC67041899Eb65a21bb);

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _neuronTokenAddress,
        address _timelock
    ) StrategyBase(LUSD, _governance, _strategist, _controller, _neuronTokenAddress, _timelock) {}

    function balanceOfPool() public view override returns (uint256 balance_) {
        (balance_, ) = IStabilityPool(STABILITY_POOL).deposits(address(this));
    }

    function getName() external pure override returns (string memory) {
        return "StrategyStabilityPoolLUSD";
    }

    function deposit() public override {
        IERC20 lusd = IERC20(LUSD);
        uint256 lusdBalance = lusd.balanceOf(address(this));
        if (lusdBalance > 0) {
            IStabilityPool(STABILITY_POOL).provideToSP(lusdBalance, address(0));
            emit Deposit(lusdBalance);
        }
    }

    function _withdrawSome(uint256 _amount) internal override returns (uint256) {
        address self = address(this);
        IStabilityPool(STABILITY_POOL).withdrawFromSP(_amount);

        uint256 ethBalance = self.balance;
        if (ethBalance > 0) {
            _swapUniswapExactETHForTokens(LUSD, ethBalance);
            emit RewardToken(ETH, ethBalance);
        }

        uint256 lqtyBalance = IERC20(LQTY).balanceOf(self);

        if (lqtyBalance > 0) {
            IERC20(LQTY).safeApprove(univ2Router2, 0);
            IERC20(LQTY).safeApprove(univ2Router2, lqtyBalance);
            _swapUniswap(LQTY, LUSD, lqtyBalance);
            emit RewardToken(LQTY, lqtyBalance);
        }

        return IERC20(LUSD).balanceOf(self);
    }

    function harvest() public override {
        _withdrawSome(0);
        emit Harvest();
        deposit();
    }
}
