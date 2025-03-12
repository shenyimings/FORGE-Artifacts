// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;
import {IERC20Permit} from "../../shared/IERC20Permit.sol";

import {IKreskoAssetIssuer} from "../../kreskoasset/IKreskoAssetIssuer.sol";
import {IERC165} from "../../shared/IERC165.sol";

interface IKISS is IKreskoAssetIssuer, IERC165 {
    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */
    event NewOperatorInitialized(address indexed pendingNewOperator, uint256 unlockTimestamp);
    event NewOperator(address indexed newOperator);
    event NewMaxOperators(uint256 newMaxOperators);
    event NewPendingOperatorWaitPeriod(uint256 newPeriod);

    function pendingOperatorUnlockTime() external returns (uint256);

    function pendingOperator() external returns (address);

    function maxOperators() external returns (uint256);

    /**
     * @notice This function adds KISS to circulation
     * Caller must be a contract and have the OPERATOR_ROLE
     * @param _to address to mint tokens to
     * @param _amount amount to mint
     * @return amount minted
     */
    function issue(uint256 _amount, address _to) external returns (uint256);

    /**
     * @notice Use operator role for minting, so override the parent
     * Caller must be a contract and have the OPERATOR_ROLE
     * @param _to address to mint tokens to
     * @param _amount amount to mint
     * @dev Does not return a value
     */
    function mint(address _to, uint256 _amount) external;

    /**
     * @notice This function removes KISS from circulation
     * Caller must be a contract and have the OPERATOR_ROLE
     * @param _from address to burn tokens from
     * @param destroyed amount burned
     * @inheritdoc IKreskoAssetIssuer
     */
    function destroy(uint256 _amount, address _from) external returns (uint256 destroyed);

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() external;

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() external;

    /**
     * @notice Set a new waiting period for a new operator
     *
     * Must be at least 15 minutes
     *
     * @param _newPeriod the period, in seconds
     */
    function setPendingOperatorWaitPeriod(uint256 _newPeriod) external;

    /**
     * @notice Allows ADMIN_ROLE to change the maximum operators
     * @param _maxOperators new maximum amount of operators
     */
    function setMaxOperators(uint256 _maxOperators) external;

    /**
     * @notice Overrides `AccessControl.grantRole` for following:
     * * Implement a cooldown period of `pendingOperatorWaitPeriod` minutes for setting a new OPERATOR_ROLE
     * * EOA cannot be granted the operator role
     *
     * @notice OPERATOR_ROLE can still be revoked without this cooldown period
     * @notice PAUSER_ROLE can still be granted without this cooldown period
     * @param _role role to grant
     * @param _to address to grant role for
     */
    function grantRole(bytes32 _role, address _to) external;
}
