//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

contract RiverMock {
    event DebugReceivedBeaconData(uint256 _validatorCount, uint256 _validatorBalanceSum, bytes32 _roundId);

    uint256 public validatorCount;
    uint256 public validatorBalanceSum;

    function setBeaconData(uint256 _validatorCount, uint256 _validatorBalanceSum, bytes32 _roundId) external {
        emit DebugReceivedBeaconData(_validatorCount, _validatorBalanceSum, _roundId);
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
}
