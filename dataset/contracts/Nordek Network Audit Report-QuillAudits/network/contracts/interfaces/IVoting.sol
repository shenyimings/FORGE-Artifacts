pragma solidity 0.4.26;

interface IVoting {
    function onCycleEnd(address[] validators) external;
}
