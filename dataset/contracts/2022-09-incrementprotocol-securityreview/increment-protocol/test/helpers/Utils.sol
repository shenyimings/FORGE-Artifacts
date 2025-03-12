// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// interfaces
import "../../contracts/interfaces/IVault.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// utils
import {Test} from "../../lib/forge-std/src/Test.sol";

abstract contract Utils is Test {
    function changeHoax(address user) public {
        deal(user, 1 << 128);
        vm.startPrank(user);
    }

    function fundAndPrepareAccount(address user, uint256 amount, IVault vault, IERC20Metadata token) public {
        deal(address(token), user, amount);
        vm.startPrank(user);
        token.approve(address(vault), amount);
    }
}
