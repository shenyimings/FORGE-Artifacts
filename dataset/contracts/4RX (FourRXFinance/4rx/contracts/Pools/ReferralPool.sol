// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "../libs/SortedLinkedList.sol";


contract ReferralPool {

    SortedLinkedList.Item[] public refPoolUsers;

    function _addRefPoolRecord(address user, uint amount, uint8 stakeId) public {
        if (!SortedLinkedList.isInList(refPoolUsers, user, stakeId)) {
            SortedLinkedList.addNode(refPoolUsers, user, amount, stakeId);
        } else {
            SortedLinkedList.updateNode(refPoolUsers, user, amount, stakeId);
        }
    }

    function _cleanRefPoolUsers() public {
        delete refPoolUsers;
        SortedLinkedList.initNodes(refPoolUsers);
    }
}
