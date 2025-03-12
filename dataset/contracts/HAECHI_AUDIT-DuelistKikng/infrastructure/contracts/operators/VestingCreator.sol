// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '@openzeppelin/contracts/proxy/Clones.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './VestingContract.sol';
import './Vesting.sol';

/**
 * Create new vesting contract for a user
 */
contract VestingCreator is Ownable {
  using Clones for address;
  using SafeERC20 for ERC20;

  struct InitTerm {
    address beneficiary;
    uint256 unlockAtTGE;
    uint256 cliffDuration;
    uint256 startCliff;
    uint256 vestingDuration;
    uint256 releaseType;
    uint256 amount;
  }

  address _vestingContract;

  ERC20 private _token;

  event NewVestingContract(address indexed vestingContract, address indexed beneficiary, uint256 indexed amount);

  constructor() {
    _vestingContract = address(new VestingContract());
  }

  function setToken(address token_) external onlyOwner {
    _token = ERC20(token_);
  }

  function createNewVesting(InitTerm memory term) external onlyOwner {
    require(address(_token) != address(0), 'VestingCreator: token was not set');
    // Clone new vesting contract
    address vestingContractAddress = _vestingContract.clone();
    VestingContract newVestingContract = VestingContract(vestingContractAddress);
    // Approve this contract to transfer given amount
    _token.safeApprove(vestingContractAddress, term.amount);
    // Init the vesting contract
    newVestingContract.init(
      Vesting.Term({
        genesis: address(this),
        amount: term.amount,
        unlockAtTGE: term.unlockAtTGE,
        startCliff: term.startCliff,
        beneficiary: term.beneficiary,
        token: address(_token),
        cliffDuration: term.cliffDuration,
        releaseType: term.releaseType,
        vestingDuration: term.vestingDuration
      })
    );
    emit NewVestingContract(vestingContractAddress, term.beneficiary, term.amount);
  }

  function transfer(address to, uint256 value) external onlyOwner {
    _token.safeTransfer(to, value);
  }

  function getBlockTime() external view returns (uint256) {
    return block.timestamp;
  }

  function getToken() external view returns (address) {
    return address(_token);
  }
}
