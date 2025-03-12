// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interfaces/IThrowable.sol";

abstract contract TokenRecovery is IThrowable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  function _recoverEther(address sendTo) internal {
    // slither-disable-next-line low-level-calls
    (bool success,) = payable(sendTo).call{value: address(this).balance}(""); // solhint-disable-line avoid-low-level-calls

    if (success == false) {
      revert ExternalContractInvocationRevertError();
    }
  }

  function _recoverToken(IERC20Upgradeable malicious, address sendTo) internal {
    malicious.safeTransfer(sendTo, malicious.balanceOf(address(this)));
  }
}
