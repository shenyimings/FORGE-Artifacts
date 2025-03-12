// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title TokenVesting
 * @dev This contract handles the vesting of ERC20 tokens for a given beneficiary.
 * can be given to this contract, which will release the token to the beneficiary following a given vesting schedule.
 * The vesting schedule is customizable through the {vestedAmount} function.
 */
contract TokenVesting is Context, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    event Released(uint256 indexed id, address beneficiary, uint256 amount);
    event VestingAdded(
        uint256 indexed id,
        uint256 amounts,
        address beneficiary,
        uint64 start,
        uint64 duration
    );
    event VestingUpdated(
        uint256 indexed id,
        uint256 amounts,
        address beneficiary,
        uint64 start,
        uint64 duration
    );

    struct Vesting {
        uint256 id;
        uint256 amounts;
        address beneficiary;
        uint64 start;
        uint64 duration;
        uint256 released;
    }
    Vesting[] private _vestings;

    IERC20 public immutable vestingToken;

    mapping(address => EnumerableSet.UintSet) private _beneficiaryVestingIds;

    /**
     * @dev Set the vestingToken.
     */
    constructor(address tokenAddress) {
        vestingToken = IERC20(tokenAddress);
    }

    function createVesting(
        uint256 vestingAmounts,
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) external onlyOwner returns (uint256 id) {
        require(durationSeconds != 0, "durationSeconds is zero");
        require(beneficiaryAddress != address(0), "beneficiary is zero address");

        id = _vestings.length;
        Vesting memory newVesting = Vesting({
            id: id,
            beneficiary: beneficiaryAddress,
            amounts: vestingAmounts,
            start: startTimestamp,
            duration: durationSeconds,
            released: 0
        });
        _vestings.push(newVesting);
        _beneficiaryVestingIds[beneficiaryAddress].add(id);
        SafeERC20.safeTransferFrom(vestingToken, _msgSender(), address(this), vestingAmounts);

        emit VestingAdded(id, vestingAmounts, beneficiaryAddress, startTimestamp, durationSeconds);
    }

    function editVesting(
        uint256 id,
        uint256 vestingAmounts,
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) external onlyOwner {
        require(durationSeconds != 0, "durationSeconds is zero");
        require(beneficiaryAddress != address(0), "beneficiary is zero address");

        Vesting memory vesting = getVestingAt(id);
        require(vesting.released <= vestingAmounts, "released is more than vestingAmounts");
        if (vestingAmounts > vesting.amounts) {
            SafeERC20.safeTransferFrom(
                vestingToken,
                _msgSender(),
                address(this),
                vestingAmounts - vesting.amounts
            );
        } else if (vesting.amounts > vestingAmounts) {
            SafeERC20.safeTransfer(vestingToken, _msgSender(), vesting.amounts - vestingAmounts);
        }

        if (beneficiaryAddress != vesting.beneficiary) {
            _beneficiaryVestingIds[vesting.beneficiary].remove(id);
            _beneficiaryVestingIds[beneficiaryAddress].add(id);
        }

        vesting.amounts = vestingAmounts;
        vesting.beneficiary = beneficiaryAddress;
        vesting.start = startTimestamp;
        vesting.duration = durationSeconds;

        _vestings[id] = vesting;

        emit VestingUpdated(
            id,
            vestingAmounts,
            beneficiaryAddress,
            startTimestamp,
            durationSeconds
        );
    }

    function getVestingAt(uint256 id) public view returns (Vesting memory) {
        require(id < _vestings.length, "Invalid vesting id");
        return _vestings[id];
    }

    function getTotalVestingCount() external view returns (uint256) {
        return _vestings.length;
    }

    function vestingCountForBeneficiary(address beneficiary) public view returns (uint256) {
        return _beneficiaryVestingIds[beneficiary].length();
    }

    function vestingsForBeneficiary(address beneficiary) external view returns (Vesting[] memory) {
        uint256 length = _beneficiaryVestingIds[beneficiary].length();
        Vesting[] memory userLocks = new Vesting[](length);

        for (uint256 i = 0; i < length; i++) {
            userLocks[i] = getVestingAt(_beneficiaryVestingIds[beneficiary].at(i));
        }
        return userLocks;
    }

    function getVestings(uint256 start, uint256 end) external view returns (Vesting[] memory) {
        uint256 length = end - start + 1;
        Vesting[] memory vestings = new Vesting[](length);
        uint256 currentIndex = 0;
        for (uint256 i = start; i <= end; i++) {
            vestings[currentIndex] = getVestingAt(i);
            currentIndex++;
        }
        return vestings;
    }

    /**
     * @dev Getter for the amount of releasable.
     */
    function releasable(uint256 id) public view virtual returns (uint256) {
        uint256 vested = vestedAmount(id, uint64(block.timestamp));
        uint256 released = getVestingAt(id).released;
        if (released > vested) {
            return 0;
        }
        return vested - released;
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {Released} event.
     */
    function release(uint256 id) public virtual {
        uint256 amount = releasable(id);
        if (amount != 0) {
            Vesting storage vesting = _vestings[id];
            vesting.released += amount;
            address beneficiary = vesting.beneficiary;
            emit Released(id, beneficiary, amount);
            SafeERC20.safeTransfer(vestingToken, beneficiary, amount);
        }
    }

    function releaseByBeneficiary(address beneficiary) public virtual {
        uint256 length = _beneficiaryVestingIds[beneficiary].length();

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < length; i++) {
            uint256 id = _beneficiaryVestingIds[beneficiary].at(i);
            uint256 amount = releasable(id);
            if (amount != 0) {
                totalAmount += amount;
                Vesting storage vesting = _vestings[id];
                vesting.released += amount;
                emit Released(id, beneficiary, amount);
            }
        }
        if (totalAmount != 0) {
            SafeERC20.safeTransfer(vestingToken, beneficiary, totalAmount);
        }
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(uint256 id, uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(id, timestamp);
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(
        uint256 id,
        uint64 timestamp
    ) internal view virtual returns (uint256) {
        Vesting memory vesting = getVestingAt(id);
        if (timestamp < vesting.start) {
            return 0;
        } else if (timestamp > vesting.start + vesting.duration) {
            return vesting.amounts;
        } else {
            return (vesting.amounts * (timestamp - vesting.start)) / vesting.duration;
        }
    }
}
