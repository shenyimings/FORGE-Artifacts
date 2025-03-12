//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../../src/interfaces/components/IOracleManager.1.sol";

contract RiverMock {
    event DebugReceivedCLData(
        uint256 _validatorCount, uint256 _validatorBalanceSum, bytes32 _roundId, uint256 _maxIncrease
    );

    uint256 public validatorCount;
    uint256 public validatorBalanceSum;

    function setConsensusLayerData(
        uint256 _validatorCount,
        uint256 _validatorBalanceSum,
        bytes32 _roundId,
        uint256 _maxIncrease
    ) external {
        emit DebugReceivedCLData(_validatorCount, _validatorBalanceSum, _roundId, _maxIncrease);
        validatorCount = _validatorCount;
        validatorBalanceSum = _validatorBalanceSum;
        _totalSupply = _validatorBalanceSum;
    }

    uint256 internal _totalSupply;
    uint256 internal _totalShares;

    function sudoSetTotalSupply(uint256 _newTotalSupply) external {
        _totalSupply = _newTotalSupply;
    }

    function sudoSetTotalShares(uint256 _newTotalShares) external {
        _totalShares = _newTotalShares;
    }

    function totalUnderlyingSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function totalSupply() external view returns (uint256) {
        return _totalShares;
    }

    mapping(uint256 => bool) invalidEpochs;

    function isValidEpoch(uint256 epoch) external view returns (bool) {
        return !invalidEpochs[epoch];
    }

    function sudoSetInvalidEpoch(uint256 epoch) external {
        invalidEpochs[epoch] = true;
    }

    event DebugReceivedReport(IOracleManagerV1.ConsensusLayerReport report);

    function setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport calldata report) external {
        emit DebugReceivedReport(report);
    }
}
