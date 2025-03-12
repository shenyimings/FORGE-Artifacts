pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice The handler registry database for Furucombo
contract Registry is Ownable {
    mapping(address => bytes32) public infos;

    bytes32 public constant DEPRECATED = bytes10(0x64657072656361746564);

    /**
     * @notice Register a handler with a bytes32 information.
     * @param registration Handler address.
     * @param info Info string.
     * @dev Dapps that triggers callback function should also be registered.
     * In this case, registration is the Dapp address and the leading 20 bytes
     * of info is the handler address.
     */
    function register(address registration, bytes32 info) external onlyOwner {
        require(registration != address(0), "zero address");
        require(infos[registration] != DEPRECATED, "unregistered");
        infos[registration] = info;
    }

    /**
     * @notice Unregister a handler. The handler will be deprecated.
     * @param registration The handler to be unregistered.
     */
    function unregister(address registration) external onlyOwner {
        require(registration != address(0), "zero address");
        require(infos[registration] != bytes32(0), "no registration");
        require(infos[registration] != DEPRECATED, "unregistered");
        infos[registration] = DEPRECATED;
    }

    /**
     * @notice Check if the handler is valid.
     * @param handler The handler to be verified.
     */
    function isValid(address handler) external view returns (bool result) {
        if (infos[handler] == 0 || infos[handler] == DEPRECATED) return false;
        else return true;
    }
}
