pragma solidity ^0.5.17;

import "../../../core/modules/Controlled.sol";


contract ModuleMock is Controlled {
    event EtherReceived(address sender, uint256 value);

    uint256 public counter;

    constructor(Controller _controller) Controlled(_controller) public {}

    function () external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    function setCounter(uint256 _counter) external {
        counter = _counter;
    }

    function receiveEther() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    function setModule(bytes32, address) external pure {
        revert('CONTROLLED_MALICIOUS_SET_MODULE');
    }

    function fail() external pure {
        revert('CONTROLLED_FAIL');
    }
}
