// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

interface ISweeper {
  /**
   * @dev transfer ERC20 from the utility contract, for ERC20 recovery in case of stuck tokens due
   * direct transfers to the contract address.
   * @param token token to transfer
   * @param to recipient of the transfer
   * @param amount amount to send
   */
  function sweepToken(
    address token,
    address to,
    uint256 amount
  ) external;

  /**
   * @dev transfer native Ether from the utility contract, for native Ether recovery in case of stuck Ether
   * due selfdestructs or transfer ether to pre-computated contract address before deployment.
   * @param to recipient of the transfer
   * @param amount amount to send
   */
  function sweepEth(address to, uint256 amount) external;
}
