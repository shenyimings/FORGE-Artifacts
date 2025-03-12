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
import '../../../interfaces/Scream/IVToken.sol';
import '../../../interfaces/Scream/IComptroller.sol';
import '../../../interfaces/IWooAccessManager.sol';
import '../../../interfaces/IWETH.sol';
import '../BaseStrategy.sol';

contract StrategyScream is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /* ----- State Variables ----- */

    // scFUSDT: https://ftmscan.com/address/0x02224765bc8d54c21bb51b0951c80315e1c263f9
    address public iToken;
    address[] public rewardToWantRoute;
    uint256 public lastHarvest;
    uint256 public supplyBal;

    /* ----- Constant Variables ----- */

    address public constant wrappedEther = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83); // WFTM
    address public constant reward = address(0xe0654C8e6fd4D733349ac7E09f6f23DA256bF475); // SCREAM
    address public constant uniRouter = address(0xF491e7B69E4244ad4002BC14e878a34207E38c29); // SpookySwapRouter
    address public constant comptroller = address(0x260E596DAbE3AFc463e75B6CC05d8c46aCAcFB09); // Unitroller that implement Comptroller

    /* ----- Events ----- */

    event StratHarvest(address indexed harvester, uint256 wantHarvested, uint256 tvl);
    event Deposit(uint256 tvl);
    event Withdraw(uint256 tvl);

    constructor(
        address _vault,
        address _accessManager,
        address _iToken,
        address[] memory _rewardToWantRoute
    ) public BaseStrategy(_vault, _accessManager) {
        iToken = _iToken;
        rewardToWantRoute = _rewardToWantRoute;

        _giveAllowances();
    }

    /* ----- External Functions ----- */

    function beforeDeposit() public override {
        super.beforeDeposit();
        updateSupplyBal();
    }

    function rewardToWant() external view returns (address[] memory) {
        return rewardToWantRoute;
    }

    /* ----- Public Functions ----- */

    function harvest() public override whenNotPaused {
        require(msg.sender == tx.origin || msg.sender == address(vault), 'StrategyScream: EOA_or_vault');

        // When pendingImplementation not zero address, means there is a new implement ready to replace.
        if (IComptroller(comptroller).pendingComptrollerImplementation() == address(0)) {
            uint256 beforeBal = balanceOfWant();

            _harvestAndSwap(rewardToWantRoute);

            uint256 wantHarvested = balanceOfWant().sub(beforeBal);
            uint256 fee = chargePerformanceFee(wantHarvested);
            deposit();

            lastHarvest = block.timestamp;
            emit StratHarvest(msg.sender, wantHarvested.sub(fee), balanceOf());
        } else {
            _withdrawAll();
            pause();
        }
    }

    function deposit() public override whenNotPaused nonReentrant {
        uint256 wantBal = balanceOfWant();

        if (wantBal > 0) {
            IVToken(iToken).mint(wantBal);
            updateSupplyBal();
            emit Deposit(balanceOf());
        }
    }

    function withdraw(uint256 amount) public override nonReentrant {
        require(msg.sender == vault, 'StrategyScream: !vault');
        require(amount > 0, 'StrategyScream: !amount');

        uint256 wantBal = balanceOfWant();

        if (wantBal < amount) {
            IVToken(iToken).redeemUnderlying(amount.sub(wantBal));
            updateSupplyBal();
            uint256 newWantBal = IERC20(want).balanceOf(address(this));
            require(newWantBal > wantBal, 'StrategyScream: !newWantBal');
            wantBal = newWantBal;
        }

        uint256 withdrawAmt = amount < wantBal ? amount : wantBal;

        uint256 fee = chargeWithdrawalFee(withdrawAmt);
        if (withdrawAmt > fee) {
            TransferHelper.safeTransfer(want, vault, withdrawAmt.sub(fee));
        }
        emit Withdraw(balanceOf());
    }

    function updateSupplyBal() public {
        supplyBal = IVToken(iToken).balanceOfUnderlying(address(this));
    }

    function balanceOfPool() public view override returns (uint256) {
        return supplyBal;
    }

    /* ----- Internal Functions ----- */

    function _giveAllowances() internal override {
        TransferHelper.safeApprove(want, iToken, 0);
        TransferHelper.safeApprove(want, iToken, uint256(-1));
        TransferHelper.safeApprove(reward, uniRouter, 0);
        TransferHelper.safeApprove(reward, uniRouter, uint256(-1));
        TransferHelper.safeApprove(wrappedEther, uniRouter, 0);
        TransferHelper.safeApprove(wrappedEther, uniRouter, uint256(-1));
    }

    function _removeAllowances() internal override {
        TransferHelper.safeApprove(want, iToken, 0);
        TransferHelper.safeApprove(reward, uniRouter, 0);
        TransferHelper.safeApprove(wrappedEther, uniRouter, 0);
    }

    function _withdrawAll() internal {
        uint256 iTokenBal = IERC20(iToken).balanceOf(address(this));
        if (iTokenBal > 0) {
            IVToken(iToken).redeem(iTokenBal);
        }
        updateSupplyBal();
    }

    /* ----- Private Functions ----- */

    function _harvestAndSwap(address[] memory _route) private {
        address[] memory markets = new address[](1);
        markets[0] = iToken;
        IComptroller(comptroller).claimComp(address(this), markets);

        // in case of reward token is native token (ETH/BNB/AVAX/FTM)
        uint256 toWrapBal = address(this).balance;
        if (toWrapBal > 0) {
            IWETH(wrappedEther).deposit{value: toWrapBal}();
        }

        uint256 rewardBal = IERC20(reward).balanceOf(address(this));

        // rewardBal == 0: means the current token reward ended
        // reward == want: no need to swap
        if (rewardBal > 0 && reward != want) {
            require(_route.length > 0, 'StrategyScream: SWAP_ROUTE_INVALID');
            IUniswapRouter(uniRouter).swapExactTokensForTokens(rewardBal, 0, _route, address(this), now);
        }
    }

    /* ----- Admin Functions ----- */

    function retireStrat() external override {
        require(msg.sender == vault, 'StrategyScream: !vault');
        _withdrawAll();
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        if (wantBal > 0) {
            TransferHelper.safeTransfer(want, vault, wantBal);
        }
    }

    function emergencyExit() external override onlyAdmin {
        _withdrawAll();
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        if (wantBal > 0) {
            TransferHelper.safeTransfer(want, vault, wantBal);
        }
    }

    receive() external payable {}
}
