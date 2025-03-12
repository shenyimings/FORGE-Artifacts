// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "contracts/TicketStorage.sol";

contract TicketStorageMock is TicketStorage {
    constructor(uint16 tickets) TicketStorage(tickets) {}

    function assignTickets(address owner, uint16 count) public {
        _assignTickets(owner, count);
    }

    function bulkAssignTickets(address owner, uint16 count) public {
        for (uint256 i = 0; i < count; i++) {
            _assignTickets(owner, 1);
        }
    }
}
