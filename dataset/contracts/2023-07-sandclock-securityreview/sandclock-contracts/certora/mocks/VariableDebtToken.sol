// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;


contract VariableDebtToken {

    mapping(address=>uint256) _balances;

    function mint(
        address user,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external returns (bool, uint256) {
        _balances[onBehalfOf] += amount;
        return (true, amount);
    }

    function burn(
        address from,
        uint256 amount,
        uint256 index
    ) external returns (uint256) {
        _balances[from] -= amount;
        return amount;
    }

    function balanceOf(address user) external view returns (uint256) {
        return _balances[user];
    }

}