// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

// import "forge-std/Test.sol";
import "../lib/forge-std/src/Test.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/pools/IConicPool.sol";
import "../interfaces/IController.sol";
import "../interfaces/access/IGovernanceProxy.sol";
import "../lib/forge-std/src/console2.sol";

// Used for some mainnet fork testing of weight updates.
// To be run once the weight update is prepared but not yet executed.
// Run with:
// forge test --match-path test/WeightUpdateTest.sol -vv --fork-url https://mainnet.infura.io/v3/877a2e1fef3a4ca5a6b31a4764c3399b

interface USDT {
    function approve(address spender, uint256 amount) external;
}

library ERC20Compat {
    function compatApprove(IERC20Metadata token, address spender, uint256 amount) internal {
        if (address(token) == address(0xdAC17F958D2ee523a2206206994597C13D831ec7)) {
            USDT(address(token)).approve(spender, amount);
        } else {
            token.approve(spender, amount);
        }
    }
}

contract WeightUpdateTest is Test {
    using stdStorage for StdStorage;
    using ERC20Compat for IERC20Metadata;

    IController controller = IController(0x013A3Da6591d3427F164862793ab4e388F9B587e);
    IGovernanceProxy governanceProxy = IGovernanceProxy(0xCb7c67bDde9F7aF0667E8d82bb87F1432Bd1d902);
    address MULTISIG = address(0xB27DC5f8286f063F11491c8f349053cB37718bea);

    function testUpdateWeights() public {
        IGovernanceProxy.Change[] memory pendingChanges = governanceProxy.getPendingChanges();
        assertEq(pendingChanges.length, 1);
        IGovernanceProxy.Change memory change = pendingChanges[0];
        skip(1 days);
        vm.prank(MULTISIG);
        governanceProxy.executeChange(change.id);

        address[] memory poolAddresses = controller.listActivePools();
        for (uint256 i = 0; i < poolAddresses.length; i++) {
            IConicPool pool = IConicPool(poolAddresses[i]);
            IERC20Metadata underlying = IERC20Metadata(pool.underlying());
            uint8 decimals = underlying.decimals();
            uint256 amount = 10_000 * 10 ** decimals;
            setTokenBalance(address(this), address(underlying), amount);
            console.log("Approving %s", address(underlying));
            underlying.compatApprove(address(pool), amount);
            pool.deposit(amount, (amount * 9) / 10);
            uint256 withdrawAmount = (amount * 9) / 10;
            pool.unstakeAndWithdraw(withdrawAmount, (withdrawAmount * 9) / 10);
        }
    }

    function setTokenBalance(address who, address token, uint256 amt) internal {
        bytes4 sel = IERC20(token).balanceOf.selector;
        stdstore.target(token).sig(sel).with_key(who).checked_write(amt);
    }
}
