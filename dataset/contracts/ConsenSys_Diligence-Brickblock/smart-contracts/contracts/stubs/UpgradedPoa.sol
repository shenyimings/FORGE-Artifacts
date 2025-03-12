pragma solidity 0.4.24;

import "../PoaToken.sol";


contract UpgradedPoa is PoaToken {
  bool public isUpgraded;

  function setUpgrade()
    public
    returns (bool)
  {
    isUpgraded = true;
  }
}
