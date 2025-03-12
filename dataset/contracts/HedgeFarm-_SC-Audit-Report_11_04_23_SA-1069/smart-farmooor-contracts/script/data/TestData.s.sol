pragma solidity ^0.8.0;

import "forge-std/Script.sol";

contract TestData is Script {
    address RANDOM_ADDRESS = makeAddr("RANDOM_ADDRESS");
    address ALICE = makeAddr("ALICE");
    address BOB = makeAddr("BOB");
    address CLARA = makeAddr("CLARA");
}