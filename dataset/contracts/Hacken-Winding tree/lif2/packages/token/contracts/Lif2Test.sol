// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./Lif2.sol";

/**
 * @dev Lif token implementation for testing purposes
 */
contract Lif2Test is Lif2 {

  /**
   * @dev Initializes the _stuckBalance storage.
   */
  function _afterClaimableInitHook()
    internal
    override(Lif2)
    virtual
    initializer
  {
    _stuckBalance[0x70997970C51812dc3A010C7d01b50e0d17dc79C8] += 9830000000000000000000;
    _stuckBalance[0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC] += 51999999999999999995385;
    _stuckBalance[0x90F79bf6EB2c4f870365E785982E1f101E93b906] += 751039901550000000000;
  }
}
