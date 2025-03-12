// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {StrategyConvexFarmBase} from "../StrategyConvexFarmBase.sol";
import {ICurveFi_2_256} from "../../../interfaces/ICurve.sol";
import {IBaseRewardPool} from "../../../interfaces/IConvexFarm.sol";

contract StrategyConvexCurveHBTC is StrategyConvexFarmBase {
    using SafeERC20 for IERC20;
    using Address for address;

    // btc tokens
    address public constant HCRV = 0xb19059ebb43466C323583928285a49f558E572Fd;
    address public constant CURVE_POOL = 0x4CA9b3063Ec5866A4B82E437059D2C43d1be596F;
    address public constant HBTC = 0x0316EB71485b0Ab14103307bf65a021042c6d380;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _neuronTokenAddress,
        address _timelock
    )
        StrategyConvexFarmBase(
            HCRV, // want
            CURVE_POOL, // curvePool
            8, // convexPoolId
            _governance,
            _strategist,
            _controller,
            _neuronTokenAddress,
            _timelock
        )
    {}

    function getName() external pure override returns (string memory) {
        return "StrategyConvexCurveHBTC";
    }

    function harvest() public override onlyBenevolent {
        address self = address(this);
        IERC20 cvxIERC20 = IERC20(cvx);
        IERC20 crvIERC20 = IERC20(crv);

        IBaseRewardPool(getCrvRewardContract()).getReward(self, true);

        // Check rewards
        uint256 _cvx = cvxIERC20.balanceOf(self);
        emit RewardToken(cvx, _cvx);

        uint256 _crv = crvIERC20.balanceOf(self);
        emit RewardToken(crv, _crv);

        // Swap cvx to crv
        if (_cvx > 0) {
            cvxIERC20.safeApprove(sushiRouter, 0);
            cvxIERC20.safeApprove(sushiRouter, _cvx);
            _swapSushiswap(cvx, crv, _cvx);
        }

        // Swap crv to stable coins
        (address to, uint256 toIndex) = getMostPremium();

        _crv = crvIERC20.balanceOf(self);

        if (_crv > 0) {
            crvIERC20.safeApprove(univ2Router2, 0);
            crvIERC20.safeApprove(univ2Router2, _crv);
            _swapUniswap(crv, to, _crv);
        }

        // reinvestment
        IERC20 toIERC20 = IERC20(to);
        uint256 _to = toIERC20.balanceOf(self);
        if (_to > 0) {
            toIERC20.approve(curvePool, _to);
            uint256[2] memory liquidity;
            liquidity[toIndex] = _to;
            ICurveFi_2_256(curvePool).add_liquidity(liquidity, 0);
        }
        emit Harvest();
        deposit();
    }

    function getMostPremium() internal view returns (address, uint256) {
        ICurveFi_2_256 curve = ICurveFi_2_256(curvePool);

        uint256[2] memory balances = [
            curve.balances(0), // hbtc
            curve.balances(1)  * 1e10 // wBtc
        ];

        if (balances[0] < balances[1]) {
            return (HBTC, 0);
        }

        return (WBTC, 1);
    }
}
