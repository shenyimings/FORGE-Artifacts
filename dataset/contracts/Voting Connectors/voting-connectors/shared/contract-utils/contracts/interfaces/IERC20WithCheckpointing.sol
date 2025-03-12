/*
 * SPDX-License-Identitifer:    GPL-3.0-or-later
 */

pragma solidity 0.4.24;

import "@aragon/os/contracts/lib/token/ERC20.sol";


contract IERC20WithCheckpointing is ERC20 {
    function balanceOfAt(address _owner, uint256 _blockNumber) public view returns (uint256);
    function totalSupplyAt(uint256 _blockNumber) public view returns (uint256);
}
