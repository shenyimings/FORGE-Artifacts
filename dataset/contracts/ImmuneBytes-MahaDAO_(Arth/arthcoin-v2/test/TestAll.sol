// SPDX-License-Identifier: MIT
pragma solidity >=0.4.25 <0.7.0;

import 'truffle/Assert.sol';
import 'truffle/DeployedAddresses.sol';
import '../contracts/FakeCollateral/FakeCollateral.sol';
import '../contracts/Arth/Arth.sol';
import '../contracts/Arth/Pools/ArthPool.sol';
import '../contracts/ARTHS/ARTHS.sol';
import '../contracts/Governance/Governance.sol';
import '../contracts/Staking/StakingRewards.sol';

contract TestAll {
    function testArthDeployment() public {
        ARTHStablecoin arth =
            ARTHStablecoin(DeployedAddresses.ARTHStablecoin());

        // Check for 18 decimals
        Assert.equal(arth.decimals(), uint256(18), '18 decimals expected');
    }

    function testArthPoolDeployment() public {
        ArthPool pool = ArthPool(DeployedAddresses.ArthPool());
    }

    function testARTHSDeployment() public {
        ARTHShares arthx = ARTHShares(DeployedAddresses.ARTHShares());

        // Check for 18 decimals
        Assert.equal(arthx.decimals(), uint256(18), '18 decimals expected');
    }

    function testGovernanceDeployment() public {
        GovernorAlpha governor =
            GovernorAlpha(DeployedAddresses.GovernorAlpha());
    }

    function testStakingRewardsDeployment() public {
        StakingRewards stake =
            StakingRewards(DeployedAddresses.StakingRewards());
    }

    function testFakeCollateralDeployment() public {
        FakeCollateral fake =
            FakeCollateral(DeployedAddresses.FakeCollateral());

        // Check for 18 decimals
        Assert.equal(fake.decimals(), uint256(18), '18 decimals expected');

        address creator_address = fake.creator_address();

        // Make sure the received their initial tokens
        Assert.equal(
            fake.balanceOf(creator_address),
            uint256(10000000e18),
            'Owner should have 10000000e18 FAKE initially'
        );
    }
}
