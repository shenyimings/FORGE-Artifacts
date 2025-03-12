// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '../OpenSkyLoan.sol';

contract OpenSkyLoanMock is OpenSkyLoan {
    constructor(
        string memory name,
        string memory symbol,
        address _settings,
        address _pool
    ) OpenSkyLoan(name, symbol, _settings, _pool) {}

    function setPoolAddress(address pool) external {
        _pool = pool;
    }

    function poolAddress() external view returns (address) {
        return _pool;
    }
 
    function updateStatus(uint256 tokenId, DataTypes.LoanStatus status) external {
        _updateStatus(tokenId, status);
    }
}
