//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./Initializable.sol";
import "./libraries/Errors.sol";
import "./libraries/LibOwnable.sol";
import "./interfaces/IRiver.1.sol";

import "./state/shared/AdministratorAddress.sol";
import "./state/shared/RiverAddress.sol";
import "./state/oracle/OracleMembers.sol";
import "./state/oracle/Quorum.sol";
import "./state/oracle/BeaconSpec.sol";
import "./state/oracle/BeaconReportBounds.sol";
import "./state/oracle/ExpectedEpochId.sol";
import "./state/oracle/LastEpochId.sol";
import "./state/oracle/ReportsPositions.sol";
import "./state/oracle/ReportsVariants.sol";

/// @title Oracle (v1)
/// @author Kiln
/// @notice This contract handles the input from the allowed oracle members. Highly inspired by Lido's implementation.
contract OracleV1 is Initializable {
    event QuorumChanged(uint256 _newQuorum);
    event ExpectedEpochIdUpdated(uint256 _epochId);
    event BeaconReported(
        uint256 _epochId, uint128 _newBeaconBalance, uint32 _newBeaconValidatorCount, address _oracleMember
    );
    event PostTotalShares(uint256 _postTotalEth, uint256 _prevTotalEth, uint256 _timeElapsed, uint256 _totalShares);

    error EpochTooOld(uint256 _providedEpochId, uint256 _minExpectedEpochId);
    error NotFrameFirstEpochId(uint256 _providedEpochId, uint256 _expectedFrameFirstEpochId);
    error AlreadyReported(uint256 _epochId, address _member);
    error BeaconBalanceIncreaseOutOfBounds(
        uint256 _prevTotalEth, uint256 _postTotalEth, uint256 _timeElapsed, uint256 _annualAprUpperBound
    );
    error BeaconBalanceDecreaseOutOfBounds(
        uint256 _prevTotalEth, uint256 _postTotalEth, uint256 _timeElapsed, uint256 _relativeLowerBound
    );

    /// @notice Received ETH input has only 9 decimals
    uint128 internal constant DENOMINATION_OFFSET = 1e9;

    /// @notice Initializes the oracle
    /// @param _riverContractAddress Address of the River contract, able to receive oracle input data after quorum is met
    /// @param _administratorAddress Address able to call administrative methods
    /// @param _epochsPerFrame Beacon spec parameter. Number of epochs in a frame.
    /// @param _slotsPerEpoch Beacon spec parameter. Number of slots in one epoch.
    /// @param _secondsPerSlot Beacon spec parameter. Number of seconds between slots.
    /// @param _genesisTime Beacon spec parameter. Timestamp of the genesis slot.
    /// @param _annualAprUpperBound Beacon bound parameter. Maximum apr allowed for balance increase. Delta between updates is extrapolated on a year time frame.
    /// @param _relativeLowerBound Beacon bound parameter. Maximum relative balance decrease.
    function initOracleV1(
        address _riverContractAddress,
        address _administratorAddress,
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime,
        uint256 _annualAprUpperBound,
        uint256 _relativeLowerBound
    )
        external
        init(0)
    {
        LibOwnable._setAdmin(_administratorAddress);
        RiverAddress.set(_riverContractAddress);
        BeaconSpec.set(
            BeaconSpec.BeaconSpecStruct({
                epochsPerFrame: _epochsPerFrame,
                slotsPerEpoch: _slotsPerEpoch,
                secondsPerSlot: _secondsPerSlot,
                genesisTime: _genesisTime
            })
        );
        BeaconReportBounds.set(
            BeaconReportBounds.BeaconReportBoundsStruct({
                annualAprUpperBound: _annualAprUpperBound,
                relativeLowerBound: _relativeLowerBound
            })
        );
        Quorum.set(1);
    }

    /// @notice Retrieve system administrator address
    function getAdministrator() external view returns (address) {
        return LibOwnable._getAdmin();
    }

    /// @notice Retrieve River address
    function getRiver() external view returns (address) {
        return RiverAddress.get();
    }

    /// @notice Prevents unauthorized calls
    modifier onlyAdmin() {
        if (msg.sender != LibOwnable._getAdmin()) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Retrieve the block timestamp
    function getTime() external view returns (uint256) {
        return _getTime();
    }

    /// @notice Retrieve expected epoch id
    function getExpectedEpochId() external view returns (uint256) {
        return ExpectedEpochId.get();
    }

    /// @notice Retrieve member report status
    /// @param _oracleMember Address of member to check
    function getMemberReportStatus(address _oracleMember) external view returns (bool) {
        int256 memberIndex = OracleMembers.indexOf(_oracleMember);
        return ReportsPositions.get(uint256(memberIndex));
    }

    /// @notice Retrieve member report status
    function getGlobalReportStatus() external view returns (uint256) {
        return ReportsPositions.getRaw();
    }

    /// @notice Retrieve report variants count
    function getReportVariantsCount() external view returns (uint256) {
        return ReportsVariants.get().length;
    }

    /// @notice Retrieve decoded report at provided index
    /// @param _idx Index of report
    function getReportVariant(uint256 _idx)
        external
        view
        returns (uint64 _beaconBalance, uint32 _beaconValidators, uint16 _reportCount)
    {
        uint256 report = ReportsVariants.get()[_idx];
        (_beaconBalance, _beaconValidators) = _decodeReport(report);
        _reportCount = _getReportCount(report);
    }

    /// @notice Retrieve the last completed epoch id
    function getLastCompletedEpochId() external view returns (uint256) {
        return LastEpochId.get();
    }

    /// @notice Retrieve the current epoch id based on block timestamp
    function getCurrentEpochId() external view returns (uint256) {
        BeaconSpec.BeaconSpecStruct memory beaconSpec = BeaconSpec.get();
        return _getCurrentEpochId(beaconSpec);
    }

    /// @notice Retrieve the current quorum
    function getQuorum() external view returns (uint256) {
        return Quorum.get();
    }

    /// @notice Retrieve the current beacon spec
    function getBeaconSpec() external view returns (BeaconSpec.BeaconSpecStruct memory) {
        return BeaconSpec.get();
    }

    /// @notice Retrieve the current frame details
    function getCurrentFrame() external view returns (uint256 _startEpochId, uint256 _startTime, uint256 _endTime) {
        BeaconSpec.BeaconSpecStruct memory beaconSpec = BeaconSpec.get();
        _startEpochId = _getFrameFirstEpochId(_getCurrentEpochId(beaconSpec), beaconSpec);
        _startTime = beaconSpec.genesisTime + _startEpochId * beaconSpec.secondsPerSlot * beaconSpec.slotsPerEpoch;
        _endTime = _startTime + beaconSpec.secondsPerSlot * beaconSpec.slotsPerEpoch * beaconSpec.epochsPerFrame - 1;
    }

    /// @notice Retrieve the first epoch id of the frame of the provided epoch id
    /// @param _epochId Epoch id used to get the frame
    function getFrameFirstEpochId(uint256 _epochId) external view returns (uint256) {
        BeaconSpec.BeaconSpecStruct memory beaconSpec = BeaconSpec.get();
        return _getFrameFirstEpochId(_epochId, beaconSpec);
    }

    function getBeaconBounds() external view returns (BeaconReportBounds.BeaconReportBoundsStruct memory) {
        return BeaconReportBounds.get();
    }

    function getOracleMembers() external view returns (address[] memory) {
        return OracleMembers.get();
    }

    /// @notice Returns true if address is member
    /// @dev Performs a naive search, do not call this on-chain, used as an off-chain helper
    /// @param _memberAddress Address of the member
    function isMember(address _memberAddress) external view returns (bool) {
        address[] memory members = OracleMembers.get();
        for (uint256 idx = 0; idx < members.length;) {
            if (members[idx] == _memberAddress) {
                return true;
            }
            unchecked {
                ++idx;
            }
        }
        return false;
    }

    /// @notice Adds new address as oracle member, giving the ability to push beacon reports.
    /// @dev Only callable by the adminstrator
    /// @param _newOracleMember Address of the new member
    function addMember(address _newOracleMember) external onlyAdmin {
        int256 memberIdx = OracleMembers.indexOf(_newOracleMember);
        if (memberIdx >= 0) {
            revert Errors.InvalidCall();
        }
        OracleMembers.push(_newOracleMember);
    }

    /// @notice Removes an address from the oracle members.
    /// @dev Only callable by the adminstrator
    /// @param _oracleMember Address to remove
    function removeMember(address _oracleMember) external onlyAdmin {
        int256 memberIdx = OracleMembers.indexOf(_oracleMember);
        if (memberIdx < 0) {
            revert Errors.InvalidCall();
        }
        OracleMembers.deleteItem(uint256(memberIdx));
    }

    /// @notice Edits the beacon spec parameters
    /// @dev Only callable by the adminstrator
    /// @param _epochsPerFrame Number of epochs in a frame.
    /// @param _slotsPerEpoch Number of slots in one epoch.
    /// @param _secondsPerSlot Number of seconds between slots.
    /// @param _genesisTime Timestamp of the genesis slot.
    function setBeaconSpec(uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime)
        external
        onlyAdmin
    {
        BeaconSpec.set(
            BeaconSpec.BeaconSpecStruct({
                epochsPerFrame: _epochsPerFrame,
                slotsPerEpoch: _slotsPerEpoch,
                secondsPerSlot: _secondsPerSlot,
                genesisTime: _genesisTime
            })
        );
    }

    /// @notice Edits the beacon bounds parameters
    /// @dev Only callable by the adminstrator
    /// @param _annualAprUpperBound Maximum apr allowed for balance increase. Delta between updates is extrapolated on a year time frame.
    /// @param _relativeLowerBound Maximum relative balance decrease.
    function setBeaconBounds(uint256 _annualAprUpperBound, uint256 _relativeLowerBound) external onlyAdmin {
        BeaconReportBounds.set(
            BeaconReportBounds.BeaconReportBoundsStruct({
                annualAprUpperBound: _annualAprUpperBound,
                relativeLowerBound: _relativeLowerBound
            })
        );
    }

    /// @notice Edits the quorum required to forward beacon data to River
    /// @dev Only callable by the adminstrator
    /// @param _newQuorum New quorum parameter
    function setQuorum(uint256 _newQuorum) external onlyAdmin {
        if (_newQuorum == 0) {
            revert Errors.InvalidArgument();
        }
        uint256 previousQuorum = Quorum.get();
        if (_newQuorum == previousQuorum) {
            revert Errors.InvalidCall();
        }
        Quorum.set(_newQuorum);
        emit QuorumChanged(_newQuorum);
        if (previousQuorum > _newQuorum) {
            (bool isQuorum, uint256 report) = _getQuorumReport(_newQuorum);
            if (isQuorum) {
                (uint64 beaconBalance, uint32 beaconValidators) = _decodeReport(report);
                _pushToRiver(
                    ExpectedEpochId.get(),
                    DENOMINATION_OFFSET * uint128(beaconBalance),
                    beaconValidators,
                    BeaconSpec.get()
                );
            }
        }
    }

    /// @notice Report beacon chain data
    /// @dev Only callable by an oracle member
    /// @param _epochId Epoch where the balance and validator count has been computed
    /// @param _beaconBalance Total balance of River validators
    /// @param _beaconValidators Total River validator count
    function reportBeacon(uint256 _epochId, uint64 _beaconBalance, uint32 _beaconValidators) external {
        BeaconSpec.BeaconSpecStruct memory beaconSpec = BeaconSpec.get();
        uint256 expectedEpochId = ExpectedEpochId.get();
        if (_epochId < expectedEpochId) {
            revert EpochTooOld(_epochId, expectedEpochId);
        }

        if (_epochId > expectedEpochId) {
            uint256 frameFirstEpochId = _getFrameFirstEpochId(_getCurrentEpochId(beaconSpec), beaconSpec);
            if (_epochId != frameFirstEpochId) {
                revert NotFrameFirstEpochId(_epochId, frameFirstEpochId);
            }
            _clearReporting(_epochId);
        }

        uint128 beaconBalanceEth1 = DENOMINATION_OFFSET * uint128(_beaconBalance);
        emit BeaconReported(_epochId, beaconBalanceEth1, _beaconValidators, msg.sender);

        int256 memberIndex = OracleMembers.indexOf(msg.sender);
        if (memberIndex == -1) {
            revert Errors.Unauthorized(msg.sender);
        }
        if (ReportsPositions.get(uint256(memberIndex))) {
            revert AlreadyReported(_epochId, msg.sender);
        }
        ReportsPositions.register(uint256(memberIndex));

        uint256 report = _encodeReport(_beaconBalance, _beaconValidators);
        int256 reportIndex = ReportsVariants.indexOfReport(report);
        uint256 quorum = Quorum.get();

        if (reportIndex >= 0) {
            uint256 registeredReport = ReportsVariants.get()[uint256(reportIndex)];
            if (_getReportCount(registeredReport) + 1 >= quorum) {
                _pushToRiver(_epochId, beaconBalanceEth1, _beaconValidators, beaconSpec);
            } else {
                ReportsVariants.set(uint256(reportIndex), registeredReport + 1);
            }
        } else {
            if (quorum == 1) {
                _pushToRiver(_epochId, beaconBalanceEth1, _beaconValidators, beaconSpec);
            } else {
                ReportsVariants.push(report + 1);
            }
        }
    }

    /// @notice Retrieve the report that has the highest number of "votes"
    /// @param _quorum The quorum used for the query
    function _getQuorumReport(uint256 _quorum) internal view returns (bool isQuorum, uint256 report) {
        // check most frequent cases first: all reports are the same or no reports yet
        uint256[] memory variants = ReportsVariants.get();
        if (variants.length == 1) {
            return (_getReportCount(variants[0]) >= _quorum, variants[0]);
        } else if (variants.length == 0) {
            return (false, 0);
        }

        // if more than 2 kind of reports exist, choose the most frequent
        uint256 maxind = 0;
        uint256 repeat = 0;
        uint16 maxval = 0;
        uint16 cur = 0;
        for (uint256 i = 0; i < variants.length;) {
            cur = _getReportCount(variants[i]);
            if (cur >= maxval) {
                if (cur == maxval) {
                    unchecked {
                        ++repeat;
                    }
                } else {
                    maxind = i;
                    maxval = cur;
                    repeat = 0;
                }
            }
            unchecked {
                ++i;
            }
        }
        return (maxval >= _quorum && repeat == 0, variants[maxind]);
    }

    /// @notice Retrieve the block timestamp
    function _getTime() internal view returns (uint256) {
        return block.timestamp; // solhint-disable-line not-rely-on-time
    }

    /// @notice Retrieve the current epoch id based on block timestamp
    /// @param _beaconSpec Beacon spec parameters
    function _getCurrentEpochId(BeaconSpec.BeaconSpecStruct memory _beaconSpec) internal view returns (uint256) {
        return (_getTime() - _beaconSpec.genesisTime) / (_beaconSpec.slotsPerEpoch * _beaconSpec.secondsPerSlot);
    }

    /// @notice Retrieve the first epoch id of the frame of the provided epoch id
    /// @param _epochId Epoch id used to get the frame
    /// @param _beaconSpec Beacon spec parameters
    function _getFrameFirstEpochId(uint256 _epochId, BeaconSpec.BeaconSpecStruct memory _beaconSpec)
        internal
        pure
        returns (uint256)
    {
        return (_epochId / _beaconSpec.epochsPerFrame) * _beaconSpec.epochsPerFrame;
    }

    /// @notice Clear reporting data
    /// @param _epochId Next expected epoch id (first epoch of the next frame)
    function _clearReporting(uint256 _epochId) internal {
        ReportsPositions.clear();
        ReportsVariants.clear();
        ExpectedEpochId.set(_epochId);
        emit ExpectedEpochIdUpdated(_epochId);
    }

    /// @notice Encode report into one slot. Last 16 bits are free to use for vote counting.
    /// @param _beaconBalance Total validator balance
    /// @param _beaconValidators Total validator count
    function _encodeReport(uint64 _beaconBalance, uint32 _beaconValidators) internal pure returns (uint256) {
        return (uint256(_beaconBalance) << 48) | (uint256(_beaconValidators) << 16);
    }

    /// @notice Decode report from one slot to two variables, ignoring the last 16 bits
    /// @param _value Encoded report
    function _decodeReport(uint256 _value) internal pure returns (uint64 _beaconBalance, uint32 _beaconValidators) {
        _beaconBalance = uint64(_value >> 48);
        _beaconValidators = uint32(_value >> 16);
    }

    /// @notice Retrieve the vote count from the encoded report (last 16 bits)
    /// @param _report Encoded report
    function _getReportCount(uint256 _report) internal pure returns (uint16) {
        return uint16(_report);
    }

    /// @notice Performs sanity checks to prevent an erroneous update to the River system
    /// @param _postTotalEth Total validator balance after update
    /// @param _prevTotalEth Total validator balance before update
    /// @param _timeElapsed Time since last update
    function _sanityChecks(uint256 _postTotalEth, uint256 _prevTotalEth, uint256 _timeElapsed) internal view {
        if (_postTotalEth >= _prevTotalEth) {
            // increase                 = _postTotalPooledEther - _preTotalPooledEther,
            // relativeIncrease         = increase / _preTotalPooledEther,
            // annualRelativeIncrease   = relativeIncrease / (timeElapsed / 365 days),
            // annualRelativeIncreaseBp = annualRelativeIncrease * 10000, in basis points 0.01% (1e-4)
            uint256 annualAprUpperBound = BeaconReportBounds.get().annualAprUpperBound;
            // check that annualRelativeIncreaseBp <= allowedAnnualRelativeIncreaseBp
            if (
                uint256(10000 * 365 days) * (_postTotalEth - _prevTotalEth)
                    > annualAprUpperBound * _prevTotalEth * _timeElapsed
            ) {
                revert BeaconBalanceIncreaseOutOfBounds(_prevTotalEth, _postTotalEth, _timeElapsed, annualAprUpperBound);
            }
        } else {
            // decrease           = _preTotalPooledEther - _postTotalPooledEther
            // relativeDecrease   = decrease / _preTotalPooledEther
            // relativeDecreaseBp = relativeDecrease * 10000, in basis points 0.01% (1e-4)
            uint256 relativeLowerBound = BeaconReportBounds.get().relativeLowerBound;
            // check that relativeDecreaseBp <= allowedRelativeDecreaseBp
            if (uint256(10000) * (_prevTotalEth - _postTotalEth) > relativeLowerBound * _prevTotalEth) {
                revert BeaconBalanceDecreaseOutOfBounds(_prevTotalEth, _postTotalEth, _timeElapsed, relativeLowerBound);
            }
        }
    }

    /// @notice Push the new beacon data to the river system and performs sanity checks
    /// @param _epochId Id of the epoch
    /// @param _balanceSum Total validator balance
    /// @param _validatorCount Total validator count
    /// @param _beaconSpec Beacon spec parameters
    function _pushToRiver(
        uint256 _epochId,
        uint128 _balanceSum,
        uint32 _validatorCount,
        BeaconSpec.BeaconSpecStruct memory _beaconSpec
    )
        internal
    {
        _clearReporting(_epochId + _beaconSpec.epochsPerFrame);

        IRiverV1 riverAddress = IRiverV1(payable(RiverAddress.get()));
        uint256 prevTotalEth = IRiverV1(payable(address(riverAddress))).totalUnderlyingSupply();
        riverAddress.setBeaconData(_validatorCount, _balanceSum, bytes32(_epochId));
        uint256 postTotalEth = IRiverV1(payable(address(riverAddress))).totalUnderlyingSupply();

        uint256 timeElapsed = (_epochId - LastEpochId.get()) * _beaconSpec.slotsPerEpoch * _beaconSpec.secondsPerSlot;

        _sanityChecks(postTotalEth, prevTotalEth, timeElapsed);
        LastEpochId.set(_epochId);

        emit PostTotalShares(
            postTotalEth, prevTotalEth, timeElapsed, IRiverV1(payable(address(riverAddress))).totalSupply()
            );
    }
}
