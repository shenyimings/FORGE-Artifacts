// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (finance/VestingWallet.sol)
pragma solidity =0.8.20;

import "@openzeppelin/contracts/finance/VestingWallet.sol";

contract Vesting is VestingWallet {
    uint64 private immutable _intervel;

    constructor(
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 intervelSeconds
    )
        payable
        VestingWallet(beneficiaryAddress, startTimestamp, durationSeconds)
    {
        _intervel = intervelSeconds;
    }

    function intervel() public view virtual returns (uint256) {
        return _intervel;
    }

    function _vestingSchedule(
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view virtual override returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp >= start() + duration()) {
            return totalAllocation;
        } else {
            // Calculate the number of  intervel  periods since the start timestamp
            uint256 elapsedIntervelAmount = ((timestamp - start()) *
                totalAllocation) / intervel();

            // Calculate the vested amount based on the elapsed intervel  periods
            return elapsedIntervelAmount / (duration() / intervel());
        }
    }
}
