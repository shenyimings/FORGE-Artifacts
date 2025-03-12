// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IJonesGlpCompoundRewards {
    event Deposit(address indexed _caller, address indexed receiver, uint256 _assets, uint256 _shares);
    event Withdraw(address indexed _caller, address indexed receiver, uint256 _assets, uint256 _shares);
    event Compound(uint256 _rewards, uint256 _totalAssets, uint256 _retentions);

    /**
     * @notice Deposit assets into this contract and get shares
     * @param assets Amount of assets to be deposit
     * @param receiver Address Owner of the deposit
     * @return Amount of shares minted
     */
    function deposit(uint256 assets, address receiver) external returns (uint256);

    /**
     * @notice Withdraw the deposited assets
     * @param shares Amount to shares to be burned to get the assets
     * @param receiver Address who will receive the assets
     * @return Amount of assets redemeed
     */
    function redeem(uint256 shares, address receiver) external returns (uint256);

    /**
     * @notice Claim cumulative rewards & stake them
     */
    function compound() external;

    /**
     * @notice Preview how many shares will obtain when deposit
     * @param assets Amount to shares to be deposit
     * @return Amount of shares to be minted
     */
    function previewDeposit(uint256 assets) external view returns (uint256);

    /**
     * @notice Preview how many assets will obtain when redeem
     * @param shares Amount to shares to be redeem
     * @return Amount of assets to be redeemed
     */
    function previewRedeem(uint256 shares) external view returns (uint256);

    /**
     * @notice Convert recipent compounded assets into un-compunding assets
     * @param assets Amount to be converted
     * @param recipient address of assets owner
     * @return Amount of un-compounding assets
     */
    function totalAssetsToDeposits(address recipient, uint256 assets) external view returns (uint256);

    error AddressCannotBeZeroAddress();
    error AmountCannotBeZero();
    error AmountExceedsStakedAmount();
    error RetentionPercentageOutOfRange();
}
