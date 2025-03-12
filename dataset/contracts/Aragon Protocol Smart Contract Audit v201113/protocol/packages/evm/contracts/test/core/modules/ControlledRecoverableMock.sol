pragma solidity ^0.5.17;

import "../../../core/modules/ControlledRecoverable.sol";


contract ControlledRecoverableMock is ControlledRecoverable {
    event EtherReceived(address sender, uint256 value);

    constructor(Controller _controller) Controlled(_controller) public {}

    function receiveEther() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }
}
