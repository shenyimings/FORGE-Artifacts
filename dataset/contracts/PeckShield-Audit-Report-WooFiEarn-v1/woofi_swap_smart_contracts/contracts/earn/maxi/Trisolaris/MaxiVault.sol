// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

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
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol';

import '../BaseMaxiVault.sol';

import '../../../interfaces/Trisolaris/IMasterChef.sol';
import '../../../interfaces/Trisolaris/ITriBar.sol';

contract WOOFiMaxiVaultTrisolaris is ERC20Upgradeable, BaseMaxiVault {
    using SafeMathUpgradeable for uint256;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many deposit tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of reward tokens
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accRewardPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws deposit tokens to a pool. Here's what happens:
        //   1. The pool's `accRewardPerShare` gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    /* ----- Mapping ----- */

    mapping(address => UserInfo) public userInfo;

    /* ----- State Variables ----- */

    uint256 public pid;
    uint256 public accRewardPerShare;

    // Contract Address
    address public masterChef; // LP Farm
    address public rewardBar; // TriBar

    /* ----- Event ----- */

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);
    event Harvest(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 depositAmount, uint256 rewardAmount);

    /* ----- Initializer ----- */

    function initialize(
        uint256 _pid,
        address _masterChef,
        address _rewardBar,
        address _depositToken,
        address _rewardToken,
        address _wooAccessManager
    ) external initializer {
        require(_masterChef != address(0), 'WOOFiMaximizerVault: _masterChef_ZERO_ADDRESS');
        require(_rewardBar != address(0), 'WOOFiMaximizerVault: _rewardBar_ZERO_ADDRESS');
        require(_depositToken != address(0), 'WOOFiMaximizerVault: _depositToken_ZERO_ADDRESS');
        require(_rewardToken != address(0), 'WOOFiMaximizerVault: _rewardToken_ZERO_ADDRESS');
        require(_wooAccessManager != address(0), 'WOOFiMaximizerVault: _wooAccessManager_ZERO_ADDRESS');

        __BaseMaxiVault_init(_wooAccessManager);
        __ERC20_init(
            string(abi.encodePacked('WOOFi Earn Maxi ', ERC20Upgradeable(_depositToken).name())),
            string(abi.encodePacked('wem', ERC20Upgradeable(_depositToken).symbol()))
        );

        pid = _pid;
        masterChef = _masterChef;
        rewardBar = _rewardBar;
        depositToken = _depositToken; // LP Token
        rewardToken = _rewardToken; // TRI

        _giveAllowances();
    }

    /* ----- Modifier ----- */

    modifier fairUpdate() {
        harvest(); // only way to update accRewardPerShare
        _;
    }

    /* ----- External Functions ----- */

    function pendingReward(address _user) external view returns (uint256) {
        uint256 pendingInMasterChef = IMasterChef(masterChef).pendingTri(pid, address(this));
        uint256 calAccRewardPerShare = balance() > 0
            ? accRewardPerShare.add(pendingInMasterChef.mul(1e12).div(balance()))
            : accRewardPerShare;
        UserInfo memory user = userInfo[_user];
        return user.amount.mul(calAccRewardPerShare).div(1e12).sub(user.rewardDebt);
    }

    function depositAll() external override {
        deposit(IERC20(depositToken).balanceOf(msg.sender));
    }

    function withdrawAll() external override {
        withdraw(IERC20(address(this)).balanceOf(msg.sender));
    }

    /* ----- Public Functions ----- */

    function deposit(uint256 _amount) public override nonReentrant notPaused fairUpdate {
        require(_amount > 0, 'WOOFiMaxiVault: _amount_ZERO');

        UserInfo storage user = userInfo[msg.sender];
        uint256 pendingRewards = user.amount.mul(accRewardPerShare).div(1e12).sub(user.rewardDebt);
        TransferHelper.safeTransferFrom(depositToken, msg.sender, address(this), _amount);
        IMasterChef(masterChef).deposit(pid, _amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(accRewardPerShare).div(1e12).sub(pendingRewards);
        _mint(msg.sender, _amount);
        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public override nonReentrant notPaused fairUpdate {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, 'WOOFiMaxiVault: _amount_EXCEEDS_USER_BALANCE');

        IMasterChef(masterChef).withdraw(pid, _amount);
        _claimReward(); // update user.rewardDebt
        user.amount = user.amount.sub(_amount);
        uint256 fee = _chargeWithdrawalFee(depositToken, _amount);

        _burn(msg.sender, _amount);
        TransferHelper.safeTransfer(depositToken, msg.sender, _amount.sub(fee));
        emit Withdraw(msg.sender, _amount.sub(fee));
    }

    function claimReward() public nonReentrant notPaused fairUpdate {
        _claimReward();
    }

    function harvest() public override notPaused {
        uint256 rewardBalBefore = IERC20(rewardToken).balanceOf(address(this));
        IMasterChef(masterChef).harvest(pid);
        uint256 rewardBalAfter = IERC20(rewardToken).balanceOf(address(this));

        if (rewardBalAfter == rewardBalBefore) return;

        uint256 rewardsHarvested = rewardBalAfter.sub(rewardBalBefore);
        uint256 fee = _chargePerformanceFee(rewardToken, rewardsHarvested);

        accRewardPerShare = balanceOfReward().mul(1e12).div(balance());
        ITriBar(rewardBar).enter(IERC20(rewardToken).balanceOf(address(this)));

        emit Harvest(msg.sender, rewardsHarvested.sub(fee));
    }

    function balance() public view returns (uint256) {
        (uint256 amount, ) = IMasterChef(masterChef).userInfo(pid, address(this));
        return amount;
    }

    function balanceOfReward() public view returns (uint256) {
        uint256 shares = IERC20(rewardBar).balanceOf(address(this));
        uint256 barSharePrice = getBarPricePerFullShare();

        return IERC20(rewardToken).balanceOf(address(this)).add(shares.mul(barSharePrice).div(1e18));
    }

    function getBarPricePerFullShare() public view returns (uint256) {
        uint256 rewardBarBal = IERC20(rewardToken).balanceOf(rewardBar); // TRI balance in TriBar
        uint256 rewardBarShares = IERC20(rewardBar).totalSupply(); // xTri total supply

        return rewardBarShares == 0 ? 1e18 : rewardBarBal.mul(1e18).div(rewardBarShares);
    }

    /* ----- Internal Functions ----- */

    function _giveAllowances() internal override {
        TransferHelper.safeApprove(depositToken, masterChef, uint256(-1));
        TransferHelper.safeApprove(rewardToken, rewardBar, uint256(-1));
    }

    function _removeAllowances() internal override {
        TransferHelper.safeApprove(depositToken, masterChef, 0);
        TransferHelper.safeApprove(rewardToken, rewardBar, 0);
    }

    /* ----- Private Functions ----- */

    function _claimReward() private {
        UserInfo storage user = userInfo[msg.sender];
        uint256 pendingRewards = user.amount.mul(accRewardPerShare).div(1e12).sub(user.rewardDebt);
        uint256 rewardBal = IERC20(rewardToken).balanceOf(address(this));
        if (rewardBal < pendingRewards) {
            uint256 leaveAmt = pendingRewards.sub(rewardBal);
            uint256 leaveShares = leaveAmt.mul(1e18).div(getBarPricePerFullShare());
            ITriBar(rewardBar).leave(leaveShares);

            uint256 rewardBalAfter = IERC20(rewardToken).balanceOf(address(this));
            require(rewardBalAfter > rewardBal, 'WOOFiMaxiVault: rewardBar_LEAVE_ERROR');
            rewardBal = rewardBalAfter;
        }

        uint256 claimAmt = pendingRewards < rewardBal ? pendingRewards : rewardBal;
        if (claimAmt > 0) {
            TransferHelper.safeTransfer(rewardToken, msg.sender, claimAmt);
        }

        user.rewardDebt = user.amount.mul(accRewardPerShare).div(1e12);
        emit ClaimReward(msg.sender, claimAmt);
    }

    /* ----- Admin Functions ----- */

    function emergencyExit() external override onlyAdmin {
        IMasterChef(masterChef).emergencyWithdraw(pid);
        ITriBar(rewardBar).leave(IERC20(rewardBar).balanceOf(address(this)));

        emit EmergencyWithdraw(
            msg.sender,
            IERC20(depositToken).balanceOf(address(this)),
            IERC20(rewardToken).balanceOf(address(this))
        );
    }

    function depositToPool() public override onlyAdmin {
        if (balance() > 0) harvest();
        uint256 depositBal = IERC20(depositToken).balanceOf(address(this));
        if (depositBal > 0) IMasterChef(masterChef).deposit(pid, depositBal);
    }

    function withdrawFromPool() public override onlyAdmin {
        if (balance() > 0) {
            harvest();
            IMasterChef(masterChef).withdraw(pid, balance());
        }
    }
}
