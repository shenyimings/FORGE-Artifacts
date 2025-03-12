// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";

contract AutomatedVaultERC20 is ERC20, Initializable {
  address public vaultManager;

  error AutomatedVaultERC20_Unauthorized();

  modifier onlyVaultManager() {
    if (msg.sender != vaultManager) revert AutomatedVaultERC20_Unauthorized();
    _;
  }

  constructor() ERC20("", "", 18) {
    _disableInitializers();
  }

  function initialize(string calldata _name, string calldata _symbol) external initializer {
    name = _name;
    symbol = _symbol;
    vaultManager = msg.sender;
  }

  /// @notice Mint tokens. Only controller can call.
  /// @param _to Address to mint to.
  /// @param _amount Amount to mint.
  function mint(address _to, uint256 _amount) external onlyVaultManager {
    _mint(_to, _amount);
  }

  /// @notice Burn tokens. Only controller can call.
  /// @param _from Address to burn from.
  /// @param _amount Amount to burn.
  function burn(address _from, uint256 _amount) external onlyVaultManager {
    _burn(_from, _amount);
  }
}
