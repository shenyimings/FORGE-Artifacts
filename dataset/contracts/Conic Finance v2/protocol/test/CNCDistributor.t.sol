// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../lib/forge-std/src/Test.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../interfaces/tokenomics/ICNCDistributor.sol";
import "../contracts/tokenomics/CNCDistributor.sol";
import "../libraries/ScaledMath.sol";
import "../lib/forge-std/src/console2.sol";
import "./ConicTest.sol";

contract CNCDistributorTest is ConicTest {
    using stdStorage for StdStorage;
    using ScaledMath for uint256;
    ICNCDistributor cncDistributor;

    address internal constant DEPLOYED_CNC_DISTRIBUTOR = 0x74eA6D777a4aEC782EBA0AcAE61142AAc69D3E2F;

    IERC20Metadata public constant CNC = IERC20Metadata(0x9aE380F0272E2162340a5bB646c354271c0F5cFC);

    IERC20 internal constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    ICurveGauge public constant CNC_ETH_GAUGE =
        ICurveGauge(0x5A8fa46ebb404494D718786e55c4E043337B10bF);

    uint256 constant CNC_AMOUNT = 10000e18;

    function setUp() public override {
        super.setUp();
        _setFork(mainnetFork);
        cncDistributor = new CNCDistributor();
    }

    function testDonate() external {
        assertEq(CNC.balanceOf(address(cncDistributor)), 0);
        setTokenBalance(bb8, address(CNC), CNC_AMOUNT);
        vm.prank(bb8);
        CNC.approve(address(cncDistributor), CNC_AMOUNT);
        vm.prank(bb8);
        cncDistributor.donate(CNC_AMOUNT);
        assertEq(CNC.balanceOf(address(cncDistributor)), CNC_AMOUNT);
        assertEq(CNC.balanceOf(bb8), 0);
    }

    function testDonateFailsNotEnoughFunds() external {
        vm.prank(bb8);
        CNC.approve(address(cncDistributor), CNC_AMOUNT);
        vm.prank(bb8);
        vm.expectRevert();
        cncDistributor.donate(CNC_AMOUNT);
    }

    function testDonateFailsIfShutdown() external {
        setTokenBalance(bb8, address(CNC), CNC_AMOUNT);
        vm.prank(bb8);
        CNC.approve(address(cncDistributor), CNC_AMOUNT);
        cncDistributor.shutdown();
        vm.prank(bb8);
        vm.expectRevert();
        cncDistributor.donate(CNC_AMOUNT);
    }

    function testShutdown() external {
        assertFalse(cncDistributor.isShutdown());
        cncDistributor.shutdown();
        assertTrue(cncDistributor.isShutdown());
    }

    function testShutdownFailsIfNotAdmin() external {
        vm.prank(bb8);
        vm.expectRevert();
        cncDistributor.shutdown();
    }

    function testShutdownFailsIfAlreadyShutdown() external {
        cncDistributor.shutdown();
        vm.expectRevert();
        cncDistributor.shutdown();
    }

    function testWithdrawOtherToken() external {
        setTokenBalance(address(cncDistributor), address(DAI), 100e18);
        uint256 oldBalance = DAI.balanceOf(MainnetAddresses.MULTISIG);
        cncDistributor.withdrawOtherToken(address(DAI));
        uint256 newBalance = DAI.balanceOf(MainnetAddresses.MULTISIG);
        assertEq(newBalance - oldBalance, 100e18);
    }

    function testWirthdrawOtherTokenFailsIfCNC() external {
        setTokenBalance(address(cncDistributor), address(CNC), CNC_AMOUNT);
        vm.expectRevert();
        cncDistributor.withdrawOtherToken(address(CNC));
    }

    function testTopUpGaugePostPeriodFinish() external {
        assert(CNC.balanceOf(address(cncDistributor)) == 0);

        // fund CNC Distributor
        setTokenBalance(address(cncDistributor), address(CNC), CNC_AMOUNT);

        // set Curve Gauge reward distributor to CNC Distributor
        vm.prank(address(MainnetAddresses.CNC_DISTRIBUTOR));
        CNC_ETH_GAUGE.set_reward_distributor(address(CNC), address(cncDistributor));

        uint256 gaugeRate = cncDistributor.gaugeInflationShare().mulDown(
            cncDistributor.currentInflationRate()
        );

        // ensure period is finished (no current rewards live)
        (, , uint256 periodFinish, , , ) = CNC_ETH_GAUGE.reward_data(address(CNC));

        // skip ahead so that it's 1 day past the last reward period finished
        vm.warp(periodFinish + 1 days);
        uint256 expectedTopUp = (8 days * gaugeRate);

        uint256 gaugeBalanceBefore = CNC.balanceOf(address(CNC_ETH_GAUGE));
        cncDistributor.topUpGauge();
        uint256 gaugeBalanceAfter = CNC.balanceOf(address(CNC_ETH_GAUGE));

        assertEq(gaugeBalanceAfter - gaugeBalanceBefore, expectedTopUp);

        (, , , uint256 rate, , ) = CNC_ETH_GAUGE.reward_data(address(CNC));
        assertEq(rate, expectedTopUp / 7 days);
    }

    function testTopUpGaugePrePeriodFinish() external {
        assert(CNC.balanceOf(address(cncDistributor)) == 0);
        // fund CNC Distributor
        setTokenBalance(address(cncDistributor), address(CNC), 2 * CNC_AMOUNT);
        vm.prank(address(MainnetAddresses.CNC_DISTRIBUTOR));
        CNC_ETH_GAUGE.set_reward_distributor(address(CNC), address(cncDistributor));

        uint256 gaugeRate = cncDistributor.gaugeInflationShare().mulDown(
            cncDistributor.currentInflationRate()
        );
        assert(gaugeRate > 0);

        // ensure period is finished (no current rewards live)
        (, , uint256 periodFinish, , , ) = CNC_ETH_GAUGE.reward_data(address(CNC));

        uint256 expectedTopUp = (7 days * gaugeRate);
        uint256 gaugeBalanceBefore = CNC.balanceOf(address(CNC_ETH_GAUGE));

        // set time to when period finishes/finished
        vm.warp(periodFinish);
        cncDistributor.topUpGauge();
        uint256 gaugeBalanceAfter = CNC.balanceOf(address(CNC_ETH_GAUGE));
        assertEq(gaugeBalanceAfter - gaugeBalanceBefore, expectedTopUp);
        (, , uint256 newPeriodFinish, uint256 rate, , ) = CNC_ETH_GAUGE.reward_data(address(CNC));
        assertEq(rate, expectedTopUp / 7 days);

        // top up gauge again after 1 day during active rewards period
        vm.warp(periodFinish + 1 days);
        gaugeBalanceBefore = CNC.balanceOf(address(CNC_ETH_GAUGE));
        cncDistributor.topUpGauge();
        gaugeBalanceAfter = CNC.balanceOf(address(CNC_ETH_GAUGE));

        expectedTopUp = (1 days * gaugeRate);
        assertEq(gaugeBalanceAfter - gaugeBalanceBefore, expectedTopUp);

        (, , , uint256 newRate, , ) = CNC_ETH_GAUGE.reward_data(address(CNC));
        assert(block.timestamp == periodFinish + 1 days);
        uint256 leftover = (newPeriodFinish - block.timestamp) * rate;
        uint256 expectedNewRate = (leftover + expectedTopUp) / 7 days;
        assertEq(newRate, expectedNewRate);
    }

    function testUpdateInflationShare() external {
        uint256 NEW_RATE = 0.3e18;

        // fund Distributor to be able to top up gauge
        setTokenBalance(address(cncDistributor), address(CNC), 2 * CNC_AMOUNT);

        // set Curve Gauge reward distributor to CNC Distributor
        vm.prank(address(MainnetAddresses.CNC_DISTRIBUTOR));
        CNC_ETH_GAUGE.set_reward_distributor(address(CNC), address(cncDistributor));

        cncDistributor.updateInflationShare(NEW_RATE);
        assertEq(cncDistributor.gaugeInflationShare(), NEW_RATE);
    }

    function testSetGaugeRewardDistributor() external {
        vm.prank(address(MainnetAddresses.CNC_DISTRIBUTOR));
        CNC_ETH_GAUGE.set_reward_distributor(address(CNC), address(cncDistributor));
        (, address distributor, , , , ) = CNC_ETH_GAUGE.reward_data(address(CNC));
        assertEq(distributor, address(cncDistributor));

        cncDistributor.shutdown();
        cncDistributor.setGaugeRewardDistributor(MainnetAddresses.MULTISIG);
        (, distributor, , , , ) = CNC_ETH_GAUGE.reward_data(address(CNC));
        assertEq(distributor, MainnetAddresses.MULTISIG);
    }

    function testSetGaugeRewardDistributorNotShutdown() external {
        vm.prank(address(MainnetAddresses.CNC_DISTRIBUTOR));
        CNC_ETH_GAUGE.set_reward_distributor(address(CNC), address(cncDistributor));
        (, address distributor, , , , ) = CNC_ETH_GAUGE.reward_data(address(CNC));
        assertEq(distributor, address(cncDistributor));

        vm.expectRevert();
        cncDistributor.setGaugeRewardDistributor(MainnetAddresses.MULTISIG);
        (, distributor, , , , ) = CNC_ETH_GAUGE.reward_data(address(CNC));
        assertEq(distributor, address(cncDistributor));
    }
}
