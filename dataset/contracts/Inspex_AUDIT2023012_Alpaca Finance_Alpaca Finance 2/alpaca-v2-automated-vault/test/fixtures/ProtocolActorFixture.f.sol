// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// dependencies
import "@forge-std/Test.sol";

contract ProtocolActorFixture is Test {
  address public constant DEPLOYER = 0xC44f82b07Ab3E691F826951a6E335E1bC1bB0B51;
  address public constant PERFORMANCE_FEE_BUCKET = address(0xfee);
  address public constant USER_ALICE = address(0xa11ce);
  address public constant USER_BOB = address(0xb0b);
  address public constant USER_EVE = address(0xe4e);
  address public constant MANAGER = address(0xa4313);

  address public WITHDRAWAL_FEE_TREASURY = makeAddr("WITHDRAWAL_FEE_TREASURY");
  address public MANAGEMENT_FEE_TREASURY = makeAddr("Management Fee");

  constructor() {
    vm.label(DEPLOYER, "DEPLOYER");
    vm.label(PERFORMANCE_FEE_BUCKET, "PERFORMANCE_FEE_BUCKET");
    vm.label(USER_ALICE, "USER_ALICE");
    vm.label(USER_BOB, "USER_BOB");
    vm.label(USER_EVE, "USER_EVE");
    vm.label(MANAGER, "MANAGER");

    vm.label(MANAGEMENT_FEE_TREASURY, "MANAGEMENT_FEE_TREASURY");
    vm.label(WITHDRAWAL_FEE_TREASURY, "WITHDRAWAL_FEE_TREASURY");
  }
}
