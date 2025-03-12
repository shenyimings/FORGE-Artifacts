pragma solidity ^0.5.17;

import "../../../core/modules/Controlled.sol";


contract ControlledMock is Controlled {
    event OnlyConfigGovernorCalled();
    event Authenticated(address user, address sender);

    constructor(Controller _controller) Controlled(_controller) public {}

    function onlyConfigGovernorFn() external onlyConfigGovernor {
        emit OnlyConfigGovernorCalled();
    }

    function authenticateCall(address _user) external authenticateSender(_user) {
        emit Authenticated(_user, msg.sender);
    }
}
