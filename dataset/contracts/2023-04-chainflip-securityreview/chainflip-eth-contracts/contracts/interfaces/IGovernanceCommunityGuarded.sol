pragma solidity ^0.8.0;

import "./IShared.sol";

/**
 * @title    GovernanceCommunityGuarded interface
 */

interface IGovernanceCommunityGuarded is IShared {
    event CommunityGuardDisabled(bool communityGuardDisabled);
    event Suspended(bool suspended);

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                  State-changing functions                //
    //                                                          //
    //////////////////////////////////////////////////////////////
    /**
     * @notice  Enable Community Guard
     */

    function enableCommunityGuard() external;

    /**
     * @notice  Disable Community Guard
     */
    function disableCommunityGuard() external;

    /**
     * @notice  Can be used to suspend contract execution - only executable by
     *          governance and only to be used in case of emergency.
     */
    function suspend() external;

    /**
     * @notice      Resume contract execution
     */
    function resume() external;

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                          Getters                         //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Get the Community Key
     * @return  The CommunityKey
     */
    function getCommunityKey() external view returns (address);

    /**
     * @notice  Get the Community Guard state
     * @return  The Community Guard state
     */
    function getCommunityGuardDisabled() external view returns (bool);

    /**
     * @notice  Get suspended state
     * @return  The suspended state
     */
    function getSuspendedState() external view returns (bool);

    /**
     * @notice  Get governor address
     * @return  The governor address
     */
    function getGovernor() external view returns (address);
}
