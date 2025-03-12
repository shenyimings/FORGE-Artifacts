// SPDX-License-Identifier: MIT
import "./IAccessControl.sol";
pragma solidity ^0.8.9;

contract SimpleAccessControl is IAccessControlContract {
    function hasAccess(address addr, bytes32 tagId, uint256 c1x) public view returns (bool hasAccess) {
        if (addr == address(0x51fEb8C526F40825953912d572f6b64B4897D073)) {
            return true;
        }
        return false;
    }
}