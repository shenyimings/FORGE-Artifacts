// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "../../../Treasury.sol";

contract TreasuryChangeFunctionSignature is Treasury {
    function addSupportedToken(address _token, bool isSupported)
        external
        onlyRole(TREASURY_MANAGER_ROLE)
    {
        require(!isSupportedToken[_token], "TOKEN_ALREADY_EXISTS");
        isSupportedToken[_token] = isSupported;
        emit TokenAdded(_token, msg.sender, block.timestamp);
    }
}
