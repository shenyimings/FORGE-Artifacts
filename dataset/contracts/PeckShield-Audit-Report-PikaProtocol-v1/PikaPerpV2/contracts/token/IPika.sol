pragma solidity ^0.8.0;

interface IPika {
    function mint(address _recipient, uint256 _amount) external;
    function burn(uint256 _amount) external;
}
