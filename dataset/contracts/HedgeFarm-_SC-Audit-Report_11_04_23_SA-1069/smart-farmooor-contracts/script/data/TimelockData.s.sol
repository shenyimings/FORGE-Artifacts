pragma solidity ^0.8.0;

contract TimelockData {
    uint256 constant TIMELOCK_MIN_DELAY = 172800;
    address constant TIMELOCK_ADMIN = address(0);
    address[] TIMELOCK_PROPOSERS;
    address[] TIMELOCK_EXECUTORS;

    function loadTimelockData(address owner, address manager) public {
        TIMELOCK_PROPOSERS = [owner];
        TIMELOCK_EXECUTORS = [owner, manager];
    }
}
