pragma solidity ^0.5.11;

contract Pausable {

    bool private pauseState = true;

    event PauseChangedTo(bool pauseState);

    function doPause() internal {
        pauseState = !pauseState;
        emit PauseChangedTo(pauseState);
    }

    function isPaused() public view returns (bool) {
        return pauseState;
    }

    modifier whenPaused() {
        require(pauseState, "it is not paused now");
        _;
    }

    modifier whenNotPaused() {
        require(!pauseState, "it is paused now");
        _;
    }

}