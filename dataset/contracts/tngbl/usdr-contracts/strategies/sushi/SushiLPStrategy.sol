// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "../../constants/roles.sol";
import "../IStrategy.sol";
import "./IMiniChefV2.sol";

contract SushiLPStrategy is AccessControl, Pausable, IStrategy {
    using SafeERC20 for IERC20;

    address public native;
    address public output;
    address public want;
    address public lpToken0;
    address public lpToken1;

    address public treasury;
    address public router;
    address public chef;
    uint256 public poolId;

    address[] public outputToNativeRoute;
    address[] public nativeToOutputRoute;
    address[] public outputToLp0Route;
    address[] public outputToLp1Route;

    constructor(
        address want_,
        uint256 poolId_,
        address chef_,
        address treasury_,
        address router_,
        address[] memory _outputToNativeRoute,
        address[] memory _outputToLp0Route,
        address[] memory _outputToLp1Route
    ) {
        want = want_;
        poolId = poolId_;
        chef = chef_;
        treasury = treasury_;
        router = router_;

        require(_outputToNativeRoute.length >= 2);
        output = _outputToNativeRoute[0];
        native = _outputToNativeRoute[_outputToNativeRoute.length - 1];
        outputToNativeRoute = _outputToNativeRoute;

        // setup lp routing
        lpToken0 = IUniswapV2Pair(want).token0();
        require(_outputToLp0Route[0] == output);
        require(_outputToLp0Route[_outputToLp0Route.length - 1] == lpToken0);
        outputToLp0Route = _outputToLp0Route;

        lpToken1 = IUniswapV2Pair(want).token1();
        require(_outputToLp1Route[0] == output);
        require(_outputToLp1Route[_outputToLp1Route.length - 1] == lpToken1);
        outputToLp1Route = _outputToLp1Route;

        nativeToOutputRoute = new address[](_outputToNativeRoute.length);
        for (uint256 i = 0; i < _outputToNativeRoute.length; i++) {
            uint256 idx = _outputToNativeRoute.length - 1 - i;
            nativeToOutputRoute[i] = outputToNativeRoute[idx];
        }

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyTreasury() {
        require(msg.sender == treasury, "!TREASURY");
        _;
    }

    function deposit() public whenNotPaused {
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        if (wantBal > 0) {
            IMiniChefV2(chef).deposit(poolId, wantBal, address(this));
        }
    }

    function withdraw(uint256 _amount) external onlyTreasury {
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        if (wantBal < _amount) {
            IMiniChefV2(chef).withdraw(
                poolId,
                _amount - wantBal,
                address(this)
            );
            wantBal = IERC20(want).balanceOf(address(this));
        }
        if (wantBal > _amount) {
            wantBal = _amount;
        }
        IERC20(want).safeTransfer(treasury, wantBal);
    }

    function harvest() external whenNotPaused onlyRole(CONTROLLER_ROLE) {
        IMiniChefV2(chef).harvest(poolId, address(this));
        addLiquidity();
        deposit();
    }

    function addLiquidity() internal {
        uint256 fullAmount = IERC20(output).balanceOf(address(this));
        uint256 outputHalf;
        assembly {
            outputHalf := shr(1, fullAmount)
        }
        _ensureAllowance(output, router, fullAmount);
        if (lpToken0 != output) {
            IUniswapV2Router02(router).swapExactTokensForTokens(
                outputHalf,
                0,
                outputToLp0Route,
                address(this),
                block.timestamp
            );
        }
        if (lpToken1 != output) {
            IUniswapV2Router02(router).swapExactTokensForTokens(
                outputHalf,
                0,
                outputToLp1Route,
                address(this),
                block.timestamp
            );
        }
        uint256 lp0Bal = IERC20(lpToken0).balanceOf(address(this));
        uint256 lp1Bal = IERC20(lpToken1).balanceOf(address(this));
        _ensureAllowance(lpToken0, router, lp0Bal);
        _ensureAllowance(lpToken1, router, lp1Bal);
        IUniswapV2Router02(router).addLiquidity(
            lpToken0,
            lpToken1,
            lp0Bal,
            lp1Bal,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    function balanceOf() public view returns (uint256) {
        return balanceOfWant() + balanceOfPool();
    }

    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function balanceOfPool() public view returns (uint256) {
        IMiniChefV2.UserInfo memory info = IMiniChefV2(chef).userInfo(
            poolId,
            address(this)
        );
        return info.amount;
    }

    function retire() external onlyTreasury {
        IMiniChefV2(chef).emergencyWithdraw(poolId, address(this));
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        IERC20(want).transfer(treasury, wantBal);
    }

    function panic() public onlyRole(CONTROLLER_ROLE) {
        pause();
        IMiniChefV2(chef).emergencyWithdraw(poolId, address(this));
    }

    function pause() public onlyRole(CONTROLLER_ROLE) {
        _pause();
        _removeAllowances();
    }

    function unpause() external onlyRole(CONTROLLER_ROLE) {
        _unpause();
        deposit();
    }

    function _ensureAllowance(
        address token,
        address spender,
        uint256 amount
    ) internal {
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        if (allowance < amount) {
            IERC20(token).approve(spender, 0);
            IERC20(token).approve(spender, type(uint256).max);
        }
    }

    function _removeAllowances() internal {
        IERC20(want).approve(chef, 0);
        IERC20(output).approve(router, 0);
        IERC20(native).approve(router, 0);
        IERC20(lpToken0).approve(router, 0);
        IERC20(lpToken1).approve(router, 0);
    }
}
