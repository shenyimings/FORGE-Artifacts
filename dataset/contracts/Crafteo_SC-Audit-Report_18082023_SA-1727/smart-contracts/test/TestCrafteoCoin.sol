// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// These files are dynamically created at test time
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/CrafteoToken.sol";

contract TestCrafteoToken {

  function testInitialBalanceUsingDeployedContract() public {
    CrafteoToken meta = CrafteoToken(DeployedAddresses.CrafteoToken());

    uint expected = 10000;

    Assert.equal(meta.getBalance(tx.origin), expected, "Owner should have 10000 CrafteoToken initially");
  }

  function testInitialBalanceWithNewCrafteoToken() public {
    CrafteoToken meta = new CrafteoToken();

    uint expected = 10000;

    Assert.equal(meta.getBalance(tx.origin), expected, "Owner should have 10000 CrafteoToken initially");
  }

}
