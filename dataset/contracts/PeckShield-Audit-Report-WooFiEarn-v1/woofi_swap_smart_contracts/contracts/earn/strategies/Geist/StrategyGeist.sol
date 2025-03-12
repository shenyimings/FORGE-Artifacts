// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/*

░██╗░░░░░░░██╗░█████╗░░█████╗░░░░░░░███████╗██╗
░██║░░██╗░░██║██╔══██╗██╔══██╗░░░░░░██╔════╝██║
░╚██╗████╗██╔╝██║░░██║██║░░██║█████╗█████╗░░██║
░░████╔═████║░██║░░██║██║░░██║╚════╝██╔══╝░░██║
░░╚██╔╝░╚██╔╝░╚█████╔╝╚█████╔╝░░░░░░██║░░░░░██║
░░░╚═╝░░░╚═╝░░░╚════╝░░╚════╝░░░░░░░╚═╝░░░░░╚═╝

*
* MIT License
* ===========
*
* Copyright (c) 2020 WooTrade
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '../../../interfaces/TraderJoe/IUniswapRouter.sol';
import '../../../interfaces/Geist/IDataProvider.sol';
import '../../../interfaces/Geist/IIncentivesController.sol';
import '../../../interfaces/Geist/ILendingPool.sol';
import '../../../interfaces/Geist/IMultiFeeDistribution.sol';
import '../../../interfaces/IWooAccessManager.sol';
import '../../../interfaces/IWETH.sol';
import '../BaseStrategy.sol';

contract StrategyGeist is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct TokenAddresses {
        address token; // Deposit Token
        address gToken; // Token that minted by lend
    }

    /* ----- State Variables ----- */

    TokenAddresses public wantToken;
    TokenAddresses[] public rewards;

    address[] public rewardToWNativeRoute;
    address[] public wNativeToWantRoute;
    address[][] public extraRewardToWNativeRoutes;

    uint256 public lastHarvest;

    /* ----- Constant Variables ----- */

    address public constant wNative = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83); // WFTM
    address public constant reward = address(0xd8321AA83Fb0a4ECd6348D4577431310A6E0814d); // GEIST
    address public constant uniRouter = address(0xF491e7B69E4244ad4002BC14e878a34207E38c29); // SpookySwapRouter

    address public dataProvider = address(0xf3B0611e2E4D2cd6aB4bb3e01aDe211c3f42A8C3);
    address public lendingPool = address(0x9FAD24f572045c7869117160A571B2e50b10d068);
    address public multiFeeDistribution = address(0x49c93a95dbcc9A6A4D8f77E59c038ce5020e82f8);
    address public incentivesController = address(0x297FddC5c33Ef988dd03bd13e162aE084ea1fE57);

    /* ----- Events ----- */

    event StratHarvest(address indexed harvester, uint256 wantHarvested, uint256 tvl);
    event Deposit(uint256 tvl);
    event Withdraw(uint256 tvl);

    constructor(
        address _vault,
        address _accessManager,
        address _want,
        address[] memory _rewardToWNativeRoute,
        address[] memory _wNativeToWantRoute,
        address[][] memory _extraRewardToWNativeRoutes
    ) public BaseStrategy(_vault, _accessManager) {
        (address gToken, , ) = IDataProvider(dataProvider).getReserveTokensAddresses(_want);
        wantToken = TokenAddresses(_want, gToken);

        rewardToWNativeRoute = _rewardToWNativeRoute;
        wNativeToWantRoute = _wNativeToWantRoute;
        extraRewardToWNativeRoutes = _extraRewardToWNativeRoutes;

        for (uint256 i; i < extraRewardToWNativeRoutes.length; i++) {
            address _token = extraRewardToWNativeRoutes[i][0];
            (address _gToken, , ) = IDataProvider(dataProvider).getReserveTokensAddresses(_token);
            rewards.push(TokenAddresses(_token, _gToken));
        }

        _giveAllowances();
    }

    /* ----- External Functions ----- */

    function rewardToWNative() external view returns (address[] memory) {
        return rewardToWNativeRoute;
    }

    /* ----- Public Functions ----- */

    function harvest() public override whenNotPaused {
        require(msg.sender == tx.origin || msg.sender == address(vault), 'StrategyGeist: EOA_or_vault');

        uint256 reserveWantGTokenBal = IERC20(wantToken.gToken).balanceOf(address(this));
        address[] memory tokens = new address[](1);
        tokens[0] = wantToken.gToken;
        // Claim pending rewards for one or more pools.
        // Rewards are not received directly, they are minted by the rewardMinter.
        IIncentivesController(incentivesController).claim(address(this), tokens);
        // Withdraw full unlocked balance and claim pending rewards
        IMultiFeeDistribution(multiFeeDistribution).exit();

        uint256 rewardBal = IERC20(reward).balanceOf(address(this));
        if (rewardBal > 0) {
            uint256 beforeBal = balanceOfWant();
            _swapRewards(reserveWantGTokenBal);
            uint256 wantHarvested = balanceOfWant().sub(beforeBal);
            uint256 fee = chargePerformanceFee(wantHarvested);
            deposit();

            lastHarvest = block.timestamp;
            emit StratHarvest(msg.sender, wantHarvested.sub(fee), balanceOf());
        }

        uint256 wantGTokenBalAfter = IERC20(wantToken.gToken).balanceOf(address(this));
        require(wantGTokenBalAfter >= reserveWantGTokenBal, 'StrategyGeist: gTokenBalError');
    }

    function deposit() public override whenNotPaused nonReentrant {
        uint256 wantBal = balanceOfWant();

        if (wantBal > 0) {
            ILendingPool(lendingPool).deposit(want, wantBal, address(this), 0);
            emit Deposit(balanceOf());
        }
    }

    function withdraw(uint256 amount) public override nonReentrant {
        require(msg.sender == vault, 'StrategyGeist: !vault');
        require(amount > 0, 'StrategyGeist: !amount');

        uint256 wantBal = balanceOfWant();

        if (wantBal < amount) {
            ILendingPool(lendingPool).withdraw(want, amount.sub(wantBal), address(this));
            uint256 newWantBal = IERC20(want).balanceOf(address(this));
            require(newWantBal > wantBal, 'StrategyGeist: !newWantBal');
            wantBal = newWantBal;
        }

        uint256 withdrawAmt = amount < wantBal ? amount : wantBal;

        uint256 fee = chargeWithdrawalFee(withdrawAmt);
        if (withdrawAmt > fee) {
            TransferHelper.safeTransfer(want, vault, withdrawAmt.sub(fee));
        }
        emit Withdraw(balanceOf());
    }

    function userReserves() public view returns (uint256, uint256) {
        (uint256 supplyBal, , uint256 borrowBal, , , , , , ) = IDataProvider(dataProvider).getUserReserveData(
            want,
            address(this)
        );
        return (supplyBal, borrowBal);
    }

    function balanceOfPool() public view override returns (uint256) {
        (uint256 supplyBal, uint256 borrowBal) = userReserves();
        return supplyBal.sub(borrowBal);
    }

    /* ----- Internal Functions ----- */

    function _giveAllowances() internal override {
        TransferHelper.safeApprove(want, lendingPool, uint256(-1));

        TransferHelper.safeApprove(reward, uniRouter, uint256(-1));
        for (uint256 i; i < rewards.length; i++) {
            TransferHelper.safeApprove(rewards[i].token, uniRouter, uint256(-1));
        }
    }

    function _removeAllowances() internal override {
        TransferHelper.safeApprove(want, lendingPool, 0);

        TransferHelper.safeApprove(reward, uniRouter, 0);
        for (uint256 i; i < rewards.length; i++) {
            TransferHelper.safeApprove(rewards[i].token, uniRouter, 0);
        }
    }

    /* ----- Private Functions ----- */

    function _swapRewards(uint256 reserveWantGTokenBal) private {
        // reward to wNative
        uint256 rewardBal = IERC20(reward).balanceOf(address(this));
        IUniswapRouter(uniRouter).swapExactTokensForTokens(rewardBal, 0, rewardToWNativeRoute, address(this), now);

        for (uint256 i; i < rewards.length; i++) {
            uint256 gTokenToWithdraw = IERC20(rewards[i].gToken).balanceOf(address(this));

            // if reward is wantToken, we have to substrate the reserved gToken balance.
            if (rewards[i].gToken == wantToken.gToken) {
                gTokenToWithdraw = gTokenToWithdraw.sub(reserveWantGTokenBal);
            }

            if (gTokenToWithdraw > 0) {
                // gToken to the underlying asset
                ILendingPool(lendingPool).withdraw(rewards[i].token, gTokenToWithdraw, address(this));

                if (rewards[i].token != wNative && rewards[i].token != wantToken.token) {
                    uint256 tokenToSwap = IERC20(rewards[i].token).balanceOf(address(this));
                    IUniswapRouter(uniRouter).swapExactTokensForTokens(
                        tokenToSwap,
                        0,
                        extraRewardToWNativeRoutes[i],
                        address(this),
                        now
                    );
                }
            }
        }

        uint256 wNativeBal = IERC20(wNative).balanceOf(address(this));
        if (wNative != want && wNativeBal > 0) {
            IUniswapRouter(uniRouter).swapExactTokensForTokens(wNativeBal, 0, wNativeToWantRoute, address(this), now);
        }
    }

    /* ----- Admin Functions ----- */

    function addRewardToNativeRoute(address[] memory _rewardToWNativeRoute) external onlyAdmin {
        address _token = _rewardToWNativeRoute[0];
        (address _gToken, , ) = IDataProvider(dataProvider).getReserveTokensAddresses(_token);

        rewards.push(TokenAddresses(_token, _gToken));
        extraRewardToWNativeRoutes.push(_rewardToWNativeRoute);

        TransferHelper.safeApprove(_token, uniRouter, uint256(-1));
    }

    function removeRewardToWNativeRoute() external onlyAdmin {
        IERC20(rewards[rewards.length - 1].token).safeApprove(uniRouter, 0);

        rewards.pop();
        extraRewardToWNativeRoutes.pop();
    }

    function retireStrat() external override {
        require(msg.sender == vault, 'StrategyGeist: !vault');
        ILendingPool(lendingPool).withdraw(want, type(uint256).max, address(this));
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        if (wantBal > 0) {
            TransferHelper.safeTransfer(want, vault, wantBal);
        }
    }

    function emergencyExit() external override onlyAdmin {
        ILendingPool(lendingPool).withdraw(want, type(uint256).max, address(this));
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        if (wantBal > 0) {
            TransferHelper.safeTransfer(want, vault, wantBal);
        }
    }

    receive() external payable {}
}
