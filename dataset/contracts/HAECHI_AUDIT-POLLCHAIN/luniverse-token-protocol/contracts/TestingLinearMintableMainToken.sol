pragma solidity ^0.4.24;

import "./MainToken.sol";

contract TestingLinearMintableMainToken is MainToken {

  constructor(
    string _name,
    string _symbol,
    uint8 _decimals,
    uint256 _initialSupply,
    uint256 _maxSupply) MainToken(_name, _symbol, _decimals, _initialSupply, _maxSupply)
  public { }

  function mintForTest(uint256 _blockTimestamp) public {
    mintInternal(_blockTimestamp);
  }
}
