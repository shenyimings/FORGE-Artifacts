pragma solidity ^0.6.0;

interface ICDS {
    function compensate(uint256) external;

    function lock() external;

    function resume() external;
}
