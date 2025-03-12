pragma solidity ^0.8.0;

import "./interfaces/IGovernanceCommunityGuarded.sol";
import "./AggKeyNonceConsumer.sol";
import "./abstract/Shared.sol";

/**
 * @title    GovernanceCommunityGuarded contract
 * @notice   Allows the governor to perform certain actions for the procotol's safety in
 *           case of emergency. The aim is to allow the governor to suspend execution of
 *           critical functions.
 *           Also, it allows the CommunityKey to safeguard certain functions so the
 *           governor can execute them iff the communityKey allows it.
 */
abstract contract GovernanceCommunityGuarded is Shared, IGovernanceCommunityGuarded {
    /// @dev    Community Guard Disabled
    bool private _communityGuardDisabled;

    /// @dev    Whether execution is suspended
    bool private _suspended = false;

    /**
     * @notice  Get the governor's address. The contracts inheriting this (StakeManager and Vault)
     *          get the governor's address from the KeyManager through the AggKeyNonceConsumer's
     *          inheritance. Therefore, the implementation of this function must be left
     *          to the children. This is not implemented as a virtual onlyGovernor modifier to force
     *          the children to implement this function - virtual modifiers don't enforce that.
     * @return  The governor's address
     */
    function _getGovernor() internal view virtual returns (address);

    /**
     * @notice  Get the community's address. The contracts inheriting this (StakeManager and Vault)
     *          get the community's address from the KeyManager through the AggKeyNonceConsumer's
     *          inheritance. Therefore, the implementation of this function must be left
     *          to the children. This is not implemented as a virtual onlyCommunityKey modifier to force
     *          the children to implement this function - virtual modifiers don't enforce that.
     * @return  The community's address
     */
    function _getCommunityKey() internal view virtual returns (address);

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                  State-changing functions                //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Enable Community Guard
     */
    function enableCommunityGuard() external override onlyCommunityKey onlyCommunityGuardDisabled {
        _communityGuardDisabled = false;
        emit CommunityGuardDisabled(false);
    }

    /**
     * @notice  Disable Community Guard
     */
    function disableCommunityGuard() external override onlyCommunityKey onlyCommunityGuardEnabled {
        _communityGuardDisabled = true;
        emit CommunityGuardDisabled(true);
    }

    /**
     * @notice Can be used to suspend contract execution - only executable by
     * governance and only to be used in case of emergency.
     */
    function suspend() external override onlyGovernor onlyNotSuspended {
        _suspended = true;
        emit Suspended(true);
    }

    /**
     * @notice      Resume contract execution
     */
    function resume() external override onlyGovernor onlySuspended {
        _suspended = false;
        emit Suspended(false);
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                          Getters                         //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Get the Community Key
     * @return  The CommunityKey
     */
    function getCommunityKey() external view override returns (address) {
        return _getCommunityKey();
    }

    /**
     * @notice  Get the Community Guard state
     * @return  The Community Guard state
     */
    function getCommunityGuardDisabled() external view override returns (bool) {
        return _communityGuardDisabled;
    }

    /**
     * @notice  Get suspended state
     * @return  The suspended state
     */
    function getSuspendedState() external view override returns (bool) {
        return _suspended;
    }

    /**
     * @notice  Get governor address
     * @return  The governor address
     */
    function getGovernor() external view override returns (address) {
        return _getGovernor();
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                         Modifiers                        //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /// @dev    Check that the caller is the Community Key address.
    modifier onlyCommunityKey() {
        require(msg.sender == _getCommunityKey(), "Governance: not Community Key");
        _;
    }

    /// @dev    Check that community has disabled the community guard.
    modifier onlyCommunityGuardDisabled() {
        require(_communityGuardDisabled, "Governance: community guard enabled");
        _;
    }

    /// @dev    Check that community has disabled the community guard.
    modifier onlyCommunityGuardEnabled() {
        require(!_communityGuardDisabled, "Governance: community guard disabled");
        _;
    }

    /// @notice Ensure that the caller is the governor address. Calls the getGovernor
    ///         function which is implemented by the children.
    modifier onlyGovernor() {
        require(msg.sender == _getGovernor(), "Governance: not governor");
        _;
    }

    // @notice Check execution is suspended
    modifier onlySuspended() {
        require(_suspended, "Governance: not suspended");
        _;
    }

    // @notice Check execution is not suspended
    modifier onlyNotSuspended() {
        require(!_suspended, "Governance: suspended");
        _;
    }
}
