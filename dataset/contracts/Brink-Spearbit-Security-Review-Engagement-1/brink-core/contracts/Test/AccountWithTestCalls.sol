// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;
pragma abicoder v1;

import "../Account/Account.sol";
import "./TestAccountCalls.sol";

abstract contract AccountWithTestCalls is Account, TestAccountCalls {

}
