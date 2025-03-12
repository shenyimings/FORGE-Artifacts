// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IERC20} from  "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from  "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {StrategyConvexFarmBase} from "../StrategyConvexFarmBase.sol";
import {ICurveFi_2} from "../../../interfaces/ICurve.sol";
import {IBaseRewardPool} from "../../../interfaces/IConvexFarm.sol";

contract StrategyConvexCurveRen is StrategyConvexFarmBase {
    using SafeERC20 for IERC20;
    using Address for address;

    // btc tokens
    address public constant renBtc = 0xEB4C2781e4ebA804CE9a9803C67d0893436bB27D;
    address public constant wBtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _neuronTokenAddress,
        address _timelock
    )
        StrategyConvexFarmBase(
            0x49849C98ae39Fff122806C06791Fa73784FB3675, // want
            0x93054188d876f558f4a66B2EF1d97d16eDf0895B, // curvePool
            6, // convexPoolId
            _governance,
            _strategist,
            _controller,
            _neuronTokenAddress,
            _timelock
        )
    {}

    function getName() external pure override returns (string memory) {
        return "StrategyConvexCurveRen";
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
        uint256 _to = IERC20(to).balanceOf(self);
        if (_to > 0) {
            IERC20(to).safeApprove(curvePool, 0);
            IERC20(to).safeApprove(curvePool, _to);
            uint256[2] memory liquidity;
            liquidity[toIndex] = _to;
            ICurveFi_2(curvePool).add_liquidity(liquidity, 0);
        }
        emit Harvest();
        deposit();
    }

    function getMostPremium() internal view returns (address, uint256) {
        ICurveFi_2 curve = ICurveFi_2(curvePool);
        uint256[2] memory balances = [
            curve.balances(0), // renBtc
            curve.balances(1) // wBtc
        ];

        // renBtc
        if (balances[0] < balances[1]) {
            return (renBtc, 0);
        }

        // wBtc
        return (wBtc, 1);
    }
}
