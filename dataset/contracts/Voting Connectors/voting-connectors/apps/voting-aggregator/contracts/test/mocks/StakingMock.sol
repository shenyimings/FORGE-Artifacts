pragma solidity ^0.4.24;


contract StakingMock {
    mapping (address => mapping (uint256 => uint256)) internal balances;
    mapping (uint256 => uint256) internal totals;

    function stakeForAt(address addr, uint256 blockNumber, uint256 amount) external {
        balances[addr][blockNumber] += amount;
        totals[blockNumber] += amount;
    }

    function totalStakedForAt(address addr, uint256 blockNumber) external view returns (uint256) {
        return balances[addr][blockNumber];
    }

    function totalStakedAt(uint256 blockNumber) external view returns (uint256) {
        return totals[blockNumber];
    }

    function supportsHistory() external pure returns (bool) {
        return true;
    }
}
