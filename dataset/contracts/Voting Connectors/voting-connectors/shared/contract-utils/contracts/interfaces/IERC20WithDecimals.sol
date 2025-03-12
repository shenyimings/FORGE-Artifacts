                                                                  /*
 * SPDX-License-Identitifer:    GPL-3.0-or-later
 */

pragma solidity 0.4.24;

import "@aragon/os/contracts/lib/token/ERC20.sol";


contract IERC20WithDecimals is ERC20 {
    function decimals() public view returns (uint8);
}
