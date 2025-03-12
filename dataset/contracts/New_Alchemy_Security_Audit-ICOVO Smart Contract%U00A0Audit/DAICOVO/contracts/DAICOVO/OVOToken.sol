pragma solidity ^0.4.18;

import "./DaicovoStandardToken.sol";

/**
 * @title OVO Token
 * @dev ERC20, ERC223 compliant mintable token.
 * @dev Extended with icon field to indicate IPFS hash for the token icon image.
 * @dev icon field compatible wallet app can load a token icon image from IPFS.
 */
contract OVOToken is DaicovoStandardToken {
    string public icon;
    function OVOToken () public DaicovoStandardToken("ICOVO", "OVO", 9) {
        icon = "QmXMDG2UnMQ7rFqxRN2LVA3ad2FLNTarDXZijdrctt8vpo";
    }
}
