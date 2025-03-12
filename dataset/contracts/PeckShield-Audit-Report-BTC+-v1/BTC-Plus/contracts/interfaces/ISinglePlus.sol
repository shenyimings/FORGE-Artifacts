// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./IPlus.sol";

/**
 * @title Interface for single plus token.
 * Single plus token is backed by one ERC20 token and targeted at yield generation.
 */
interface ISinglePlus is IPlus {
    /**
     * @dev Returns the address of the underlying token.
     */
    function token() external view returns (address);

    /**
     * @dev Retrive the underlying assets from the investment.
     */
    function divest() external;

    /**
     * @dev Returns the amount that can be invested now. The invested token
     * does not have to be the underlying token.
     * investable > 0 means it's time to call invest.
     */
    function investable() external view returns (uint256);

    /**
     * @dev Invest the underlying assets for additional yield.
     */
    function invest() external;

    /**
     * @dev Returns the amount of reward that could be harvested now.
     * harvestable > 0 means it's time to call harvest.
     */
    function harvestable() external view returns (uint256);

    /**
     * @dev Harvest additional yield from the investment.
     */
    function harvest() external;

    /**
     * @dev Mints the single plus token with the underlying token.
     * @dev _amount Amount of the underlying token used to mint single plus token.
     */
    function mint(uint256 _amount) external;

    /**
     * @dev Redeems the single plus token.
     * @param _amount Amount of single plus token to redeem. -1 means redeeming all shares.
     */
    function redeem(uint256 _amount) external;
}