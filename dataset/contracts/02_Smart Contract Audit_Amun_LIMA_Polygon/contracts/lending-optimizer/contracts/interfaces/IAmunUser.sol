pragma solidity ^0.6.12;

interface IAmunUser {
    function isAmunUser(address _amunUser) external view returns (bool);
    function isOnlyAmunUserActive() external view returns (bool);
}
