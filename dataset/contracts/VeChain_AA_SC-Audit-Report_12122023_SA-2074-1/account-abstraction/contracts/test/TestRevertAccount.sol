// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.12;
/* solhint-disable no-inline-assembly */

import "../samples/SimpleAccount.sol";
contract TestRevertAccount is IAccount {
    address public constant VTHO_TOKEN_ADDRESS = 0x0000000000000000000000000000456E65726779;
    IERC20 public constant VTHO_TOKEN_CONTRACT = IERC20(VTHO_TOKEN_ADDRESS);
    IEntryPoint private ep;
    constructor(IEntryPoint _ep) payable {
        ep = _ep;
    }

    function validateUserOp(UserOperation calldata, bytes32, uint256 missingAccountFunds)
    external override returns (uint256 validationData) {
        require(VTHO_TOKEN_CONTRACT.approve(address(ep), missingAccountFunds), "revert approval failed");
        ep.depositAmountTo(address(this), missingAccountFunds);
        return 0;
    }

    function revertLong(uint256 length) public pure{
        assembly {
            revert(0, length)
        }
    }
}
