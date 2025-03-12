// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";


library SortedLinkedList {
    using SafeMath for uint;

    struct Item {
        address user;
        uint16 next;
        uint8 id;
        uint score;
    }

    uint16 internal constant GUARD = 0;

    function addNode(Item[] storage items, address user, uint score, uint8 id) internal {
        uint16 prev = findSortedIndex(items, score);
        require(_verifyIndex(items, score, prev));
        items.push(Item(user, items[prev].next, id, score));
        items[prev].next = uint16(items.length.sub(1));
    }

    function updateNode(Item[] storage items, address user, uint score, uint8 id) internal {
        (uint16 current, uint16 oldPrev) = findCurrentAndPrevIndex(items, user, id);
        require(items[oldPrev].next == current);
        require(items[current].user == user);
        require(items[current].id == id);
        score = score.add(items[current].score);
        items[oldPrev].next = items[current].next;
        addNode(items, user, score, id);
    }

    function initNodes(Item[] storage items) internal {
        items.push(Item(address(0), 0, 0, 0));
    }

    function _verifyIndex(Item[] storage items, uint score, uint16 prev) internal view returns (bool) {
        return prev == GUARD || (score <= items[prev].score && score > items[items[prev].next].score);
    }

    function findSortedIndex(Item[] storage items, uint score) internal view returns(uint16) {
        Item memory current = items[GUARD];
        uint16 index = GUARD;
        while(current.next != GUARD && items[current.next].score > score) {
            index = current.next;
            current = items[current.next];
        }

        return index;
    }

    function findCurrentAndPrevIndex(Item[] storage items, address user, uint8 id) internal view returns (uint16, uint16) {
        Item memory current = items[GUARD];
        uint16 currentIndex = GUARD;
        uint16 prevIndex = GUARD;
        while(current.next != GUARD && !(current.user == user && current.id == id)) {
            prevIndex = currentIndex;
            currentIndex = current.next;
            current = items[current.next];
        }

        return (currentIndex, prevIndex);
    }

    function isInList(Item[] storage items, address user, uint8 id) internal view returns (bool) {
        Item memory current = items[GUARD];
        bool exists = false;

        while(current.next != GUARD ) {
            if (current.user == user && current.id == id) {
                exists = true;
                break;
            }
            current = items[current.next];
        }

        return exists;
    }
}
