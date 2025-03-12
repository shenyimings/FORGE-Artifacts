pragma solidity ^0.8.0;

import "../interfaces/IShared.sol";

/**
 * @title    Shared contract
 * @notice   Holds constants and modifiers that are used in multiple contracts
 * @dev      It would be nice if this could be a library, but modifiers can't be exported :(
 */

abstract contract Shared is IShared {
    /// @dev The address used to indicate whether transfer should send native or a token
    address internal constant _NATIVE_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant _ZERO_ADDR = address(0);
    bytes32 internal constant _NULL = "";
    uint256 internal constant _E_18 = 1e18;

    /// @dev    Checks that a uint isn't zero/empty
    modifier nzUint(uint256 u) {
        require(u != 0, "Shared: uint input is empty");
        _;
    }

    /// @dev    Checks that an address isn't zero/empty
    modifier nzAddr(address a) {
        require(a != _ZERO_ADDR, "Shared: address input is empty");
        _;
    }

    /// @dev    Checks that a bytes32 isn't zero/empty
    modifier nzBytes32(bytes32 b) {
        require(b != _NULL, "Shared: bytes32 input is empty");
        _;
    }

    /// @dev    Checks that the pubKeyX is populated
    modifier nzKey(Key memory key) {
        require(key.pubKeyX != 0, "Shared: pubKeyX is empty");
        _;
    }
}
