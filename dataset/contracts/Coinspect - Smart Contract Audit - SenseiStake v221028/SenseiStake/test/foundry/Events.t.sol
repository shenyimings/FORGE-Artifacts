pragma solidity 0.8.4;

import "forge-std/Test.sol";

contract EmitContractTest is Test {
    event Transfer(address indexed from, address indexed to, address indexed other, uint256 amount);

    function testExpectTest() public {
        ExpectEmit emitter = new ExpectEmit();
        // Check topic 1 and topic 2, but do not check data
        vm.expectEmit(true, true, false, true);
        // The event we expect
        emit Transfer(address(this), address(1337), address(1338), 1337);
        // The event we get
        emitter.t();
        
    }
}

contract ExpectEmit {
    event Transfer(address indexed from, address indexed to, address indexed other, uint256 amount);

    function t() public {
        emit Transfer(msg.sender, address(1337), address(1337), 1337);
    }
}
