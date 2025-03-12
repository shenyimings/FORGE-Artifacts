pragma solidity 0.8.4;

import "forge-std/Test.sol";

contract ForkTest is Test {
    // the identifiers of the forks
    uint256 goerliFork;
    string MAINNET_RPC_URL = "https://eth-goerli.g.alchemy.com/v2/Y90zFzKWSHaGgejMQVqPRUEYkN7YCW9w";

    // create two _different_ forks during setup
    function setUp() public {
        goerliFork = vm.createFork(MAINNET_RPC_URL);
    }

    // select a specific fork
    function testCanSelectFork() public {
        // select the fork
        vm.selectFork(goerliFork);
        assertEq(vm.activeFork(), goerliFork);

        // from here on data is fetched from the `goerliFork` if the EVM requests it
    }

    // manage multiple forks in the same test
    function testCanSwitchForks() public {
        cheats.selectFork(goerliFork);
        assertEq(vm.activeFork(), goerliFork);
    }

    // forks can be created at all times
    function testCanCreateAndSelectForkInOneStep() public {
        // creates a new fork and also selects it
        uint256 anotherFork = cheats.createSelectFork(MAINNET_RPC_URL);
    }

    // set `block.timestamp` of a fork
    function testCanSetForkBlockTimestamp() public {
        vm.selectFork(goerliFork);
        vm.rollFork(1_337_000);

        assertEq(block.number, 1_337_000);
    }
}
