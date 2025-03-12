// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Token.sol";

struct VestingDetail {
    //Vestor address
    address beneficiary;
    // Amount to be vested.
    uint256 vestingAmount;
    // Vesting duration, after cliff.
    uint256 duration;
    // Amount already claimed by beneficiary.
    uint256 claimedAmount;
    // Time at which beneficiary last claimed.
    uint256 lastClaimedTime;
    // Initial amount to be claimed, included in vestingAmount.
    uint256 initialAmount;
    // Whether the initialAmount value was claimed.
    bool initialClaimed;
    // Time at which vesting begins.
    uint256 claimStartTime;
    // Bool for beneficiary exist or not.
    bool exists;
}

/// @title A vestion contract for emploees and partners.
contract TeamVesting is Ownable {
    using SafeERC20 for ERC20;

    address public immutable self;
    address public immutable RITE;
    uint256 public startDate;
    uint256 public totalClaimed;
    uint256 public totalVestingAmount = 0;
    //Maximun number of vesting detail array.
    uint256 private constant maxVestingDetailArray = 20;

    //If the current owner wants to renounceOwnership, it will always be to this address
    address private constant fixedOwnerAddress =
        0x1156B992b1117a1824272e31797A2b88f8a7c729;

    constructor(address _RITE, uint256 _startDate) {
        //Vesting start date
        require(
            _startDate >= block.timestamp,
            "Start date cannot be before the deployment date"
        );
        require(_RITE != address(0), "Address cannot be zero");
        self = address(this);
        RITE = _RITE;
        startDate = _startDate;
    }

    // Vesting detail list
    mapping(address => VestingDetail) internal vestingDetails;

    /// @dev Allow owner to set user's vesting struct
    /// @param _vestingDetails A list of user's vesting
    function setTeamVesting(VestingDetail[] memory _vestingDetails)
        external
        onlyOwner
    {
        uint256 count = _vestingDetails.length;

        //At least one vesting detail is required.
        require(count > 0, "No vesting details provided");

        //Check on the maximum size over which the for loop will run over.
        require(count <= maxVestingDetailArray, "Vesting detail array is full");

        for (uint256 i = 0; i < count; i++) {
            address beneficiary = _vestingDetails[i].beneficiary;
            require(
                beneficiary != address(0),
                "Beneficiary address cannot be zero"
            );
            //Check if beneficiary already has a vesting
            require(
                vestingDetails[beneficiary].vestingAmount == 0,
                "Vesting already exists for beneficiary"
            );
            require(
                beneficiary != owner() && beneficiary != self,
                "Beneficiary is not allowed to be owner or self"
            );
            //New vesting amount must be greater than 0
            require(
                _vestingDetails[i].vestingAmount > 0,
                "Beneficiary has no vesting amount"
            );
            //New vesting duration must be greater than 0
            require(
                _vestingDetails[i].duration > 0,
                "beneficiary has no duration"
            );
            //New vesting cliam start time must be in the future
            require(
                _vestingDetails[i].claimStartTime > block.timestamp,
                "Beneficiary has no claimStartTime"
            );
            //New vesting initial claimed amount must be 0,indicating that they have never claimed
            require(
                _vestingDetails[i].claimedAmount == 0,
                "Claimed amount is not valid"
            );
            //New vesting initial last claimed amount must be 0
            require(
                _vestingDetails[i].lastClaimedTime == 0,
                "Last claimed time is not valid"
            );
            //New vesting initial amount must be greater than 0
            require(
                _vestingDetails[i].initialAmount > 0,
                "Initial amount is not valid"
            );
            //New vesting initial claimed amount must be false
            require(
                !_vestingDetails[i].initialClaimed,
                "Initial claimed can not be true"
            );

            vestingDetails[beneficiary] = VestingDetail(
                beneficiary,
                _vestingDetails[i].vestingAmount,
                _vestingDetails[i].duration,
                _vestingDetails[i].claimedAmount,
                _vestingDetails[i].lastClaimedTime,
                _vestingDetails[i].initialAmount,
                _vestingDetails[i].initialClaimed,
                _vestingDetails[i].claimStartTime,
                true
            );

            totalVestingAmount += _vestingDetails[i].vestingAmount;

            emit Vested(beneficiary, _vestingDetails[i].vestingAmount);
        }
    }

    function claim() external {
        require(
            startDate != 0 && block.timestamp > startDate,
            "Vesting period has not started"
        );
        address beneficiary = msg.sender;
        require(
            vestingDetails[beneficiary].vestingAmount > 0,
            "Vesting does not exist"
        );
        require(
            vestingDetails[beneficiary].exists,
            "Beneficiary has terminated"
        );
        require(
            block.timestamp > vestingDetails[beneficiary].claimStartTime,
            "Claiming period has not started"
        );
        require(
            vestingDetails[beneficiary].claimedAmount <
                vestingDetails[beneficiary].vestingAmount,
            "You have already claimed your vesting amount"
        );

        uint256 amountToClaim = 0;

        uint256 lastClaimedTime = vestingDetails[beneficiary].lastClaimedTime;

        if (
            !vestingDetails[beneficiary].initialClaimed &&
            vestingDetails[beneficiary].initialAmount > 0
        ) {
            amountToClaim += vestingDetails[beneficiary].initialAmount;
            vestingDetails[beneficiary].initialClaimed = true;
        }

        if (lastClaimedTime == 0)
            lastClaimedTime = vestingDetails[beneficiary].claimStartTime;

        amountToClaim +=
            ((block.timestamp - lastClaimedTime) *
                (vestingDetails[beneficiary].vestingAmount -
                    vestingDetails[beneficiary].initialAmount)) /
            vestingDetails[beneficiary].duration;

        // In case the last claim amount is greater than the remaining amount
        if (
            amountToClaim >
            vestingDetails[beneficiary].vestingAmount -
                vestingDetails[beneficiary].claimedAmount
        )
            amountToClaim =
                vestingDetails[beneficiary].vestingAmount -
                vestingDetails[beneficiary].claimedAmount;

        totalClaimed += amountToClaim;

        vestingDetails[beneficiary].claimedAmount += amountToClaim;
        vestingDetails[beneficiary].lastClaimedTime = block.timestamp;
        ERC20(RITE).safeTransfer(beneficiary, amountToClaim);

        emit Claimed(beneficiary, amountToClaim);
    }

    /// @dev Get beneficiary's vesting struct
    /// @param beneficiary Beneficiary address
    /// @return beneficiary's vesting struct
    function getBeneficiaryVesting(address beneficiary)
        external
        view
        returns (VestingDetail memory)
    {
        return vestingDetails[beneficiary];
    }

    /// @dev Allow owner to terminate beneficiary's vesting
    /// @param beneficiary Address of beneficiary whose vesting should be terminated
    function terminateNow(address beneficiary) external onlyOwner {
        //Check if beneficiary has a vesting
        require(
            vestingDetails[beneficiary].vestingAmount > 0,
            "Vesting does not exist"
        );
        //check if beneficiary exist
        require(
            vestingDetails[beneficiary].exists,
            "Beneficiary is already terminated"
        );
        vestingDetails[beneficiary].exists = false;

        emit Terminated(beneficiary);
    }

    /// @dev Allow owner to change the start date of the vesting period
    /// @param _startDate A date for the vesting to start
    function setStartDate(uint256 _startDate) external onlyOwner {
        require(_startDate > block.timestamp, "Start date is in the past");
        startDate = _startDate;
    }

    /// @dev Event for terminate beneficiary
    /// @param beneficiary a beneficiary address
    event Terminated(address indexed beneficiary);

    /// @dev event when beneficiary claim tokens
    /// @param beneficiary a beneficiary address
    /// @param amount a claimed amount
    event Claimed(address indexed beneficiary, uint256 amount);

    /// @dev event when beneficiary's vesting detail been set
    /// @param beneficiary a beneficiary address
    /// @param amount a claimed amount
    event Vested(address indexed beneficiary, uint256 amount);

    /// @dev Override renounceOwnership to transfer ownership to a fixed address, make sure contract owner will never be address(0)
    function renounceOwnership() public override onlyOwner {
        _transferOwnership(fixedOwnerAddress);
    }
}
