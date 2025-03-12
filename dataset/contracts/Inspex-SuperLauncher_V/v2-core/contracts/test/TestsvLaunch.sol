// SPDX-License-Identifier: agpl-3.0

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title SvLaunch
 * @notice User stake LAUNCH token to receive svLAUNCH token
 * @author SuperLauncher
 **/
contract V2SvL is ERC20Snapshot {
  string internal constant NAME = 'V2svLAUNCH';
  string internal constant SYMBOL = 'V2svL';
  uint8 internal constant DECIMALS = 18;

  constructor( ) ERC20(NAME, SYMBOL)
    public
  {
      _mint(msg.sender, 1_000_000e18);
  }
  
    /**
     * @dev - Override _snapshot.
     */
    function snapshot() external  returns (uint256) {
        return _snapshot();
    }
}