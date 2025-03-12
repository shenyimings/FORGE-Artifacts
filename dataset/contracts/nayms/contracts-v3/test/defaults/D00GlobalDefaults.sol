// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/// @notice Default test setup part 00
///         Global level defaults for any and all solidity projects using solc >=0.7.6
///         Setup accounts, signers, labels

import "test/utils/DSTestPlusF.sol";
import { AppStorage } from "src/diamonds/nayms/AppStorage.sol";
import { MockAccounts } from "test/utils/users/MockAccounts.sol";

contract D00GlobalDefaults is DSTestPlusF {
    address public immutable account0 = address(this);
    uint256 public MAINNET_FORK_BLOCK_NUMBER = 15615850;
    uint256 public GOERLI_FORK_BLOCK_NUMBER = 7661570;

    function setUp() public virtual {
        console2.log("\n -- D00 Global Defaults\n");

        console2.log("Test contract address, aka account0", address(this));
        console2.log("msg.sender during setup", msg.sender);

        vm.label(account0, "Account 0 (Test Contract address)");
    }
}
