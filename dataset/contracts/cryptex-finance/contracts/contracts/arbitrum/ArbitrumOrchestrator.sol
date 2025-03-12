// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

import "../BaseOrchestrator.sol";

/**
 * @title TCAP Arbitrum Orchestrator
 * @author Cryptex.finance
 * @notice Orchestrator contract in charge of managing the settings of the vaults, rewards and TCAP token. It acts as the owner of these contracts.
 */
contract ArbitrumOrchestrator is BaseOrchestrator {
  /**
   * @notice Constructor
   * @param _guardian The guardian address that is used to take immediate actions like pausing.
   * @param _owner The owner address that controls access to functions marked with the onlyOwner modifier.
   **/
  constructor(address _guardian, address _owner)
    BaseOrchestrator(_guardian, _owner)
  {}

  /// @notice renounceOwnership has been disabled so that the contract is never left without a onwer
  /// @inheritdoc Proprietor
  function renounceOwnership() public override onlyOwner {
    revert("ArbitrumOrchestrator::renounceOwnership: function disabled");
  }
}
