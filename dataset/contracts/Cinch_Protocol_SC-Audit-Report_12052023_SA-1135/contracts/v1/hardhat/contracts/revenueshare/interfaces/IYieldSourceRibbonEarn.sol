// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IYieldSourceRibbonEarn {
    /**
     * @notice Deposits the `asset` from msg.sender added to `creditor`'s deposit.
     * @notice Used for vault -> vault deposits on the user's behalf
     * @dev https://github.com/ribbon-finance/ribbon-v2/blob/7d8deadf8dd63273aeee105beebcb99564ad4711/contracts/vaults/RETHVault/base/RibbonVault.sol#L348
     * @param amount is the amount of `asset` to deposit
     * @param creditor is the address that can claim/withdraw deposited amount
     */
    function depositFor(uint256 amount, address creditor) external;

    /**
     * @notice Getter for returning the account's share balance including unredeemed shares
     * @param account is the account to lookup share balance for
     * @return the share balance
     */
    function shares(address account) external view returns (uint256);

    /**
     * @notice The price of a unit of share denominated in the `asset`
     */
    function pricePerShare() external view returns (uint256);

    /**
     * @notice Total supply of shares
     */
    function totalSupply() external view returns (uint256);
}
