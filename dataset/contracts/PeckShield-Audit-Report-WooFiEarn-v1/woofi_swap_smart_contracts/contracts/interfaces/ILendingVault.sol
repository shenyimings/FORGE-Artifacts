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

/// @title WOOFi LendingVault interface.
interface ILendingVault {
    // ************** //
    // *** EVENTS *** //
    // ************** //

    event Deposit(address indexed user, uint256 assets, uint256 shares);

    event Withdraw(address indexed user, uint256 assets);

    event RequestWithdraw(address indexed user, uint256 assets, uint256 shares);

    event CancelRequestWithdraw(address indexed user, uint256 assets, uint256 shares);

    event InstantWithdraw(address indexed user, uint256 assets, uint256 shares, uint256 fees);

    event SettleInterest(
        address indexed caller,
        uint256 diff,
        uint256 rate,
        uint256 interestAssets,
        uint256 weeklyInterestAssets
    );

    event WeeklySettle(address indexed caller, address indexed user, uint256 assets, uint256 shares);

    event SetDailyMaxInstantWithdrawAssets(
        uint256 maxInstantWithdrawAssets,
        uint256 leftInstantWithdrawAssets,
        uint256 maxAssets
    );

    event SetWeeklyMaxInstantWithdrawAssets(uint256 maxAssets);

    event Borrow(uint256 assets);

    event Repay(uint256 assets, bool repaySettle);

    event UpgradeStrategy(address strategy);

    event NewStrategyCandidate(address strategy);

    // ***************** //
    // *** FUNCTIONS *** //
    // ***************** //

    /// @dev ERC20 token for deposit && two withdraw ways(instant/request).
    /// @return assetTokenAddress Address of ERC20 token.
    function asset() external view returns (address assetTokenAddress);

    /// @dev Total amount of `asset` in Vault for share converting.
    /// @return totalManagedAssets Total amount of `asset`.
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /// @dev Amount of `asset` in Vault locally,
    /// SUBTRACT the amount of `asset` that market maker repay for weekly settle.
    /// @return assets Amount of `asset` in Vault locally.
    function localAssets() external view returns (uint256 assets);

    /// @dev Calculate the share price for convert unit shares(1e18) to assets.
    /// @return sharePrice Result of unit shares(1e18) convert to assets.
    function getPricePerFullShare() external view returns (uint256 sharePrice);

    /// @dev According to `totalAssets` and `totalSupply`, convert `assets` to `shares`.
    /// @param assets Amount of `asset` convert to `shares`
    /// @return shares Result of `assets` convert to `shares`.
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /// @dev According to `totalAssets` and `totalSupply`, convert `shares` to `assets`.
    /// @param shares Amount of `share` convert to `assets`
    /// @return assets Result of `shares` convert to `assets`.
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /// @dev Limit of total `deposit` amount of `asset` from user,
    /// `uint256(-1)` means no limit, `0` means Vault paused.
    /// @param user Address of Vault user.
    /// @return maxAssets Result of `asset` deposit limitations to user.
    function maxDeposit(address user) external view returns (uint256 maxAssets);

    /// @dev Total withdrawable amount of `asset` from user execute `withdraw`,
    /// @param user Address of Vault user.
    /// @return maxAssets Result of `asset` that user can withdraw.
    function maxWithdraw(address user) external view returns (uint256 maxAssets);

    /// @dev Max amount of `asset` that convert user shares to assets when `requestWithdraw`,
    /// only for safety check, not the final result until `weeklySettle` is done.
    /// @param user Address of Vault user.
    /// @return maxAssets Result of `dev` above.
    function maxRequestWithdraw(address user) external view returns (uint256 maxAssets);

    /// @dev Max amount of `asset` that user can withdraw immediately(not SUBTRACT fees here),
    /// related to user `shares` and weekly limit of `instantWithdraw`.
    /// @param user Address of Vault user.
    /// @return maxAssets Result of `dev` above.
    function maxInstantWithdraw(address user) external view returns (uint256 maxAssets);

    /// @dev Check if the `strategy` is active,
    /// only true if `strategy != address(0)` and strategy not paused.
    /// @return active Status of `strategy`, `true` means strategy working, `false` means not working now.
    function isStrategyActive() external view returns (bool active);

    /// @dev Deposit an amount of `asset` represented in `assets`.
    /// @param assets Amount of `asset` to deposit.
    /// @return shares The deposited amount repesented in shares.
    function deposit(uint256 assets) external payable returns (uint256 shares);

    /// @dev Withdraw total settled amount of `asset` from a user account,
    /// not accept `assets` as parameter,
    /// represented by the last epoch requested withdraw shares.
    function withdraw() external;

    /// @dev Request withdraw an amount of `asset` from a user account(no fees),
    /// represented in `shares` and keep in Vault(safeTransferFrom).
    /// @param assets Amount of `asset` to request withdraw.
    /// @return shares The request withdrew amount repesented in shares.
    function requestWithdraw(uint256 assets) external returns (uint256 shares);

    /// @dev Cancel total requested amount of `share` from a user account(no fees),
    /// and payback the total requested amount of `share`(safeTransfer).
    /// @return shares The request withdrew shares that been canceled.
    function cancelRequestWithdraw() external returns (uint256 shares);

    /// @dev Withdraw an amount of `asset` from a user account immediately(fees exist).
    /// @param assets Amount of `asset` to withdraw.
    /// @return shares The withdrew amount repesented in shares.
    function instantWithdraw(uint256 assets) external returns (uint256 shares);
}
