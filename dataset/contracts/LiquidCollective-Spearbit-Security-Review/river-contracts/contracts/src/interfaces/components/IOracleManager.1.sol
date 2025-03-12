//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IOracleManagerV1 {
    event BeaconDataUpdate(uint256 validatorCount, uint256 validatorBalanceSum, bytes32 roundId);

    error InvalidValidatorCountReport(uint256 _providedValidatorCount, uint256 _depositedValidatorCount);

    function setBeaconData(uint256 _validatorCount, uint256 _validatorBalanceSum, bytes32 _roundId) external;
    function getOracle() external view returns (address oracle);
    function setOracle(address _oracleAddress) external;
    function getBeaconValidatorBalanceSum() external view returns (uint256 beaconValidatorBalanceSum);
    function getBeaconValidatorCount() external view returns (uint256 beaconValidatorCount);
}
