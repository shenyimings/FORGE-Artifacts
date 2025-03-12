// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

contract MockCPIOracle {
    uint256 private _report;
    bool private _valid;

    function mockData(uint256 report, bool valid) external {
        _report = report;
        _valid = valid;
    }

    function getData() external view returns (uint256, bool) {
        return (_report, _valid);
    }

    // solhint-disable-next-line func-name-mixedcase
    function DECIMALS() public pure returns (uint8) {
        return 18;
    }
}
