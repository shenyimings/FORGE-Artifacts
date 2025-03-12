pragma solidity 0.5.16;

contract EmergencyMock {
    uint public x = 5;
    uint public y = 8;

    function setX(uint val) public returns(bytes memory) {
        x = val;

        return msg.data;
    }

    function setY(uint val) public payable returns(bytes memory) {
        require(msg.value == 1, "must send 1 wei");
        y = val;

        return msg.data;
    }
}
