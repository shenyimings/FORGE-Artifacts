// contracts/ETNGovernanceInterface.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
  
interface ETNGovernanceInterface {

    function newEpoch() external;
    function slashValidator(address validatorAddress) external;

    function getValidators() external view returns (address[] memory);
}