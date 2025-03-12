// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Counter.sol";

contract CounterMock {
    using Counter for Counter.Minted;

    Counter.Minted private _counter;

    constructor() {
        _counter.initialize();
    }

    function current() public view returns (uint256) {
        return _counter.current();
    }

    function increment(uint256 count) public {
        _counter.increment(count);
    }
}
