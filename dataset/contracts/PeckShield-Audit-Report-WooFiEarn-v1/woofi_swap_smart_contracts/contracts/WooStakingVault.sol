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
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import './libraries/DecimalMath.sol';
import './interfaces/IWooAccessManager.sol';

contract WooStakingVault is ERC20, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using DecimalMath for uint256;

    struct UserInfo {
        uint256 reserveAmount; // amount of stakedToken user reverseWithdraw
        uint256 lastReserveWithdrawTime; // keeps track of reverseWithdraw time for potential penalty
    }

    /* ----- Events ----- */

    event Deposit(address indexed user, uint256 depositAmount, uint256 mintShares);
    event ReserveWithdraw(address indexed user, uint256 reserveAmount, uint256 burnShares);
    event Withdraw(address indexed user, uint256 withdrawAmount, uint256 withdrawFee);
    event InstantWithdraw(address indexed user, uint256 withdrawAmount, uint256 withdrawFee);
    event RewardAdded(
        address indexed sender,
        uint256 balanceBefore,
        uint256 sharePriceBefore,
        uint256 balanceAfter,
        uint256 sharePriceAfter
    );

    /* ----- State variables ----- */

    IERC20 public immutable stakedToken;
    mapping(address => uint256) public costSharePrice;
    mapping(address => UserInfo) public userInfo;

    uint256 public totalReserveAmount = 0; // affected by reserveWithdraw and withdraw
    uint256 public withdrawFeePeriod = 7 days;
    uint256 public withdrawFee = 500; // 5% (10000 as denominator)

    address public treasury;
    IWooAccessManager public wooAccessManager;

    /* ----- Constant variables ----- */

    uint256 public constant MAX_WITHDRAW_FEE_PERIOD = 7 days;
    uint256 public constant MAX_WITHDRAW_FEE = 500; // 5% (10000 as denominator)

    constructor(
        address initialStakedToken,
        address initialTreasury,
        address initialWooAccessManager
    )
        public
        ERC20(
            string(abi.encodePacked('Interest Bearing ', ERC20(initialStakedToken).name())),
            string(abi.encodePacked('x', ERC20(initialStakedToken).symbol()))
        )
    {
        require(initialStakedToken != address(0), 'WooStakingVault: initialStakedToken_ZERO_ADDR');
        require(initialTreasury != address(0), 'WooStakingVault: initialTreasury_ZERO_ADDR');
        require(initialWooAccessManager != address(0), 'WooStakingVault: initialWooAccessManager_ZERO_ADDR');

        stakedToken = IERC20(initialStakedToken);
        treasury = initialTreasury;
        wooAccessManager = IWooAccessManager(initialWooAccessManager);
    }

    /* ----- External Functions ----- */

    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, 'WooStakingVault: amount_CAN_NOT_BE_ZERO');

        uint256 balanceBefore = balance();
        TransferHelper.safeTransferFrom(address(stakedToken), msg.sender, address(this), amount);
        uint256 balanceAfter = balance();
        amount = balanceAfter.sub(balanceBefore);

        uint256 xTotalSupply = totalSupply();
        uint256 shares = xTotalSupply == 0 ? amount : amount.mul(xTotalSupply).div(balanceBefore);

        // must be executed before _mint
        _updateCostSharePrice(amount, shares);

        _mint(msg.sender, shares);

        emit Deposit(msg.sender, amount, shares);
    }

    function reserveWithdraw(uint256 shares) external nonReentrant {
        require(shares > 0, 'WooStakingVault: shares_CAN_NOT_BE_ZERO');
        require(shares <= balanceOf(msg.sender), 'WooStakingVault: shares exceed balance');

        uint256 currentReserveAmount = shares.mulFloor(getPricePerFullShare()); // calculate reserveAmount before _burn
        uint256 poolBalance = balance();
        if (poolBalance < currentReserveAmount) {
            // in case reserve amount exceeds pool balance
            currentReserveAmount = poolBalance;
        }
        _burn(msg.sender, shares);

        totalReserveAmount = totalReserveAmount.add(currentReserveAmount);

        UserInfo storage user = userInfo[msg.sender];
        user.reserveAmount = user.reserveAmount.add(currentReserveAmount);
        user.lastReserveWithdrawTime = block.timestamp;

        emit ReserveWithdraw(msg.sender, currentReserveAmount, shares);
    }

    function withdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        uint256 withdrawAmount = user.reserveAmount;
        require(withdrawAmount > 0, 'WooStakingVault: withdrawAmount_CAN_NOT_BE_ZERO');

        uint256 fee = 0;
        if (block.timestamp < user.lastReserveWithdrawTime.add(withdrawFeePeriod)) {
            fee = withdrawAmount.mul(withdrawFee).div(10000);
            if (fee > 0) {
                TransferHelper.safeTransfer(address(stakedToken), treasury, fee);
            }
        }
        uint256 withdrawAmountAfterFee = withdrawAmount.sub(fee);

        user.reserveAmount = 0;
        totalReserveAmount = totalReserveAmount.sub(withdrawAmount);
        TransferHelper.safeTransfer(address(stakedToken), msg.sender, withdrawAmountAfterFee);

        emit Withdraw(msg.sender, withdrawAmount, fee);
    }

    function instantWithdraw(uint256 shares) external nonReentrant {
        require(shares > 0, 'WooStakingVault: shares_CAN_NOT_BE_ZERO');
        require(shares <= balanceOf(msg.sender), 'WooStakingVault: shares exceed balance');

        uint256 withdrawAmount = shares.mulFloor(getPricePerFullShare());

        uint256 poolBalance = balance();
        if (poolBalance < withdrawAmount) {
            withdrawAmount = poolBalance;
        }

        _burn(msg.sender, shares);

        uint256 fee = wooAccessManager.isZeroFeeVault(msg.sender) ? 0 : withdrawAmount.mul(withdrawFee).div(10000);
        if (fee > 0) {
            TransferHelper.safeTransfer(address(stakedToken), treasury, fee);
        }
        uint256 withdrawAmountAfterFee = withdrawAmount.sub(fee);

        TransferHelper.safeTransfer(address(stakedToken), msg.sender, withdrawAmountAfterFee);

        emit InstantWithdraw(msg.sender, withdrawAmount, fee);
    }

    function addReward(uint256 amount) external whenNotPaused {
        // Note: this method is only for adding Woo reward. Users may not call this method to deposit woo token.
        require(amount > 0, 'WooStakingVault: amount_CAN_NOT_BE_ZERO');
        uint256 balanceBefore = balance();
        uint256 sharePriceBefore = getPricePerFullShare();
        TransferHelper.safeTransferFrom(address(stakedToken), msg.sender, address(this), amount);
        uint256 balanceAfter = balance();
        uint256 sharePriceAfter = getPricePerFullShare();

        emit RewardAdded(msg.sender, balanceBefore, sharePriceBefore, balanceAfter, sharePriceAfter);
    }

    /* ----- Public Functions ----- */

    function getPricePerFullShare() public view returns (uint256) {
        if (totalSupply() == 0) {
            return 1e18;
        }
        return balance().divFloor(totalSupply());
    }

    function balance() public view returns (uint256) {
        return stakedToken.balanceOf(address(this)).sub(totalReserveAmount);
    }

    /* ----- Private Functions ----- */

    function _updateCostSharePrice(uint256 amount, uint256 shares) private {
        uint256 sharesBefore = balanceOf(msg.sender);
        uint256 costBefore = costSharePrice[msg.sender];
        uint256 costAfter = (sharesBefore.mul(costBefore).add(amount.mul(1e18))).div(sharesBefore.add(shares));

        costSharePrice[msg.sender] = costAfter;
    }

    /* ----- Admin Functions ----- */

    /// @notice Sets withdraw fee period
    /// @dev Only callable by the contract owner.
    function setWithdrawFeePeriod(uint256 newWithdrawFeePeriod) external onlyOwner {
        require(
            newWithdrawFeePeriod <= MAX_WITHDRAW_FEE_PERIOD,
            'WooStakingVault: newWithdrawFeePeriod>MAX_WITHDRAW_FEE_PERIOD'
        );
        withdrawFeePeriod = newWithdrawFeePeriod;
    }

    /// @notice Sets withdraw fee
    /// @dev Only callable by the contract owner.
    function setWithdrawFee(uint256 newWithdrawFee) external onlyOwner {
        require(newWithdrawFee <= MAX_WITHDRAW_FEE, 'WooStakingVault: newWithdrawFee>MAX_WITHDRAW_FEE');
        withdrawFee = newWithdrawFee;
    }

    /// @notice Sets treasury address
    /// @dev Only callable by the contract owner.
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), 'WooStakingVault: newTreasury_ZERO_ADDR');
        treasury = newTreasury;
    }

    /// @notice Sets WooAccessManager
    /// @dev Only callable by the contract owner.
    function setWooAccessManager(address newWooAccessManager) external onlyOwner {
        require(newWooAccessManager != address(0), 'WooStakingVault: newWooAccessManager_ZERO_ADDR');
        wooAccessManager = IWooAccessManager(newWooAccessManager);
    }

    /**
        @notice Rescues random funds stuck.
        This method only saves the irrelevant tokens just in case users deposited in mistake.
        It cannot transfer any of user staked tokens.
    */
    function inCaseTokensGetStuck(address stuckToken) external onlyOwner {
        require(stuckToken != address(0), 'WooStakingVault: stuckToken_ZERO_ADDR');
        require(stuckToken != address(stakedToken), 'WooStakingVault: stuckToken_CAN_NOT_BE_stakedToken');

        uint256 amount = IERC20(stuckToken).balanceOf(address(this));
        TransferHelper.safeTransfer(stuckToken, msg.sender, amount);
    }

    /// @notice Pause the contract.
    function pause() external onlyOwner {
        super._pause();
    }

    /// @notice Restart the contract.
    function unpause() external onlyOwner {
        super._unpause();
    }
}
