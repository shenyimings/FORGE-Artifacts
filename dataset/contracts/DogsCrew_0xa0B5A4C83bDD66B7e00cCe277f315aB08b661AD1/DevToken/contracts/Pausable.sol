// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Ownable.sol";

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
    event Pause();
    event Unpause();

    bool public paused = false;

    //  modifier to allow actions only when the contract IS paused
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    //  modifier to allow actions only when the contract IS NOT paused
    modifier whenPaused() {
        require(paused);
        _;
    }

    // called by the owner to pause, triggers stopped state
    function pause() public onlyOwner whenNotPaused returns (bool) {
        paused = true;
        emit Pause();
        return true;
    }

    // called by the owner to unpause, returns to normal state
    function unpause() public onlyOwner whenPaused returns (bool) {
        paused = false;
        emit Unpause();
        return true;
    }

    // used to check if the contract is paused
    function getStatusPause() public view returns (bool) {
        return paused;
    }
}
