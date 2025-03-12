pragma solidity ^0.6.12;

interface Aave {
    function deposit(
        address _reserve,
        uint256 _amount,
        uint16 _code
    ) external;
}
