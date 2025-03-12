// SPDX-License-Identifier: MIT
/* solhint-disable */
pragma solidity 0.8.3;

import { MeowToken } from "@zero-tech/ztoken/contracts/MeowToken.sol";
import { MeowTokenTest } from "@zero-tech/ztoken/contracts/MeowTokenTest.sol";


contract MeowTokenMock is MeowToken {
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
