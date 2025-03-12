// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../lib/forge-std/src/Test.sol";

import "./ConicTest.sol";
import "../contracts/tokenomics/InflationRedirectionPool.sol";
import "../interfaces/tokenomics/ILpTokenStaker.sol";
import "../interfaces/pools/IConicPool.sol";

contract InflationRedirectionPoolTest is Test {
    uint256 internal mainnetFork;

    InflationRedirectionPool internal redirectionPool;
    IController internal controller = IController(MainnetAddresses.CONTROLLER);
    IInflationManager internal inflationManager;
    ILpTokenStaker internal lpTokenStaker;

    IERC20Metadata internal constant CNC =
        IERC20Metadata(0x9aE380F0272E2162340a5bB646c354271c0F5cFC);
    address internal constant USDC_POOL = 0x07b577f10d4e00f3018542d08a87F255a49175A5;
    address internal constant CRVUSD_POOL = 0x369cBC5C6f139B1132D3B91B87241B37Fc5B971f;
    address internal constant ETH_POOL = 0xBb787d6243a8D450659E09ea6fD82F1C859691e9;

    function setUp() public {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL, 17_770_225);
        lpTokenStaker = ILpTokenStaker(controller.lpTokenStaker());
        inflationManager = controller.inflationManager();
        redirectionPool = new InflationRedirectionPool(controller);
        vm.prank(MainnetAddresses.GOVERNANCE_PROXY);
        controller.addPool(address(redirectionPool));
        vm.prank(MainnetAddresses.GOVERNANCE_PROXY);
        inflationManager.updatePoolWeights();
    }

    function testInflationRedirection() external {
        address[] memory pools = controller.listPools();
        uint256 currentInflationRate = inflationManager.currentInflationRate();

        // check that the redirection pool is the only one receiving inflation
        assertEq(
            inflationManager.getCurrentPoolInflationRate(address(redirectionPool)),
            currentInflationRate
        );

        // check that we can claim all the rewards
        for (uint256 i; i < pools.length; i++) {
            if (pools[i] == address(redirectionPool)) continue;
            console.log("claiming rewards from pool", pools[i]);
            IConicPool pool = IConicPool(pools[i]);
            pool.rewardManager().claimPoolEarningsAndSellRewardTokens();
        }

        // need some time to ellapse after claimPoolEarningsAndSellRewardTokens
        skip(1);

        // check we can withdraw from all pools even if they do not receive inflation
        for (uint256 i; i < pools.length; i++) {
            if (pools[i] == address(redirectionPool)) continue;
            assertEq(inflationManager.getCurrentPoolInflationRate(pools[i]), 0);
            _withdrawFromPool(pools[i]);
        }

        skip(1 days);

        // check that no pool is receiving inflation
        for (uint256 i; i < pools.length; i++) {
            if (pools[i] == address(redirectionPool)) continue;
            assertEq(controller.lpTokenStaker().claimableCnc(pools[i]), 0);
        }

        // check that redirection pool is receiving inflation
        assertEq(CNC.balanceOf(address(redirectionPool)), 0);

        redirectionPool.poolCheckpoint();
        uint256 received = CNC.balanceOf(address(redirectionPool));
        assertApproxEqRel(received, currentInflationRate * 86400, 1e16);

        // check that the inflation is redirected to the treasury
        uint256 treasuryBalanceBefore = CNC.balanceOf(MainnetAddresses.MULTISIG);
        redirectionPool.withdrawInflation();
        uint256 treasuryBalanceAfter = CNC.balanceOf(MainnetAddresses.MULTISIG);
        assertEq(received, treasuryBalanceAfter - treasuryBalanceBefore);
    }

    function testInflationRedirectionShutdown() external {
        skip(1 days);
        uint256 currentInflationRate = inflationManager.currentInflationRate();
        uint256 totalSupply1 = CNC.totalSupply();
        redirectionPool.withdrawInflation();
        uint256 totalSupply2 = CNC.totalSupply();
        assertApproxEqRel(totalSupply2 - totalSupply1, currentInflationRate * 86400, 1e16);
        skip(2 days);

        vm.expectRevert("InflationRedirectionPool: only multisig can shutdown");
        redirectionPool.shutdown();

        vm.prank(MainnetAddresses.MULTISIG);
        redirectionPool.shutdown();
        assertEq(redirectionPool.isShutdown(), true);
        uint256 totalSupply3 = CNC.totalSupply();
        assertApproxEqRel(totalSupply3 - totalSupply2, currentInflationRate * 86400 * 2, 1e16);

        skip(3 days);
        vm.expectRevert("InflationRedirectionPool: pool is shutdown");
        vm.prank(MainnetAddresses.MULTISIG);
        redirectionPool.shutdown();
        assertEq(totalSupply3, CNC.totalSupply());
    }

    function _withdrawFromPool(address pool) internal {
        address user = _getTestAddress(pool);
        if (user == address(0)) return;

        uint256 userLpBalance = lpTokenStaker.getUserBalanceForPool(pool, user);
        assertGt(userLpBalance, 0);
        IERC20Metadata underlying = IERC20Metadata(IConicPool(pool).underlying());

        uint256 balanceBefore = underlying.balanceOf(user);
        vm.prank(user);
        uint256 received = IConicPool(pool).unstakeAndWithdraw(userLpBalance, 0);
        uint256 balanceAfter = underlying.balanceOf(user);
        assertEq(received, balanceAfter - balanceBefore);
        assertGt(received, 0);
        console.log("pool", pool);
        console.log("LP amount", userLpBalance);
        console.log("underlying received", received);
    }

    function _getTestAddress(address pool) internal pure returns (address) {
        if (pool == USDC_POOL) return 0xc0F0C674dCF195E2c39DFA7Bb59fa968b7F7c575;
        if (pool == CRVUSD_POOL) return 0x56B9c77823c65a6A83E85e1e04d974642589B67a;
        if (pool == ETH_POOL) return 0xd8c2ee2FEfAc57F8B3cD63bE28D8F89bBBf5a5F2;
        return address(0);
    }
}
