// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;
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
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/EnumerableSet.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';

import '../interfaces/IStrategy.sol';
import '../interfaces/IWETH.sol';
import '../interfaces/IWooAccessManager.sol';
import '../interfaces/IVaultV2.sol';

import './WooWithdrawManager.sol';
import './WooLendingManager.sol';

contract WooSuperChargerVault is ERC20, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event RequestWithdraw(address indexed user, uint256 assets, uint256 shares);
    event InstantWithdraw(address indexed user, uint256 assets, uint256 shares, uint256 fees);
    event WeeklySettleStarted(address indexed caller, uint256 totalRequestedShares, uint256 weeklyRepayAmount);
    event WeeklySettleEnded(
        address indexed caller,
        uint256 totalBalance,
        uint256 lendingBalance,
        uint256 reserveBalance
    );
    event ReserveVaultMigrated(address indexed user, address indexed oldVault, address indexed newVault);

    event LendingManagerUpdated(address formerLendingManager, address newLendingManager);
    event WithdrawManagerUpdated(address formerWithdrawManager, address newWithdrawManager);
    event InstantWithdrawFeeRateUpdated(uint256 formerFeeRate, uint256 newFeeRate);

    /* ----- State Variables ----- */

    address constant ETH_PLACEHOLDER_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    IVaultV2 public reserveVault;
    WooLendingManager public lendingManager;
    WooWithdrawManager public withdrawManager;

    address public immutable want;
    address public immutable weth;
    IWooAccessManager public immutable accessManager;

    mapping(address => uint256) public costSharePrice;
    mapping(address => uint256) public requestedWithdrawShares; // Requested withdrawn amount (in assets, NOT shares)
    uint256 public requestedTotalShares;
    EnumerableSet.AddressSet private requestUsers;

    uint256 public instantWithdrawCap; // Max instant withdraw amount (in assets, per week)
    uint256 public instantWithdrawnAmount; // Withdrawn amout already consumed (in assets, per week)

    bool public isSettling;

    address public treasury = 0x815D4517427Fc940A90A5653cdCEA1544c6283c9;
    uint256 public instantWithdrawFeeRate = 30; // 1 in 10000th. default: 30 -> 0.3%

    constructor(
        address _weth,
        address _want,
        address _accessManager
    )
        public
        ERC20(
            string(abi.encodePacked('WOOFi Super Charger ', ERC20(_want).name())),
            string(abi.encodePacked('we', ERC20(_want).symbol()))
        )
    {
        require(_weth != address(0), 'WooSuperChargerVault: !weth');
        require(_want != address(0), 'WooSuperChargerVault: !want');
        require(_accessManager != address(0), 'WooSuperChargerVault: !accessManager');

        weth = _weth;
        want = _want;
        accessManager = IWooAccessManager(_accessManager);
    }

    function init(
        address _reserveVault,
        address _lendingManager,
        address payable _withdrawManager
    ) external onlyOwner {
        require(_reserveVault != address(0), 'WooSuperChargerVault: !_reserveVault');
        require(_lendingManager != address(0), 'WooSuperChargerVault: !_lendingManager');
        require(_withdrawManager != address(0), 'WooSuperChargerVault: !_withdrawManager');

        reserveVault = IVaultV2(_reserveVault);
        require(reserveVault.want() == want);
        lendingManager = WooLendingManager(_lendingManager);
        withdrawManager = WooWithdrawManager(_withdrawManager);
    }

    modifier onlyAdmin() {
        require(owner() == msg.sender || accessManager.isVaultAdmin(msg.sender), 'WooSuperChargerVault: !ADMIN');
        _;
    }

    modifier onlyLendingManager() {
        require(msg.sender == address(lendingManager), 'WooSuperChargerVault: !lendingManager');
        _;
    }

    /* ----- External Functions ----- */

    function deposit(uint256 amount) external payable whenNotPaused nonReentrant {
        require(amount > 0, 'WooSuperChargerVault: !amount');

        lendingManager.accureInterest();
        uint256 shares = _shares(amount, getPricePerFullShare());

        uint256 sharesBefore = balanceOf(msg.sender);
        uint256 costBefore = costSharePrice[msg.sender];
        uint256 costAfter = (sharesBefore.mul(costBefore).add(amount.mul(1e18))).div(sharesBefore.add(shares));
        costSharePrice[msg.sender] = costAfter;

        if (want == weth) {
            require(msg.value == amount, 'WooSuperChargerVault: msg.value_INSUFFICIENT');
            reserveVault.deposit{value: msg.value}(amount);
        } else {
            TransferHelper.safeTransferFrom(want, msg.sender, address(this), amount);
            TransferHelper.safeApprove(want, address(reserveVault), amount);
            reserveVault.deposit(amount);
        }

        _mint(msg.sender, shares);

        instantWithdrawCap = instantWithdrawCap.add(amount.div(10));

        emit Deposit(msg.sender, amount, shares);
    }

    function instantWithdraw(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, 'WooSuperChargerVault: !amount');
        require(!isSettling, 'WooSuperChargerVault: NOT_ALLOWED_IN_SETTLING');

        if (instantWithdrawnAmount >= instantWithdrawCap) {
            // NOTE: no more instant withdraw quota.
            return;
        }

        require(amount <= instantWithdrawCap.sub(instantWithdrawnAmount), 'WooSuperChargerVault: OUT_OF_CAP');
        lendingManager.accureInterest();
        uint256 shares = _sharesUp(amount, getPricePerFullShare());
        _burn(msg.sender, shares);

        uint256 reserveShares = _sharesUp(amount, reserveVault.getPricePerFullShare());
        reserveVault.withdraw(reserveShares);

        uint256 fee = accessManager.isZeroFeeVault(msg.sender) ? 0 : amount.mul(instantWithdrawFeeRate).div(10000);
        if (want == weth) {
            TransferHelper.safeTransferETH(treasury, fee);
            TransferHelper.safeTransferETH(msg.sender, amount.sub(fee));
        } else {
            TransferHelper.safeTransfer(want, treasury, fee);
            TransferHelper.safeTransfer(want, msg.sender, amount.sub(fee));
        }

        instantWithdrawnAmount = instantWithdrawnAmount.add(amount);

        emit InstantWithdraw(msg.sender, amount, reserveShares, fee);
    }

    function requestWithdraw(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, 'WooSuperChargerVault: !amount');
        require(!isSettling, 'WooSuperChargerVault: CANNOT_WITHDRAW_IN_SETTLING');

        lendingManager.accureInterest();
        uint256 shares = _sharesUp(amount, getPricePerFullShare());
        TransferHelper.safeTransferFrom(address(this), msg.sender, address(this), shares);

        requestedWithdrawShares[msg.sender] = requestedWithdrawShares[msg.sender].add(shares);
        requestedTotalShares = requestedTotalShares.add(shares);
        requestUsers.add(msg.sender);

        emit RequestWithdraw(msg.sender, amount, shares);
    }

    function requestedTotalAmount() public view returns (uint256) {
        return _assets(requestedTotalShares);
    }

    function requestedWithdrawAmount(address user) public view returns (uint256) {
        return _assets(requestedWithdrawShares[user]);
    }

    function available() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function reserveBalance() public view returns (uint256) {
        return _assets(IERC20(address(reserveVault)).balanceOf(address(this)), reserveVault.getPricePerFullShare());
    }

    function lendingBalance() public view returns (uint256) {
        return lendingManager.debtAfterPerfFee();
    }

    // Returns the total balance (assets), which is avaiable + reserve + lending.
    function balance() public view returns (uint256) {
        return available().add(reserveBalance()).add(lendingBalance());
    }

    function getPricePerFullShare() public view returns (uint256) {
        return totalSupply() == 0 ? 1e18 : balance().mul(1e18).div(totalSupply());
    }

    // --- For WooLendingManager --- //

    function maxBorrowableAmount() public view returns (uint256) {
        uint256 resBal = reserveBalance();
        uint256 instWithdrawBal = instantWithdrawCap.sub(instantWithdrawnAmount);
        return resBal > instWithdrawBal ? resBal.sub(instWithdrawBal) : 0;
    }

    function borrowFromLendingManager(uint256 amount, address fundAddr) external onlyLendingManager {
        require(!isSettling, 'IN SETTLING');
        require(amount <= maxBorrowableAmount(), 'INSUFF_AMOUNT_FOR_BORROW');
        uint256 sharesToWithdraw = _sharesUp(amount, reserveVault.getPricePerFullShare());
        reserveVault.withdraw(sharesToWithdraw);
        if (want == weth) {
            IWETH(weth).deposit{value: amount}();
        }
        TransferHelper.safeTransfer(want, fundAddr, amount);
    }

    function repayFromLendingManager(uint256 amount) external onlyLendingManager {
        TransferHelper.safeTransferFrom(want, msg.sender, address(this), amount);
        if (want == weth) {
            IWETH(weth).withdraw(amount);
            reserveVault.deposit{value: amount}(amount);
        } else {
            TransferHelper.safeApprove(want, address(reserveVault), amount);
            reserveVault.deposit(amount);
        }
    }

    // --- Admin operations --- //

    function weeklyNeededAmountForWithdraw() public view returns (uint256) {
        uint256 reserveBal = reserveBalance();
        uint256 requestedAmount = requestedTotalAmount();
        uint256 afterBal = balance().sub(requestedAmount);

        return
            reserveBal >= requestedAmount.add(afterBal.div(10))
                ? 0
                : requestedAmount.add(afterBal.div(10)).sub(reserveBal);
    }

    function startWeeklySettle() external onlyAdmin {
        require(!isSettling, 'IN_SETTLING');
        isSettling = true;
        lendingManager.accureInterest();
        emit WeeklySettleStarted(msg.sender, requestedTotalShares, weeklyNeededAmountForWithdraw());
    }

    function endWeeklySettle() public onlyAdmin {
        require(isSettling, '!SETTLING');
        require(weeklyNeededAmountForWithdraw() == 0, 'WEEKLY_REPAY_NOT_CLEARED');

        uint256 sharePrice = getPricePerFullShare();

        isSettling = false;
        uint256 amount = requestedTotalAmount();

        if (amount != 0) {
            uint256 shares = _sharesUp(amount, reserveVault.getPricePerFullShare());
            reserveVault.withdraw(shares);

            if (want == weth) {
                IWETH(weth).deposit{value: amount}();
            }
            require(available() >= amount);

            TransferHelper.safeApprove(want, address(withdrawManager), amount);
            uint256 length = requestUsers.length();
            for (uint256 i = 0; i < length; i++) {
                address user = requestUsers.at(0);

                withdrawManager.addWithdrawAmount(user, requestedWithdrawShares[user].mul(sharePrice).div(1e18));

                requestedWithdrawShares[user] = 0;
                requestUsers.remove(user);
            }

            _burn(address(this), requestedTotalShares);
            requestedTotalShares = 0;
        }

        instantWithdrawnAmount = 0;

        lendingManager.accureInterest();
        uint256 totalBalance = balance();
        instantWithdrawCap = totalBalance.div(10);

        emit WeeklySettleEnded(msg.sender, totalBalance, lendingBalance(), reserveBalance());
    }

    function migrateReserveVault(address _vault) external onlyOwner {
        require(_vault != address(0), '!_vault');

        uint256 preBal = (want == weth) ? address(this).balance : available();
        reserveVault.withdraw(IERC20(address(reserveVault)).balanceOf(address(this)));
        uint256 afterBal = (want == weth) ? address(this).balance : available();
        uint256 reserveAmount = afterBal.sub(preBal);

        address oldVault = address(reserveVault);
        reserveVault = IVaultV2(_vault);
        require(reserveVault.want() == want, 'INVALID_WANT');
        if (want == weth) {
            reserveVault.deposit{value: reserveAmount}(reserveAmount);
        } else {
            TransferHelper.safeApprove(want, address(reserveVault), reserveAmount);
            reserveVault.deposit(reserveAmount);
        }

        emit ReserveVaultMigrated(msg.sender, oldVault, _vault);
    }

    function inCaseTokenGotStuck(address stuckToken) external onlyOwner {
        if (stuckToken == ETH_PLACEHOLDER_ADDR) {
            TransferHelper.safeTransferETH(msg.sender, address(this).balance);
        } else {
            uint256 amount = IERC20(stuckToken).balanceOf(address(this));
            TransferHelper.safeTransfer(stuckToken, msg.sender, amount);
        }
    }

    function setLendingManager(address _lendingManager) external onlyOwner {
        address formerManager = address(lendingManager);
        lendingManager = WooLendingManager(_lendingManager);
        emit LendingManagerUpdated(formerManager, _lendingManager);
    }

    function setWithdrawManager(address payable _withdrawManager) external onlyOwner {
        address formerManager = address(withdrawManager);
        withdrawManager = WooWithdrawManager(_withdrawManager);
        emit WithdrawManagerUpdated(formerManager, _withdrawManager);
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    function setInstantWithdrawFeeRate(uint256 _feeRate) external onlyOwner {
        uint256 formerFeeRate = instantWithdrawFeeRate;
        instantWithdrawFeeRate = _feeRate;
        emit InstantWithdrawFeeRateUpdated(formerFeeRate, _feeRate);
    }

    function pause() public onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    receive() external payable {}

    function _assets(uint256 shares) private view returns (uint256) {
        return _assets(shares, getPricePerFullShare());
    }

    function _assets(uint256 shares, uint256 sharePrice) private pure returns (uint256) {
        return shares.mul(sharePrice).div(1e18);
    }

    function _shares(uint256 assets, uint256 sharePrice) private pure returns (uint256) {
        return assets.mul(1e18).div(sharePrice);
    }

    function _sharesUp(uint256 assets, uint256 sharePrice) private pure returns (uint256) {
        uint256 shares = assets.mul(1e18).div(sharePrice);
        return _assets(shares, sharePrice) == assets ? shares : shares.add(1);
    }
}
