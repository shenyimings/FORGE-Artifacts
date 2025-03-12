// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '../interfaces/IClaimRewardsConnector.sol';
import '../../modules/Lender/LendingDispatcher.sol';
import '../../modules/SimplePosition/SimplePositionStorage.sol';

contract ClaimRewardsConnector is LendingDispatcher, SimplePositionStorage, IClaimRewardsConnector {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 private constant MANTISSA = 1e18;

    uint256 public immutable rewardsFactor;
    address public immutable holder;

    constructor(uint256 _rewardsFactor, address _holder) public {
        rewardsFactor = _rewardsFactor;
        holder = _holder;
    }

    function claimRewards() public override returns (address rewardsToken, uint256 rewardsAmount) {
        require(isSimplePosition(), 'SP1');
        address lender = getLender(simplePositionStore().platform);

        (rewardsToken, rewardsAmount) = claimRewards(lender, simplePositionStore().platform);
        if (rewardsToken != address(0)) {
            uint256 subsidy = rewardsAmount.mul(rewardsFactor) / MANTISSA;
            if (subsidy > 0) {
                IERC20(rewardsToken).safeTransfer(holder, subsidy);
            }
            if (rewardsAmount > subsidy) {
                IERC20(rewardsToken).safeTransfer(accountOwner(), rewardsAmount - subsidy);
            }
        }
    }
}
