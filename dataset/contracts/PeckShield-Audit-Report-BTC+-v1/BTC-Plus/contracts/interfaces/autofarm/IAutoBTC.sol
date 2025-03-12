// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @title Interface of AutoFarm BTC.
 */
interface IAutoBTC {

    /**
     * @dev Mints autoBTC with BTCB.
     * @param _amount Amount of BTCB used to mint autoBTC.
     */
    function mint(uint _amount) external;

    /**
     * @dev Redeems autoBTC to BTCB.
     * @param _amount Amount of autoBTC to redeem.
     */
    function redeem(uint256 _amount) external;

    /**
     * @dev Returns the current exchange rate between AutoBTC and BTCB.
     */
    function exchangeRate() external view returns (uint256);

    /**
     * @dev Returns the pending AUTO to the account.
     */
    function pendingReward(address _account) external view returns (uint256);

    /**
     * @dev Claims all AUTO available for the caller.
     */
    function claimRewards() external;
}