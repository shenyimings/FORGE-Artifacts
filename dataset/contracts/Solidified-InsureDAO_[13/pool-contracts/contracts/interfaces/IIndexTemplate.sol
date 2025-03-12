pragma solidity ^0.6.0;

interface IIndexTemplate {
    function compensate(uint256) external;

    function lock(uint256) external;

    function resume() external;
}
