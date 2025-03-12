// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;
pragma abicoder v1;

contract TestAccountCalls {
  bool private _called;

  event ExecutedTestCall();
  event MockParamEvent(uint256 mockUint);
  event MockParamsEvent(uint256 mockUint, int24 mockInt, address mockAddress);

  function testRevert(bool forceRevert) external {
    require(!forceRevert, "TestAccountCalls: reverted");
    _called = true;
    emit ExecutedTestCall();
  }

  function testTransferETH (uint256 amount, address recipient) external {
    bool success;
    (success, ) = recipient.call{value: amount}("");
    require(success, "TestAccountCalls: testTransferETH call failed");
  }

  function testEvent (uint256 mockUint) external {
    emit MockParamEvent(mockUint);
  }

  function testEvent (uint256 mockUint, int24 mockInt, address mockAddress) external {
    emit MockParamsEvent(mockUint, mockInt, mockAddress);
  }

  function testStore (uint256 mockUint) external {
    bytes32 ptr = keccak256('mockUint');
    assembly {
      sstore(ptr, mockUint)
    }
  }
}