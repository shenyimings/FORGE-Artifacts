pragma solidity ^0.4.24;


contract TokenMock {
    mapping (address => mapping (uint256 => uint256)) internal balances;
    mapping (uint256 => uint256) internal totals;

    function addBalanceAt(address _owner, uint256 _blockNumber, uint256 _amount) external {
        balances[_owner][_blockNumber] += _amount;
        totals[_blockNumber] += _amount;
    }

    function balanceOfAt(address _owner, uint256 _blockNumber) public view returns (uint256) {
        return balances[_owner][_blockNumber];
    }

    function totalSupplyAt(uint256 _blockNumber) public view returns (uint256) {
        return totals[_blockNumber];
    }
}
