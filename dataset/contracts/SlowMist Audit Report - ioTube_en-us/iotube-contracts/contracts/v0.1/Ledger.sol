// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "./Owned.sol";

contract Ledger is Owned {
    mapping(bytes32 => uint256) public records;

    function record(bytes32 id) public onlyOwner {
        require(records[id] == 0, "already in ledger");
        records[id] = block.number;
    }

    function get(bytes32 id) public view returns (uint256) {
        return records[id];
    }
}
