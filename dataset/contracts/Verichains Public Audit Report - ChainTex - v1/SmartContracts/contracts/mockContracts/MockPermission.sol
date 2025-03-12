pragma solidity 0.4.25;

import "../PermissionGroups.sol";


contract MockPermission is PermissionGroups {
    uint public rate;
    bool public tradeActive = true;

    constructor() public
        PermissionGroups()
    {
    }

    function setRate ( uint newRate ) public
        onlyOperator
    {
        rate = newRate;
    }

    function stopTrade () public
        onlyAlerter
    {
        tradeActive = false;
    }

    function activateTrade () public
        onlyOperator
    {
        tradeActive = true;
    }
}
