// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "@rari-capital/solmate/tokens/ERC20.sol";

/// @title A Wrapper of Solmate's ERC20
/// @dev We should use solmate ERC20 during an integration to prevent a naming conflict between solmakte's ERC20 and OpenZeppelin's ERC20
/// @dev since we use safeTransferLib from solmate, we need to stay with solmate's ERC20
contract MockDecimals18ERC20 is ERC20 {
  uint8 private _decimals;

  constructor(string memory _name, string memory _symbol)
    ERC20(_name, _symbol, 18)
  {}

  function mint(address _to, uint256 _amount) public {
    _mint(_to, _amount);
  }

  receive() external payable {
    _mint(msg.sender, msg.value);
  }
}
