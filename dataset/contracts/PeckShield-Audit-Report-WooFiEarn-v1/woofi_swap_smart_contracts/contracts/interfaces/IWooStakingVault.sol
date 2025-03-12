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

/// @title WOOFi WooStakingVault interface.
/// @notice WooStakingVault has been deployed, but not define `IWooStakingVault` at that time.
/// This interface is only for other contracts that want to call `WooStakingVault` functions.
interface IWooStakingVault {
    // ************** //
    // *** EVENTS *** //
    // ************** //

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

    // ***************** //
    // *** FUNCTIONS *** //
    // ***************** //

    /// @dev ERC20 token for deposit && two withdraw ways(instant/reserve).
    /// @return stakedTokenAddress Address of ERC20 token.
    function stakedToken() external view returns (address stakedTokenAddress);

    /// @dev Get user cost share price.
    /// @param user Address of Vault user.
    /// @return cost Result of `dev`.
    function costSharePrice(address user) external view returns (uint256 cost);

    /// @dev Get user amount of `stakedToken` by reserve withdraw && last reserve withdraw timestamp.
    /// @param user Address of Vault user.
    /// @return reserveAmount Result of `dev`.
    /// @return lastReserveWithdrawTime Result of `dev`.
    function userInfo(address user) external view returns (uint256 reserveAmount, uint256 lastReserveWithdrawTime);

    /// @dev Calculate the share price for convert unit shares(1e18) to assets.
    /// @return sharePrice Result of unit shares(1e18) convert to assets.
    function getPricePerFullShare() external view returns (uint256 sharePrice);

    /// @dev Get the `stakedToken` balance in Vault, SUBTRACT total `stakedToken` amount of user reserved withdraw.
    /// @return wooBalance Result of `dev`.
    function balance() external view returns (uint256 wooBalance);

    /// @dev Deposit an amount of `stakedToken`.
    /// @param amount Amount of `stakedToken` to deposit.
    function deposit(uint256 amount) external;

    /// @dev Reserve withdraw an amount of `stakedToken` from a user account(no fees).
    /// @param shares Amount of `asset` to request withdraw.
    function reserveWithdraw(uint256 shares) external;

    /// @dev Withdraw total reserved amount of `stakedToken` from a user account.
    function withdraw() external;

    /// @dev Withdraw an amount of `stakedToken` from a user account immediately(fees exist).
    /// @param shares Amount of `share`(e.g. xWOO) to withdraw.
    function instantWithdraw(uint256 shares) external;

    /// @dev For transfer rewards(e.g. WOO) to Vault(need approve).
    /// @notice Please to be sure calling this function will not get any rewards!!!
    /// @param amount Amount of reward that transfer to Vault.
    function addReward(uint256 amount) external;
}
