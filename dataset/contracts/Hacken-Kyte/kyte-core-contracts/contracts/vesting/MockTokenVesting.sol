//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./TokenVesting.sol";

contract MockTokenVesting is TokenVesting {
    uint256 public mockTime = 0;

    constructor(address token_) TokenVesting(token_) {}

    function setBlockTimestamp(uint256 _time) external {
        mockTime = _time;
    }

    function _blockTimestamp() internal view override returns (uint256) {
        return mockTime;
    }

    function getLastVestingScheduleForHolder(address holder)
        public
        view
        returns (VestingSchedule memory)
    {
        return
            vestingSchedules[
                computeVestingScheduleIdForAddressAndIndex(
                    holder,
                    holdersVestingCount[holder] - 1
                )
            ];
    }

    function computeVestingScheduleIdForAddressAndIndex(
        address holder,
        uint256 index
    ) public pure returns (bytes32) {
        return _computeVestingScheduleIdForAddressAndIndex(holder, index);
    }

    function getVestingSchedulesCountByBeneficiary(address _beneficiary)
        external
        view
        returns (uint256)
    {
        return holdersVestingCount[_beneficiary];
    }
}
