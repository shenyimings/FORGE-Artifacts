// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../proxy/ControllableV3.sol";

contract MockBribe is ControllableV3 {

  uint public epoch;
  mapping(address => mapping(address => bool)) internal rewardTokens;

  function init(address controller_) external initializer {
    __Controllable_init(controller_);
  }

  function isRewardToken(address st, address rt) external view returns (bool) {
    return rewardTokens[st][rt];
  }

  function registerRewardToken(address st, address rt) external {
    rewardTokens[st][rt] = true;
  }

  function notifyRewardAmount(address, address token, uint amount) external {
    IERC20(token).transferFrom(msg.sender, address(this), amount);
  }

  function notifyForNextEpoch(address, address token, uint amount) external {
    IERC20(token).transferFrom(msg.sender, address(this), amount);
  }

  function notifyDelayedRewards(address, address, uint) external {
    // noop
  }

  /// @dev See {IERC165-supportsInterface}.
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == InterfaceIds.I_BRIBE || super.supportsInterface(interfaceId);
  }

  function increaseEpoch() external {
    epoch++;
  }

}
