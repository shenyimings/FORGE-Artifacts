/*
    Copyright 2021 Cook Finance.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/
pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

//import "hardhat/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract RewardVesting {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public reward;

    // Variable for earning with locks
    struct LockedBalance {
        uint256 amount;
        uint256 unlockTime;
    }
    mapping(address => LockedBalance[]) private _userEarnings;
    uint256 public duration = 86400;

    struct Balances {
        uint256 earned;
    }

    mapping(address => Balances) public userBalances;

    uint256 public accumulatedPenalty = 0;

    /// @dev The address of the account which currently has administrative capabilities over this contract.
    address public governance;

    address public pendingGovernance;

    /// @dev The address of the reward source, the address can invoke addEarning 
    address public rewardSource;

    event EarningAdd(address indexed user, uint256 amount);
    event EarningWithdraw(address indexed user, uint256 amount, uint256 penaltyAmount);

    event PendingGovernanceUpdated(
      address pendingGovernance
    );

    event GovernanceUpdated(
      address governance
    );


    // solium-disable-next-line
    constructor(address _governance) public {
      require(_governance != address(0), "RewardVesting: governance address cannot be 0x0");
      governance = _governance;
    }

    /*
     * Owner methods
     */
    function initialize(IERC20 _reward, address _rewardSource) external onlyGovernance {
        require(reward == IERC20(0), "Already initialized");
        require(_rewardSource != address(0), "Zero address");
        reward = _reward;
        rewardSource = _rewardSource;
    }

    modifier onlyGovernance() {
      require(msg.sender == governance, "RewardVesting: only governance");
      _;
    }

    /// @dev Sets the governance.
    ///
    /// This function can only called by the current governance.
    ///
    /// @param _pendingGovernance the new pending governance.
    function setPendingGovernance(address _pendingGovernance) external onlyGovernance {
      require(_pendingGovernance != address(0), "RewardVesting: pending governance address cannot be 0x0");
      pendingGovernance = _pendingGovernance;

      emit PendingGovernanceUpdated(_pendingGovernance);
    }

    function acceptGovernance() external {
      require(msg.sender == pendingGovernance, "RewardVesting: only pending governance");

      address _pendingGovernance = pendingGovernance;
      governance = _pendingGovernance;

      emit GovernanceUpdated(_pendingGovernance);
    }


    function transferPenalty(address transferTo) external onlyGovernance {
        reward.safeTransfer(transferTo, accumulatedPenalty);
        accumulatedPenalty = 0;
    }

    /*
     * Add earning from other accounts, which will be locked for 3 months.
     * Early exit is allowed, by 50% will be penalty.
     */
    function addEarning(address user, uint256 amount, uint256 durationInSecs) external {
        require(msg.sender == rewardSource, "Not from reward source");
        _addPendingEarning(user, amount, durationInSecs);
        reward.safeTransferFrom(msg.sender, address(this), amount);
    }

    function _addPendingEarning(address user, uint256 amount, uint256 durationInSecs) internal {
        Balances storage bal = userBalances[user];
        bal.earned = bal.earned.add(amount);

        uint256 unlockTime = block.timestamp.div(duration).mul(duration).add(durationInSecs);
        LockedBalance[] storage earnings = _userEarnings[user];
        uint256 idx = earnings.length;

        if (idx == 0 || earnings[idx-1].unlockTime < unlockTime) {
            earnings.push(LockedBalance({amount: amount, unlockTime: unlockTime}));
        } else {
            earnings[idx-1].amount = earnings[idx-1].amount.add(amount);
        }
        emit EarningAdd(user, amount);
    }

    // Withdraw staked tokens
    // First withdraws unlocked tokens, then earned tokens. Withdrawing earned tokens
    // incurs a 50% penalty which will be burnt
    function withdrawEarning(uint256 amount) public {
        require(amount > 0, "Cannot withdraw 0");
        Balances storage bal = userBalances[msg.sender];
        uint256 penaltyAmount = 0;

        uint256 remaining = amount;
        bal.earned = bal.earned.sub(remaining);
        for (uint i = 0; ; i++) {
            uint256 earnedAmount = _userEarnings[msg.sender][i].amount;
            if (earnedAmount == 0) {
                continue;
            }
            if (penaltyAmount == 0 && _userEarnings[msg.sender][i].unlockTime > block.timestamp) {
                penaltyAmount = remaining;
                require(bal.earned >= remaining, "Insufficient balance after penalty");
                bal.earned = bal.earned.sub(remaining);
                if (bal.earned == 0) {
                    delete _userEarnings[msg.sender];
                    break;
                }
                remaining = remaining.mul(2);
            }
            if (remaining <= earnedAmount) {
                _userEarnings[msg.sender][i].amount = earnedAmount.sub(remaining);
                break;
            } else {
                delete _userEarnings[msg.sender][i];
                remaining = remaining.sub(earnedAmount);
            }
        }


        reward.safeTransfer(msg.sender, amount);

        accumulatedPenalty = accumulatedPenalty + penaltyAmount;

        emit EarningWithdraw(msg.sender, amount, penaltyAmount);
    }

    // Final balance received and penalty balance paid by user upon calling exit
    function withdrawableEarning(
        address user
    )
        public
        view
        returns (uint256 amount, uint256 penaltyAmount, uint256 amountWithoutPenalty)
    {
        Balances storage bal = userBalances[user];

        if (bal.earned > 0) {
            uint256 length = _userEarnings[user].length;
            for (uint i = 0; i < length; i++) {
                uint256 earnedAmount = _userEarnings[user][i].amount;
                if (earnedAmount == 0) {
                    continue;
                }
                if (_userEarnings[user][i].unlockTime > block.timestamp) {
                    break;
                }
                amountWithoutPenalty = amountWithoutPenalty.add(earnedAmount);
            }
            
            if (bal.earned.sub(amountWithoutPenalty) % 2 == 0) {
                penaltyAmount = bal.earned.sub(amountWithoutPenalty).div(2);
            } else {
                penaltyAmount = bal.earned.sub(amountWithoutPenalty).div(2) + 1;
            }
        }
        amount = bal.earned.sub(penaltyAmount);

        return (amount, penaltyAmount, amountWithoutPenalty);
    }

    function earnedBalances(
        address user
    )
        public
        view
        returns (uint total, uint[2][] memory earningsData)
    {
        LockedBalance[] storage earnings = _userEarnings[user];
        uint idx;
        for (uint i = 0; i < earnings.length; i++) {
            if (earnings[i].unlockTime > block.timestamp) {
                if (idx == 0) {
                    earningsData = new uint[2][](earnings.length - i);
                }
                earningsData[idx][0] = earnings[i].amount;
                earningsData[idx][1] = earnings[i].unlockTime;
                idx++;
                total = total.add(earnings[i].amount);
            }
        }
        return (total, earningsData);
    }
}