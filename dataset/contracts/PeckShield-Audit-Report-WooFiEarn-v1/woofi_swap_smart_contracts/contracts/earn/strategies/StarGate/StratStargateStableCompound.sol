// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '../../../interfaces/Stargate/ILPStaking.sol';
import '../../../interfaces/Stargate/IStargateRouter.sol';
import '../../../interfaces/Stargate/IStargatePool.sol';
import '../../../interfaces/BankerJoe/IJoeRouter.sol';
import '../BaseStrategy.sol';

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
contract StratStargateStableCompound is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /* ----- State Variables ----- */

    address public wrappedEther;
    address public uniRouter;

    // DepositPool list:
    // usdc.e pool helper: 0x257D69AA678e0A8DA6DFDA6A16CdF2052A460b45
    IStargateRouter public router;

    uint256 public stakingPid;

    uint8 public balanceSafeRate = 5;

    IStargatePool public pool;

    // Stake LP token to earn $STG
    // BNB chain: https://bscscan.com/address/0x3052a0f6ab15b4ae1df39962d5ddefaca86dab47#code
    ILPStaking public staking;

    address public wantLPToken; // S*BUSD:  deposit busd into pool to get S*BUSD LP token, then further stakes this LP token into LPRouter to get $STG reward

    address public reward; // STG

    address[] public rewardToWantRoute;

    uint256 public lastHarvest;

    uint16 public dstChainId;
    uint256 public srcPoolId;
    uint256 public dstPoolId;
    bool public instantRedeemOnly = true;

    /* ----- Events ----- */

    event StratHarvest(address indexed harvester, uint256 wantHarvested, uint256 tvl);
    event Deposit(uint256 tvl);
    event Withdraw(uint256 tvl);

    constructor(
        address _vault,
        address _accessManager,
        address _uniRouter, // swap router
        address _pool, // pool
        address _staking, // lp staking - Masterchef
        uint256 _stakingPid, // _pid for staking
        address _reward, // $stg
        address[] memory _rewardToWantRoute // $stg -> xxx -> want
    ) public BaseStrategy(_vault, _accessManager) {
        wrappedEther = IVaultV2(_vault).weth();
        uniRouter = _uniRouter;
        pool = IStargatePool(_pool);
        wantLPToken = _pool; // NOTE: pool is LPErc20Token for staking
        router = IStargateRouter(IStargatePool(_pool).router());
        staking = ILPStaking(_staking);
        stakingPid = _stakingPid;
        reward = _reward;
        rewardToWantRoute = _rewardToWantRoute;

        require(pool.token() == want, 'StratStargateStableCompound: !pool_token');

        require(
            rewardToWantRoute.length > 0 &&
                rewardToWantRoute[0] == reward &&
                rewardToWantRoute[rewardToWantRoute.length - 1] == want,
            'StratStargateStableCompound: !route'
        );

        _giveAllowances();
    }

    /* ----- External Functions ----- */

    function rewardToWant() external view returns (address[] memory) {
        return rewardToWantRoute;
    }

    /* ----- Public Functions ----- */

    function harvest() public override whenNotPaused {
        require(msg.sender == tx.origin || msg.sender == address(vault), 'StratStargateStableCompound: EOA_or_vault');

        // NOTE: pool's local available balance
        if (IERC20(want).balanceOf(address(pool)) < balanceOfPool().mul(balanceSafeRate)) {
            _withdrawAll();
            pause();
            return;
        }

        uint256 beforeBal = balanceOfWant();

        staking.deposit(stakingPid, 0); // harvest STG token

        uint256 rewardBal = IERC20(reward).balanceOf(address(this));
        if (rewardBal > 0 && reward != want) {
            IJoeRouter(uniRouter).swapExactTokensForTokens(rewardBal, 0, rewardToWantRoute, address(this), now);
        }

        uint256 wantHarvested = balanceOfWant().sub(beforeBal);
        uint256 fee = chargePerformanceFee(wantHarvested);
        deposit();

        lastHarvest = block.timestamp;
        emit StratHarvest(msg.sender, wantHarvested.sub(fee), balanceOf());
    }

    function deposit() public override whenNotPaused nonReentrant {
        uint256 wantBal = balanceOfWant();
        if (wantBal > 0) {
            router.addLiquidity(pool.poolId(), wantBal, address(this));
            staking.deposit(stakingPid, IERC20(wantLPToken).balanceOf(address(this)));
            emit Deposit(balanceOf());
        }
    }

    function withdraw(uint256 amount) public override nonReentrant {
        require(msg.sender == vault, 'StratStargateStableCompound: !vault');
        require(amount > 0, 'StratStargateStableCompound: !amount');

        uint256 wantBal = balanceOfWant();

        if (wantBal < amount) {
            // local amount usd converted to LP token amount
            uint256 lptokenAmountToWithdraw = _amountLDtoLP(amount.sub(wantBal));

            // lp token unstaked from LPStaking, and then parked here in this strat
            staking.withdraw(stakingPid, lptokenAmountToWithdraw);

            // redeem all the want LP tokens out
            _redeemLocalWantLP();

            uint256 newWantBal = IERC20(want).balanceOf(address(this));
            require(newWantBal > wantBal, 'StratStargateStableCompound: !newWantBal');
            wantBal = newWantBal;
        }

        require(wantBal >= amount.mul(9999).div(10000), 'StratStargateStableCompound: !withdraw');
        uint256 withdrawAmt = amount < wantBal ? amount : wantBal;
        uint256 fee = chargeWithdrawalFee(withdrawAmt);
        if (withdrawAmt > fee) {
            TransferHelper.safeTransfer(want, vault, withdrawAmt.sub(fee));
        }

        emit Withdraw(balanceOf());
    }

    function _redeemLocalWantLP() internal {
        address thisAddr = address(this);
        uint256 lpAmount = IERC20(wantLPToken).balanceOf(thisAddr);

        if (instantRedeemOnly) {
            router.instantRedeemLocal(uint16(pool.poolId()), lpAmount, thisAddr);
            return;
        }

        uint256 capLpAmount = _amountSDtoLP(pool.deltaCredit());
        // check the redeemed amount with the capped local instant redeem amount
        if (lpAmount <= capLpAmount) {
            // NOTE: this means capable of local instant redemption
            router.instantRedeemLocal(uint16(pool.poolId()), lpAmount, thisAddr);
        } else {
            bytes memory to = abi.encodePacked(thisAddr);
            router.redeemLocal(
                dstChainId,
                srcPoolId,
                dstPoolId,
                payable(thisAddr),
                lpAmount,
                to,
                IStargateRouter.lzTxObj(0, 0, to)
            );
        }
    }

    function balanceOfPool() public view override returns (uint256) {
        (uint256 lpAmount, ) = staking.userInfo(stakingPid, address(this));
        return _amountLPtoLD(lpAmount); // lp token amount -> usd local decimal amount
    }

    function maxInstantRedeemLpAmount() public view returns (uint256) {
        return _amountSDtoLP(pool.deltaCredit());
    }

    function canInstantRedeemLocalNow() external view returns (bool) {
        (uint256 lpStakeAmount, ) = staking.userInfo(stakingPid, address(this));
        uint256 capLpAmount = maxInstantRedeemLpAmount();
        return lpStakeAmount <= capLpAmount;
    }

    /* ----- Internal Functions ----- */

    // NOTE: convert from LD (local decimal) to LP token.
    // Follows the logic here: https://bscscan.com/address/0x98a5737749490856b401db5dc27f522fc314a4e1#code
    function _amountLDtoLP(uint256 _amountLD) internal view returns (uint256 amountLP) {
        uint256 totalLiquidity = pool.totalLiquidity();
        uint256 totalSupply = pool.totalSupply();
        require(totalLiquidity > 0, 'Stargate: totalLiquidity_ZERO');
        uint256 amountSD = _amountLD.div(pool.convertRate());
        amountLP = amountSD.mul(totalSupply).div(totalLiquidity); // amountSD / (totalLiquidity / totalSupply)
    }

    function _amountLPtoLD(uint256 _amountLP) internal view returns (uint256 amountLD) {
        uint256 totalLiquidity = pool.totalLiquidity();
        uint256 totalSupply = pool.totalSupply();
        require(totalLiquidity > 0, 'Stargate: cant convert LPtoSD when totalSupply == 0');
        uint256 amountSD = _amountLP.mul(totalLiquidity).div(totalSupply);
        amountLD = amountSD.mul(pool.convertRate());
    }

    function _amountSDtoLP(uint256 _amountSD) internal view returns (uint256) {
        uint256 totalLiquidity = pool.totalLiquidity();
        uint256 totalSupply = pool.totalSupply();
        require(totalLiquidity > 0, 'Stargate: cant convert SDtoLP when totalLiq == 0');
        return _amountSD.mul(totalSupply).div(totalLiquidity);
    }

    function _amountLDtoSD(uint256 _amountLD) internal view returns (uint256 amountSD) {
        amountSD = _amountLD.div(pool.convertRate());
    }

    function _amountSDtoLD(uint256 _amountSD) internal view returns (uint256 amountLD) {
        amountLD = _amountSD.mul(pool.convertRate());
    }

    function _giveAllowances() internal override {
        TransferHelper.safeApprove(want, address(router), 0);
        TransferHelper.safeApprove(want, address(router), uint256(-1));
        TransferHelper.safeApprove(wantLPToken, address(staking), 0);
        TransferHelper.safeApprove(wantLPToken, address(staking), uint256(-1));
        TransferHelper.safeApprove(reward, uniRouter, 0);
        TransferHelper.safeApprove(reward, uniRouter, uint256(-1));
    }

    function _removeAllowances() internal override {
        TransferHelper.safeApprove(want, address(router), 0);
        TransferHelper.safeApprove(wantLPToken, address(staking), 0);
        TransferHelper.safeApprove(reward, uniRouter, 0);
    }

    function _withdrawAll() internal {
        (uint256 lpStakeAmount, ) = staking.userInfo(stakingPid, address(this));
        if (lpStakeAmount > 0) {
            // unstake the LP token from LPStaking to this strat
            staking.withdraw(stakingPid, lpStakeAmount);
            // redeem out all the LP tokens
            _redeemLocalWantLP();
        }
        emit Withdraw(balanceOf());
    }

    /* ----- Admin Functions ----- */

    function setRedeemParams(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId
    ) external onlyAdmin {
        dstChainId = _dstChainId;
        srcPoolId = _srcPoolId;
        dstPoolId = _dstPoolId;
    }

    function setInstantRedeemOnly(bool _instantRedeemOnly) external onlyAdmin {
        instantRedeemOnly = _instantRedeemOnly;
    }

    function setBalanceSafeRate(uint8 _balanceSafeRate) external onlyAdmin {
        balanceSafeRate = _balanceSafeRate;
    }

    function setRewardToWantRoute(address[] calldata _rewardToWantRoute) external onlyAdmin {
        rewardToWantRoute = _rewardToWantRoute;
    }

    function setUniRouter(address _uniRouter) external onlyAdmin {
        uniRouter = _uniRouter;
    }

    function retireStrat() external override {
        require(msg.sender == vault, 'StratStargateStableCompound: !vault');
        // call harvest explicitly if needed
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

    function emergencyExit1(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        bytes calldata _to,
        IStargateRouter.lzTxObj memory _lzTxParams
    ) external onlyAdmin {
        (uint256 lpStakeAmount, ) = staking.userInfo(stakingPid, address(this));
        staking.withdraw(stakingPid, lpStakeAmount);
        uint256 wantLPAmount = IERC20(wantLPToken).balanceOf(address(this));
        router.redeemLocal(
            _dstChainId, // dstChainId
            _srcPoolId, // srcPoolId
            _dstPoolId, // dstPoolId
            payable(vault), // refund address
            wantLPAmount, // lp token amount
            _to,
            _lzTxParams
        );
    }

    function emergencyExit2(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        bytes calldata _to,
        IStargateRouter.lzTxObj memory _lzTxParams
    ) external onlyAdmin {
        (uint256 lpStakeAmount, ) = staking.userInfo(stakingPid, address(this));
        staking.withdraw(stakingPid, lpStakeAmount);
        uint256 wantLPAmount = IERC20(wantLPToken).balanceOf(address(this));
        router.redeemLocal(
            _dstChainId, // dstChainId
            _srcPoolId, // srcPoolId
            _dstPoolId, // dstPoolId
            payable(address(this)), // refund address
            wantLPAmount, // lp amount
            _to,
            _lzTxParams
        );
        TransferHelper.safeTransfer(want, vault, IERC20(want).balanceOf(address(this)));
    }

    receive() external payable {}
}
