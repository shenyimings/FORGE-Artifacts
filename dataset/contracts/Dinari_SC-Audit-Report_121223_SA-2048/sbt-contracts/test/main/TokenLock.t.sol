// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {MockToken} from "../utils/mocks/MockToken.sol";
import {TokenLockCheck} from "../../src/TokenLockCheck.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

contract TokenLockTest is Test {
    MockToken token;
    MockToken token2;
    TokenLockCheck tokenLockCheck;
    address user;

    function setUp() public {
        user = address(1);
        token = new MockToken("Money", "$");
        token2 = new MockToken("Money", "$");
        tokenLockCheck = new TokenLockCheck(address(token), address(token2));
    }

    function testLocked() public {
        assertEq(tokenLockCheck.isTransferLocked(address(token), user), false);
        assertEq(tokenLockCheck.isTransferLocked(address(token2), user), false);
        assertEq(tokenLockCheck.isTransferLocked(user, user), false);

        token.blacklist(user);
        token2.blacklist(user);
        assertEq(tokenLockCheck.isTransferLocked(address(token), user), true);
        assertEq(tokenLockCheck.isTransferLocked(address(token2), user), true);
    }

    function testCallSelector() public {
        vm.expectRevert(Address.FailedInnerCall.selector);
        tokenLockCheck.setCallSelector(address(token), 0x032f29a1); // lock selector doesn't exist for token contract

        tokenLockCheck.setCallSelector(address(token), token.isBlacklisted.selector);
    }
}
