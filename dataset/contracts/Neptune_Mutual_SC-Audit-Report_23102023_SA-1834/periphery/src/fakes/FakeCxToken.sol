// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract FakeCxToken is ERC20Upgradeable {
  uint256 _expiresOn;

  function initialize(string memory tokenName, string memory tokenSymbol, uint256 expiry) public initializer {
    __ERC20_init(tokenName, tokenSymbol);

    _expiresOn = expiry;
  }

  function mint(address account, uint256 amount) external {
    super._mint(account, amount);
  }

  function expiresOn() external view returns (uint256) {
    return _expiresOn;
  }
}
