pragma solidity 0.4.19;


library PhysicalAddressClaim {
    /**
     * Mask and Offset used to code and decode the version for a Claim.
     */
    uint256 constant public VERSION = 1;
    uint256 constant internal VERSION_MASK = 0xFF00000000000000000000000000000000000000000000000000000000000000;
    uint256 constant internal VERSION_OFFSET = 0x0100000000000000000000000000000000000000000000000000000000000000;
    uint256 constant internal VERSION_ENCODED = VERSION * VERSION_OFFSET;

    modifier isCurrentVersion(bytes32 _claim) {
        require((uint256(_claim) & VERSION_MASK) == VERSION_ENCODED);
        _;
    }

    /**
     * Mask used to extract the confirmation block of a Claim.
     * No offset needed since it will be stored at the end of the bytes32.
     */
    uint256 constant internal CONFIRMATION_MASK = 0x000000000000000000000000000000000000000000000000FFFFFFFFFFFFFFFF;

    /**
     * @notice Encodes the confirmation block number in a bytes32.
     * @param _confirmationBlockNumber Confirmation Block cant be greater than 8 bytes.
     * @return An single bytes32 containing the version of the schema and the params provided
     */
    function encode(uint256 _confirmationBlockNumber) public pure returns(bytes32) {
        require(_confirmationBlockNumber <= CONFIRMATION_MASK);
        return bytes32(VERSION_ENCODED | _confirmationBlockNumber);
    }

    /**
     * @notice Extracts the version and confirmation block number.
     * @param _claim The coded claim probably retrieved from a claims registry.
     * @return {
         "version": "An integer representing the version of the Claim.",
         "confirmation": "The contract address for recasting tokens",
       }
     */
    function decode(bytes32 _claim) public pure isCurrentVersion(_claim) returns(
        uint256 version,
        uint256 confirmation
    ) {
        version = decodeVersion(_claim);
        confirmation = decodeConfirmation(_claim);
    }

    /**
     * @notice Extracts the version.
     * @param _claim The coded claim probably retrieved from a claims registry.
     * @return An integer representing the version of the Claim.
     */
    function decodeVersion(bytes32 _claim) public pure returns(uint256 version) {
        version = (uint256(_claim) & VERSION_MASK) / VERSION_OFFSET;
    }

    /**
     * @notice Extracts the confirmation block number.
     * @param _claim The coded claim probably retrieved from a claims registry.
     * @return The confirmation block number.
     */
    function decodeConfirmation(bytes32 _claim) public pure returns(uint256 confirmation) {
        confirmation = uint256(_claim) & CONFIRMATION_MASK;
    }
}
