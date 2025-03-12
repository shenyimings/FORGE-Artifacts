// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ATokenMock is ERC20 {
  address public _comptroller;
  constructor(address troll)
    ERC20('aDAI', 'aDAI') public {
    _comptroller = troll;
    _mint(msg.sender, 10**18 * 450000000);
  }
  function setComptroller(address _comp) public {
    _comptroller = _comp;
  }
  function getIncentivesController() external view returns (address) {
    return _comptroller;
  }
}
