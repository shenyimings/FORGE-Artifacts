pragma solidity ^0.5.16;

import "../../contracts/CTokenAdmin.sol";

contract MockCTokenAdmin is CTokenAdmin {
    uint256 public blockTimestamp;

    constructor(address payable _admin) public CTokenAdmin(_admin) {}

    function setBlockTimestamp(uint256 timestamp) public {
        blockTimestamp = timestamp;
    }

    function getBlockTimestamp() public view returns (uint256) {
        return blockTimestamp;
    }
}
