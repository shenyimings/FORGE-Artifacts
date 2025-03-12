pragma solidity 0.4.25;

contract HumanOriented {
    modifier onlyHuman() {
        require(msg.sender == tx.origin, "not a human"); // solium-disable-line security/no-tx-origin
        _;
    }
}
