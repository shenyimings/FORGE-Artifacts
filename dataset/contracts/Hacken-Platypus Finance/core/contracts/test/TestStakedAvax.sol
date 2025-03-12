// SPDX-License-Identifier: MIT
import '../interfaces/IStakedAvax.sol';

pragma solidity 0.8.9;

/// MOCK CONTRACT: IStakedAvax on localhost
contract TestStakedAvax is IStakedAvax {
    // sAVAX to AVAX rate ~ 1.0122
    // 1e18
    uint256 rate = 1e18;

    function getPooledAvaxByShares(uint256 _shares) external view returns (uint256) {
        require(_shares == 1e18, 'wrong shares');
        return rate;
    }

    function setRate(uint256 _rate) external {
        rate = _rate;
    }
}
