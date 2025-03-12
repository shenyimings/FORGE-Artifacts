// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './Vesting.sol';

/**
 * Vesting Contract
 */
contract VestingContract {
  using SafeERC20 for ERC20;
  using SafeMath for uint256;

  ERC20 private _token;

  uint256 immutable RELEASE_MONTHLY = 1;
  uint256 immutable RELEASE_LINEAR = 2;

  Vesting.Schedule private _schedule;

  event Withdrawal(address beneficiary, uint256 blocks, uint256 amount);

  function init(Vesting.Term memory term) external returns (bool) {
    require(address(_token) == address(0), 'VestingContract: Can not be called twice');
    require(term.unlockAtTGE <= term.amount, 'VestingContract: Unlocked amount can not greater than total amount');
    Vesting.Schedule memory schedule;
    _token = ERC20(term.token);
    if (term.unlockAtTGE > 0) {
      // Unlock token at TGE
      _token.safeTransferFrom(term.genesis, term.beneficiary, term.unlockAtTGE);
    }
    // Remaining token
    schedule.beneficiary = term.beneficiary;
    schedule.genesis = term.genesis;
    schedule.remain = term.amount.sub(term.unlockAtTGE);
    schedule.releaseType = term.releaseType;
    schedule.consumedBlocks = 0;
    schedule.startVesting = term.startCliff.add(term.cliffDuration);
    schedule.totalBlocks = _getVestedBlocks(term.vestingDuration, term.releaseType);
    schedule.unlockAmountPerBlock = schedule.remain.div(schedule.totalBlocks);
    _schedule = schedule;
    return true;
  }

  function withdraw() external returns (bool) {
    address owner = msg.sender;
    Vesting.Schedule memory schedule = _schedule;
    require(schedule.beneficiary == owner, 'VestingContract: We do not allow cross trigger');
    require(schedule.remain > 0, 'VestingContract: Insufficient balance');
    require(block.timestamp > schedule.startVesting, 'VestingContract: Your token is not vested');
    require(schedule.consumedBlocks < schedule.totalBlocks, 'VestingContract: You consumed all blocks');
    // Calculate vested block
    uint256 vestedBlocks = _getVestedBlocks(block.timestamp.sub(schedule.startVesting), schedule.releaseType);
    // Prevent overflow
    if (vestedBlocks >= schedule.totalBlocks) {
      vestedBlocks = schedule.totalBlocks;
    }
    // Calculate redeemable amount
    uint256 redeemableBlocks = vestedBlocks.sub(schedule.consumedBlocks);
    uint256 amount = redeemableBlocks.mul(schedule.unlockAmountPerBlock);
    require(amount > 0, 'VestingContract: Token was not vested');
    // Process transfer
    _token.safeTransferFrom(schedule.genesis, owner, amount);
    // Update data
    schedule.consumedBlocks = schedule.consumedBlocks.add(redeemableBlocks);
    schedule.remain = schedule.remain.sub(amount);
    emit Withdrawal(schedule.beneficiary, redeemableBlocks, amount);
    _schedule = schedule;
    return true;
  }

  function _availableBalance() private view returns (uint256) {
    Vesting.Schedule memory schedule = _schedule;
    if (block.timestamp > schedule.startVesting) {
      uint256 vestedBlocks = _getVestedBlocks(block.timestamp.sub(schedule.startVesting), schedule.releaseType);
      // Prevent overflow
      if (vestedBlocks >= schedule.totalBlocks) {
        vestedBlocks = schedule.totalBlocks;
      }
      uint256 redeemableBlocks = vestedBlocks.sub(schedule.consumedBlocks);
      return redeemableBlocks.mul(schedule.unlockAmountPerBlock);
    }
    return 0;
  }

  function _getVestedBlocks(uint256 duration, uint256 releaseType) private pure returns (uint256) {
    return releaseType == RELEASE_LINEAR ? duration.div(1 days) : duration.div(30 days);
  }

  function balanceOf(address) public view returns (uint256) {
    return _availableBalance();
  }

  function totalSupply() external view returns (uint256) {
    return _token.totalSupply();
  }

  function name() external view returns (string memory) {
    return string(abi.encodePacked('Vesting ', _token.name()));
  }

  function symbol() external view returns (string memory) {
    return string(abi.encodePacked('V', _token.symbol()));
  }

  function decimals() external view returns (uint8) {
    return _token.decimals();
  }

  function getVestingSchedule() external view returns (Vesting.Schedule memory) {
    return _schedule;
  }
}
