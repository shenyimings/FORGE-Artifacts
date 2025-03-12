/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SuperfineVesting is Ownable, Pausable, ReentrancyGuard {
    struct Program {
        uint256 id;
        string metadata;
        uint256 startRegistration;
        uint256 endRegistration;
        uint256 allocationAmount;
        uint256 availableAmount;
        uint256 tgeUnlockPercentage;
        uint256 unlockMoment;
        uint256 unlockDistance;
        uint256 milestoneUnlockPercentage;
        address[] participants;
    }

    struct VestingInfo {
        uint256 totalClaimedAmount;
        uint256 removedMoment;
        mapping(uint256 => uint256) totalAtProgram;
        mapping(uint256 => uint256) claimedAtProgram;
        mapping(uint256 => bool) isInvestorAtProgram;
    }

    uint256 public TGE;
    Program[] private _allPrograms;
    mapping(address => bool) private _operators;
    mapping(address => VestingInfo) private _vestingInfoOf;

    event ProgramCreated(
        uint256 id,
        string metadata,
        uint256 startRegistration,
        uint256 endRegistration,
        uint256 initialAmount,
        uint256 tgeUnlockPercentage,
        uint256 unlockMoment,
        uint256 unlockDistance,
        uint256 milestoneUnlockPercentage
    );
    event MetadataUpdated(uint256 programId, string metadata);
    event ParticipantRegistered(
        address participant,
        uint256 programId,
        uint256 amount
    );
    event ClaimSuccessful(
        address participant,
        uint256 programId,
        uint256 amount
    );
    event EmergencyWithdrawn(address recipient, uint256 amount);

    constructor() Ownable() {
        _operators[msg.sender] = true;
    }

    receive() external payable {}

    modifier onlyOperator() {
        require(
            _operators[msg.sender],
            "SuperfineVesting: caller is not operator"
        );
        _;
    }

    function numPrograms() external view returns (uint256) {
        return _allPrograms.length;
    }

    function getProgramsInfo() external view returns (Program[] memory) {
        return _allPrograms;
    }

    function getVestingAmount(
        address participant,
        uint256 programId
    ) external view returns (uint256) {
        return _vestingInfoOf[participant].totalAtProgram[programId];
    }

    function getTotalVestingAmount(
        address participant
    ) external view returns (uint256) {
        uint256 totalVestingAmount = 0;
        for (uint256 i = 0; i < _allPrograms.length; i++)
            totalVestingAmount += _vestingInfoOf[participant].totalAtProgram[i];
        return totalVestingAmount;
    }

    function getClaimedAmount(
        address participant,
        uint256 programId
    ) external view returns (uint256) {
        return _vestingInfoOf[participant].claimedAtProgram[programId];
    }

    function getTotalClaimedAmount(
        address participant
    ) external view returns (uint256) {
        return _vestingInfoOf[participant].totalClaimedAmount;
    }

    function getClaimableAmount(
        address participant,
        uint256 programId
    ) public view returns (uint256) {
        if (programId >= _allPrograms.length) return 0;
        if (TGE == 0) return 0;
        uint256 programUnlockedAmount = 0;
        uint256 lastMoment = block.timestamp;
        if (_vestingInfoOf[participant].removedMoment > 0)
            lastMoment = _vestingInfoOf[participant].removedMoment;
        uint256 vestingAmount = _vestingInfoOf[participant].totalAtProgram[
            programId
        ];
        if (vestingAmount > 0) {
            Program memory program = _allPrograms[programId];
            if (lastMoment >= TGE)
                programUnlockedAmount +=
                    (vestingAmount * program.tgeUnlockPercentage) /
                    10000;
            if (lastMoment >= program.unlockMoment) {
                uint256 numUnlockTimes = (lastMoment - program.unlockMoment) /
                    program.unlockDistance +
                    1;
                programUnlockedAmount +=
                    (vestingAmount *
                        program.milestoneUnlockPercentage *
                        numUnlockTimes) /
                    10000;
            }
            if (programUnlockedAmount > vestingAmount)
                programUnlockedAmount = vestingAmount;
        }
        return
            programUnlockedAmount -
            _vestingInfoOf[participant].claimedAtProgram[programId];
    }

    function getTotalClaimableAmount(
        address participant
    ) external view returns (uint256) {
        uint256 totalClaimableAmount = 0;
        for (uint256 i = 0; i < _allPrograms.length; i++)
            totalClaimableAmount += getClaimableAmount(participant, i);
        return totalClaimableAmount;
    }

    function setOperators(
        address[] memory operators,
        bool[] memory isOperators
    ) external onlyOwner {
        require(
            operators.length == isOperators.length,
            "SuperfineVesting: lengths mismatch"
        );
        for (uint256 i = 0; i < operators.length; i++)
            _operators[operators[i]] = isOperators[i];
    }

    function updateMetadata(
        uint256 programId,
        string calldata newMetadata
    ) external onlyOperator {
        require(
            programId < _allPrograms.length,
            "SuperfineVesting: program does not exist"
        );
        _allPrograms[programId].metadata = newMetadata;
    }

    function createPrograms(
        uint256 TGE_,
        string[] memory metadatas,
        uint256[] memory startRegistrations,
        uint256[] memory endRegistrations,
        uint256[] memory initialAmounts,
        uint256[] memory tgeUnlockPercentages,
        uint256[] memory unlockMoments,
        uint256[] memory unlockDistances,
        uint256[] memory milestoneUnlockPercentages
    ) external onlyOperator {
        require(
            metadatas.length == startRegistrations.length &&
                metadatas.length == endRegistrations.length &&
                metadatas.length == initialAmounts.length &&
                metadatas.length == tgeUnlockPercentages.length &&
                metadatas.length == unlockMoments.length &&
                metadatas.length == unlockDistances.length &&
                metadatas.length == milestoneUnlockPercentages.length,
            "SuperfineVesting: lengths mismatch"
        );
        if (TGE == 0) {
            require(TGE_ > 0, "SuperfineVesting: TGE must be real moment");
            TGE = TGE_;
        } else require(TGE_ == TGE, "SuperfineVesting: wrong TGE moment");
        address[] memory participants;
        for (uint256 i = 0; i < metadatas.length; i++) {
            require(
                unlockMoments[i] >= TGE,
                "SuperfineVesting: TGE must not happen after unlock moment"
            );
            require(
                tgeUnlockPercentages[i] + milestoneUnlockPercentages[i] <=
                    10000,
                "SuperfineVesting: unlock percentages cannot exceed 100%"
            );
            uint256 id = _allPrograms.length;
            _allPrograms.push(
                Program(
                    id,
                    metadatas[i],
                    startRegistrations[i],
                    endRegistrations[i],
                    initialAmounts[i],
                    initialAmounts[i],
                    tgeUnlockPercentages[i],
                    unlockMoments[i],
                    unlockDistances[i],
                    milestoneUnlockPercentages[i],
                    participants
                )
            );
            emit ProgramCreated(
                id,
                metadatas[i],
                startRegistrations[i],
                endRegistrations[i],
                initialAmounts[i],
                tgeUnlockPercentages[i],
                unlockMoments[i],
                unlockDistances[i],
                milestoneUnlockPercentages[i]
            );
        }
    }

    function registerParticipant(
        address participant,
        uint256 programId,
        bool isInvestor
    ) external payable onlyOperator {
        require(
            participant != address(0),
            "SuperfineVesting: register the zero address"
        );
        require(
            programId < _allPrograms.length,
            "SuperfineVesting: program does not exist"
        );
        Program storage program = _allPrograms[programId];
        require(
            block.timestamp >= program.startRegistration,
            "SuperfineVesting: program is not available"
        );
        require(
            block.timestamp <= program.endRegistration,
            "SuperfineVesting: program is over"
        );
        require(
            msg.value <= program.availableAmount,
            "SuperfineVesting: available amount not enough"
        );
        _vestingInfoOf[participant].isInvestorAtProgram[programId] = isInvestor;
        _vestingInfoOf[participant].totalAtProgram[programId] += msg.value;
        program.availableAmount -= msg.value;
        bool addedBefore = false;
        for (uint256 i = 0; i < program.participants.length; i++)
            if (program.participants[i] == participant) {
                addedBefore = true;
                break;
            }
        if (!addedBefore) program.participants.push(participant);
        emit ParticipantRegistered(participant, programId, msg.value);
    }

    function removeParticipant(
        address participant,
        uint256 programId
    ) external onlyOperator {
        require(
            !_vestingInfoOf[participant].isInvestorAtProgram[programId],
            "SuperfineVesting: cannot remove an investor"
        );
        require(
            _vestingInfoOf[participant].removedMoment == 0,
            "SuperfineVesting: participant already removed"
        );
        _vestingInfoOf[participant].removedMoment = block.timestamp;
        Program storage program = _allPrograms[programId];
        for (uint256 i = program.participants.length - 1; i >= 0; i--) {
            if (program.participants[i] == participant) {
                uint256 length = program.participants.length;
                program.participants[i] = program.participants[length - 1];
                program.participants.pop();
            }
            if (i == 0) break;
        }
    }

    function claimTokens(uint256 programId) public whenNotPaused {
        uint256 claimableAmount = getClaimableAmount(msg.sender, programId);
        _vestingInfoOf[msg.sender].totalClaimedAmount += claimableAmount;
        _vestingInfoOf[msg.sender].claimedAtProgram[
            programId
        ] += claimableAmount;
        (bool success, ) = payable(msg.sender).call{value: claimableAmount}("");
        require(success, "SuperfineVesting: claim tokens failed");
        emit ClaimSuccessful(msg.sender, programId, claimableAmount);
    }

    function claimAllTokens() external whenNotPaused nonReentrant {
        for (uint256 i = 0; i < _allPrograms.length; i++) {
            VestingInfo storage vestingInfo = _vestingInfoOf[msg.sender];
            if (vestingInfo.totalAtProgram[i] > vestingInfo.claimedAtProgram[i])
                claimTokens(i);
        }
    }

    function pause() external onlyOperator {
        _pause();
    }

    function unpause() external onlyOperator {
        _unpause();
    }

    function emergencyWithdraw(
        address payable recipient
    ) external onlyOwner whenPaused {
        uint256 amount = address(this).balance;
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "SuperfineVesting: emergency withdraw failed");
        emit EmergencyWithdrawn(recipient, amount);
    }
}
