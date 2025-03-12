//pragma solidity ^0.4.24;
//
//import "./MainToken.sol";
//
//contract NonMintableMainToken is MainToken {
//  event Destory();
//
//  constructor(
//    string _name,
//    string _symbol,
//    uint8 _decimals,
//    uint256 _initialSupply,
//    uint256 _maxSupply
//  ) MainToken(_name, _symbol, _decimals, _initialSupply, _maxSupply)
//  public { }
//
//  function destroy() external onlyOwner {
//    emit Destory();
//    selfdestruct(owner); // any code after selfdestruct won't work
//  }
//}
