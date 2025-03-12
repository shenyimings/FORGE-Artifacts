pragma solidity >=0.8.16;

interface ZoneInterface {
    /**
     * @dev Emit an event whenever a zone is successfully paused.
     */
    event Paused();

    /**
     * @dev Emit an event whenever a zone is successfully unpaused (created).
     */
    event Unpaused();

    // Called by Consideration whenever extraData is not provided by the caller.
    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address offerer,
        bytes32 zoneHash
    ) external view returns (bytes4 validOrderMagicValue);
}

contract PausableZone is ZoneInterface {
    constructor() {}

    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address offerer,
        bytes32 zoneHash
    ) external pure override returns (bytes4 validOrderMagicValue) {
        orderHash;
        caller;
        offerer;
        zoneHash;

        // Return the selector of isValidOrder as the magic value.
        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }
}
