// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {DividendDistribution} from "../../src/dividend/DividendDistribution.sol";
import "solady/test/utils/mocks/MockERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract DividendDistributionTest is Test {
    DividendDistribution distribution;
    MockERC20 token;

    uint256 public userPrivateKey;
    uint256 public ownerPrivateKey;

    address public user = address(1);
    address public user2 = address(2);
    address public distributor = address(4);

    struct HashAndDataTuple {
        uint256 originalData;
        bytes32 hash;
    }

    event Distributed(uint256 indexed distributionId, address indexed account, uint256 amount);
    event NewDistributionCreated(
        uint256 indexed distributionId, uint256 totalDistribution, uint256 startDate, uint256 endDate
    );
    event DistributionReclaimed(uint256 indexed distributionId, uint256 totalReclaimed);

    function setUp() public {
        token = new MockERC20("Money", "$", 6);

        distribution = new DividendDistribution(address(this));

        distribution.grantRole(distribution.DISTRIBUTOR_ROLE(), distributor);
    }

    function testCreateNewDistribution(uint256 totalDistribution, uint256 _endTime) public {
        vm.assume(totalDistribution < 1e8);
        assertEq(IERC20(address(token)).balanceOf(address(distribution)), 0);

        token.mint(distributor, totalDistribution);

        vm.prank(distributor);
        token.approve(address(distribution), totalDistribution);

        if (_endTime <= block.timestamp) {
            vm.expectRevert(DividendDistribution.EndTimeInPast.selector);
            vm.prank(distributor);
            distribution.createDistribution(address(token), totalDistribution, _endTime);
        } else {
            vm.expectEmit(true, true, true, true);
            emit NewDistributionCreated(0, totalDistribution, block.timestamp, _endTime);
            vm.prank(distributor);
            distribution.createDistribution(address(token), totalDistribution, _endTime);
            assertEq(IERC20(address(token)).balanceOf(address(distribution)), totalDistribution);
            assertEq(IERC20(address(token)).balanceOf(distributor), 0);
        }
    }

    function testCreateDistributionNotDistributorReverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, distribution.DISTRIBUTOR_ROLE()
            )
        );
        vm.prank(user);
        distribution.createDistribution(address(token), 100, block.timestamp + 1);
    }

    function testDistribute(uint256 totalDistribution, uint256 distribution1) public {
        vm.assume(distribution1 < totalDistribution);

        token.mint(distributor, totalDistribution);

        vm.prank(distributor);
        token.approve(address(distribution), totalDistribution);
        vm.prank(distributor);
        uint256 distributionId = distribution.createDistribution(address(token), totalDistribution, block.timestamp + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, distribution.DISTRIBUTOR_ROLE()
            )
        );
        vm.prank(user);
        distribution.distribute(distributionId, user, distribution1);

        vm.expectEmit(true, true, true, true);
        emit Distributed(distributionId, user, distribution1);
        vm.prank(distributor);
        distribution.distribute(distributionId, user, distribution1);
        assertEq(token.balanceOf(user), distribution1);

        (,, uint256 endTime) = distribution.distributions(distributionId);
        vm.warp(endTime + 1);
        vm.prank(distributor);
        vm.expectRevert(DividendDistribution.DistributionEnded.selector);
        distribution.distribute(distributionId, user, distribution1);
    }

    function testReclaimed(uint256 totalDistribution) public {
        token.mint(distributor, totalDistribution);

        vm.prank(distributor);
        token.approve(address(distribution), totalDistribution);
        vm.prank(distributor);
        distribution.createDistribution(address(token), totalDistribution, block.timestamp + 1);
        assertEq(IERC20(address(token)).balanceOf(address(distribution)), totalDistribution);
        assertEq(IERC20(address(token)).balanceOf(distributor), 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, distribution.DISTRIBUTOR_ROLE()
            )
        );
        vm.prank(user);
        distribution.reclaimDistribution(0);

        vm.expectRevert(DividendDistribution.DistributionRunning.selector);
        vm.prank(distributor);
        distribution.reclaimDistribution(0);

        vm.expectRevert(DividendDistribution.NotReclaimable.selector);
        vm.prank(distributor);
        distribution.reclaimDistribution(1);

        (,, uint256 endTime) = distribution.distributions(0);
        vm.warp(endTime + 1);

        vm.expectEmit(true, true, true, true);
        emit DistributionReclaimed(0, totalDistribution);
        vm.prank(distributor);
        distribution.reclaimDistribution(0);

        assertEq(IERC20(address(token)).balanceOf(address(distribution)), 0);
        assertEq(IERC20(address(token)).balanceOf(distributor), totalDistribution);
    }
}
