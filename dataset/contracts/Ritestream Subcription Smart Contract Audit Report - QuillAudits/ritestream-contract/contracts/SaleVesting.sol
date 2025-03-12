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
    uint256 initialAmount; // still waiting for requirement to be finalized
    // Whether the initialAmount value was claimed.
    bool initialClaimed;
    // Time at which vesting begins.
    uint256 claimStartTime;
}

// Client's requirement not yet finalized, still waiting.
contract SaleVesting2 is Ownable {
    using SafeERC20 for ERC20;

    address public immutable self;
    address public immutable RITE;
    uint256 public TGEDate;
    uint256 public totalClaimed;
    uint256 public totalVestingAmount = 0;
    //Maximun number of vesting detail array.
    uint256 private constant maxVestingDetailArray = 20;

    event SetTGEDate(uint256 date);

    //This address is used for if current owner want to renounceOwnership, it will always be the same address
    address private constant fixedOwnerAddress =
        0x1156B992b1117a1824272e31797A2b88f8a7c729;

    constructor(address _RITE, uint256 _TGEDate) {
        require(
            _TGEDate >= block.timestamp,
            "TGE cannot be before the deployment date"
        );
        require(_RITE != address(0), "Address cannot be zero");
        TGEDate = _TGEDate;
        self = address(this);
        RITE = _RITE;
    }

    mapping(address => VestingDetail) internal vestingDetails;

    /**
     * @dev Allow owner set user's vesting struct
     * @param _vestingDetails A list of beneficiary's vesting.
     */

    function setVesting(VestingDetail[] calldata _vestingDetails)
        external
        onlyOwner
    {
        uint256 count = _vestingDetails.length;
        //At least one vesting detail is required.
        require(count > 0, "No vesting list provided");
        require(
            block.timestamp < TGEDate,
            "TGE already finished, no more vesting"
        );

        //Check on the maximun size over which the for loop will run over.
        require(count <= maxVestingDetailArray, "Too many vesting details");

        for (uint256 i = 0; i < count; i++) {
            address beneficiary = _vestingDetails[i].beneficiary;
            require(
                beneficiary != owner() && beneficiary != address(0),
                "Beneficiary address is not valid"
            );
            //Check if beneficiary already has a vesting
            require(
                vestingDetails[beneficiary].vestingAmount == 0,
                "Vesting already exists"
            );
            //Beneficiary's vesting amount must be greater than 0
            require(
                _vestingDetails[i].vestingAmount > 0,
                "Vesting amount is not valid"
            );
            //Vesting duration must be greater than 0
            require(_vestingDetails[i].duration > 0, "Duration is not valid");
            //New beneficiary's initial claimed amount must be 0
            require(
                _vestingDetails[i].claimedAmount == 0,
                "Claimed amount is not valid"
            );
            //New beneficiary's last claimed time must be 0,indicating that they have never claimed
            require(
                _vestingDetails[i].lastClaimedTime == 0,
                "Last claimed time is not valid"
            );
            //New beneficiary's initial amount must be greater than 0
            require(
                _vestingDetails[i].initialAmount > 0,
                "TGE initial release amount is not valid"
            );
            //New beneficiary's initial claimed must be false
            require(
                _vestingDetails[i].initialClaimed == false,
                "Initial claimed is not valid"
            );
            //New beneficiary's claim start time must be not be before TGE date
            require(
                _vestingDetails[i].claimStartTime >= TGEDate,
                "Claim start time is not valid"
            );

            vestingDetails[beneficiary] = VestingDetail(
                beneficiary,
                _vestingDetails[i].vestingAmount,
                _vestingDetails[i].duration,
                _vestingDetails[i].claimedAmount,
                _vestingDetails[i].lastClaimedTime,
                _vestingDetails[i].initialAmount,
                _vestingDetails[i].initialClaimed,
                _vestingDetails[i].claimStartTime
            );

            totalVestingAmount += _vestingDetails[i].vestingAmount;

            emit Vested(beneficiary, _vestingDetails[i].vestingAmount);
        }
    }

    /**
     * @dev Allow user to claim token from vesting after TGE.
     */
    function claim() external {
        address beneficiary = msg.sender;
        //TGE date must be must be in the past but not 0
        require(
            TGEDate > 0 && block.timestamp >= TGEDate,
            "Claim is not allowed before TGE start"
        );
        //Beneficiary must have a vesting amount
        require(
            vestingDetails[beneficiary].vestingAmount > 0,
            "Vesting does not exist"
        );
        //Beneficiary must have not claimed all of their vesting amount
        require(
            vestingDetails[beneficiary].claimedAmount <
                vestingDetails[beneficiary].vestingAmount,
            "You have already claimed your vested amount"
        );

        uint256 amountToClaim = 0;

        // if initial claim is not done, claim initial amount + linear amount
        if (
            !vestingDetails[beneficiary].initialClaimed &&
            vestingDetails[beneficiary].initialAmount > 0
        ) {
            amountToClaim += vestingDetails[beneficiary].initialAmount;
            vestingDetails[beneficiary].initialClaimed = true;
        }

        // Check that block is after the cliff period.
        if (block.timestamp >= vestingDetails[beneficiary].claimStartTime) {
            uint256 lastClaimedTime = vestingDetails[beneficiary]
                .lastClaimedTime;
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
        }

        vestingDetails[beneficiary].lastClaimedTime = block.timestamp;
        vestingDetails[beneficiary].claimedAmount += amountToClaim;
        totalClaimed += amountToClaim;
        ERC20(RITE).safeTransfer(beneficiary, amountToClaim);

        emit Claimed(beneficiary, amountToClaim);
    }

    /**
     * @dev Get beneficiary's vesting detail
     */
    function getBeneficiaryVesting(address _beneficiary)
        external
        view
        returns (VestingDetail memory)
    {
        return vestingDetails[_beneficiary];
    }

    /**
     * @dev Allow owner to set TGE date
     * @param _date  The date of the TGE
     */
    function setTGEDate(uint256 _date) external onlyOwner {
        require(_date > block.timestamp, "TGE date is not valid");
        TGEDate = _date;
        emit SetTGEDate(TGEDate);
    }

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
