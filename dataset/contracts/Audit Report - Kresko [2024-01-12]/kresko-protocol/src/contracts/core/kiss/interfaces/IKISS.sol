// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC165} from "vendor/IERC165.sol";
import {IKreskoAssetIssuer} from "kresko-asset/IKreskoAssetIssuer.sol";
import {IVaultExtender} from "vault/interfaces/IVaultExtender.sol";

interface IKISS is IVaultExtender, IKreskoAssetIssuer, IERC165 {
    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice This function adds KISS to circulation
     * Caller must be a contract and have the OPERATOR_ROLE
     * @param _amount amount to mint
     * @param _to address to mint tokens to
     * @return uint256 amount minted
     */
    function issue(uint256 _amount, address _to) external override returns (uint256);

    /**
     * @notice This function removes KISS from circulation
     * Caller must be a contract and have the OPERATOR_ROLE
     * @param _amount amount to burn
     * @param _from address to burn tokens from
     * @return uint256 amount burned
     *
     * @inheritdoc IKreskoAssetIssuer
     */
    function destroy(uint256 _amount, address _from) external override returns (uint256);

    /**
     * @notice Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() external;

    /**
     * @notice  Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() external;

    /**
     * @notice Exchange rate of vKISS to USD.
     * @return rate vKISS/USD exchange rate.
     * @custom:signature exchangeRate()
     * @custom:selector 0x3ba0b9a9
     */
    function exchangeRate() external view returns (uint256 rate);

    /**
     * @notice Overrides `AccessControl.grantRole` for following:
     * @notice EOA cannot be granted Role.OPERATOR role
     * @param _role role to grant
     * @param _to address to grant role for
     */
    function grantRole(bytes32 _role, address _to) external;
}
