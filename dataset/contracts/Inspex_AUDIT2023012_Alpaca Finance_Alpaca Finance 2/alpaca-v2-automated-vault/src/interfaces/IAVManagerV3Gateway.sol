// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

interface IAVManagerV3Gateway {
  error AVManagerV3Gateway_InvalidInput();
  error AVManagerV3Gateway_InvalidAddress();
  error AVManagerV3Gateway_TooLittleReceived();
  error AVManagerV3Gateway_NotPool();

  function deposit(address _vaultToken, address _token, uint256 _amount, uint256 _minReceived)
    external
    returns (bytes memory _result);

  function depositETH(address _vaultToken, uint256 _minReceived) external payable returns (bytes memory _result);

  function withdrawMinimize(
    address _vaultToken,
    uint256 _shareToWithdraw,
    AutomatedVaultManager.TokenAmount[] calldata _minAmountOut
  ) external returns (AutomatedVaultManager.TokenAmount[] memory _result);

  function withdrawConvertAll(address _vaultToken, uint256 _shareToWithdraw, bool _zeroForOne, uint256 _minAmountOut)
    external
    returns (uint256 _amountOut);
}
