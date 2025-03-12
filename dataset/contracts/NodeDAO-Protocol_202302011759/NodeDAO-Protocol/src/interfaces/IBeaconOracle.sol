// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

/**
 * @title Beacon Oracle and Dao
 *
 * BeaconOracle data acquisition and verification
 * Dao management
 */
interface IBeaconOracle {
    // verifyNftValue
    function verifyNftValue(bytes32[] memory proof, bytes memory pubkey, uint256 validatorBalance, uint256 nftTokenID)
        external
        view
        returns (bool);

    // Is a oracle member
    function isOracleMember(address oracleMember) external view returns (bool);

    function addOracleMember(address _oracleMember) external;

    function removeOracleMember(address _oracleMember) external;

    function getBeaconBalances() external view returns (uint128);

    function getBeaconValidators() external view returns (uint64);

    event AddOracleMember(address oracleMember);
    event RemoveOracleMember(address oracleMember);
    event ResetExpectedEpochId(uint256 expectedEpochId);
    event ExpectedEpochIdUpdated(uint256 expectedEpochId);
    event ResetEpochsPerFrame(uint256 epochsPerFrame);
    event ReportBeacon(uint256 epochId, address oracleMember, uint32 sameReportCount);
    event ReportSuccess(uint256 epochId, uint256 sameReportCount, uint32 quorum);
    event achieveQuorum(uint256 epochId, bool isQuorum, uint32 quorum);
}
