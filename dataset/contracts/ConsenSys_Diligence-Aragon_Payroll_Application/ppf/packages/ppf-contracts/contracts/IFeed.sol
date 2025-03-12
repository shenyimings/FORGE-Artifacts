pragma solidity ^0.4.18;

interface IFeed {
    function get(address base, address quote) external view returns (uint128 xrt, uint64 when);
}
