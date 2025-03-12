// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./RewardsAndPenalties.sol";


contract Insurance is RewardsAndPenalties {
    uint private constant BASE_INSURANCE_FOR_BP = 3500; // trigger insurance with contract balance fall below 35%
    uint private constant OPT_IN_INSURANCE_FEE_BP = 1000; // 10%
    uint private constant OPT_IN_INSURANCE_FOR_BP = 10000; // 100%

    bool public isInInsuranceState = false; // if contract is only allowing insured money this becomes true;

    function _checkForBaseInsuranceTrigger() internal {
        if (fourRXToken.balanceOf(address(this)) <= _calcPercentage(maxContractBalance, BASE_INSURANCE_FOR_BP)) {
            isInInsuranceState = true;
        } else {
            isInInsuranceState = false;
        }
    }

    function _getInsuredAvailableAmount(Stake memory stake, uint withdrawalAmount) internal pure returns (uint)
    {
        uint availableAmount = withdrawalAmount;
        // Calc correct insured value by checking which insurance should be applied
        uint insuredFor = BASE_INSURANCE_FOR_BP;
        if (stake.optInInsured) {
            insuredFor = OPT_IN_INSURANCE_FOR_BP;
        }

        uint maxWithdrawalAllowed = _calcPercentage(stake.deposit, insuredFor);

        require(maxWithdrawalAllowed >= stake.withdrawn.add(stake.penalty)); // if contract is in insurance trigger, do not allow withdrawals for the users who already have withdrawn more then 35%

        if (stake.withdrawn.add(availableAmount).add(stake.penalty) > maxWithdrawalAllowed) {
            availableAmount = maxWithdrawalAllowed.sub(stake.withdrawn).sub(stake.penalty);
        }

        return availableAmount;
    }

    function _insureStake(address user, Stake storage stake) internal {
        require(!stake.optInInsured && stake.active);
        require(fourRXToken.transferFrom(user, address(this), _calcPercentage(stake.deposit, OPT_IN_INSURANCE_FEE_BP)));

        stake.optInInsured = true;
    }
}
