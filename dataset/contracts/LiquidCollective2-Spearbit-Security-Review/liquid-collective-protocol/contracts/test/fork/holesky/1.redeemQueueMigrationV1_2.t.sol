//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../../../src/TUPProxy.sol";
import "../../../src/RedeemManager.1.sol";
import "../../../src/state/redeemManager/RedeemQueue.1.sol";
import "../../../src/state/redeemManager/RedeemQueue.2.sol";
import "../../../src/state/redeemManager/RedeemQueue.1.2.sol";
import "../../../src/state/redeemManager/WithdrawalStack.sol";
import {ITransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/console.sol";

interface MockIRedeemManagerV1 {
    function getRedeemRequestDetails(uint32 _redeemRequestId)
        external
        view
        returns (RedeemQueueV1.RedeemRequest memory);

    function getRedeemRequestCount() external view returns (uint256);
}

interface MockIRedeemManagerV2 {
    function getRedeemRequestDetails(uint32 _redeemRequestId)
        external
        view
        returns (RedeemQueueV2.RedeemRequest memory);

    function getRedeemRequestCount() external view returns (uint256);
}

contract RedeemQueueMigrationV1_2 is Test {
    bool internal _skip = false;
    string internal _rpcUrl;

    address internal constant REDEEM_MANAGER_MAINNET_ADDRESS = 0xd8D56E758BB655b5B70Ac40758afbAA46E990831;
    address internal constant REDEEM_MANAGER_MAINNET_PROXY_ADMIN_ADDRESS = 0xA3257d9A7E6284865C7C113E82bA2363F7F277d2;

    function setUp() external {
        try vm.envString("TENDERLY_URL") returns (string memory rpcUrl) {
            _rpcUrl = rpcUrl;
            vm.createSelectFork(_rpcUrl, 2130850);
            console.log("1.RedeemQueueMigrationV1_2.t.sol is active");
        } catch {
            _skip = true;
        }
    }

    function _generateRandomAddress(uint256 length) internal view returns (address[] memory) {
        // Generate a random 20-byte address
        address[] memory randomAddresses = new address[](length);

        // Populate the array with random addresses
        for (uint256 i = 0; i < length; i++) {
            randomAddresses[i] =
                address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i)))));
        }

        return randomAddresses;
    }

    modifier shouldSkip() {
        if (!_skip) {
            _;
        }
    }

    function test_migrate_allRequestInOneCall() external shouldSkip {
        // Setting up the Redeem Manager
        TUPProxy redeemManagerProxy = TUPProxy(payable(REDEEM_MANAGER_MAINNET_ADDRESS));

        MockIRedeemManagerV1 RedeemManager = MockIRedeemManagerV1(REDEEM_MANAGER_MAINNET_ADDRESS);

        RedeemQueueV1.RedeemRequest memory oldRequest0 = RedeemManager.getRedeemRequestDetails(0);
        RedeemQueueV1.RedeemRequest memory oldRequest1 = RedeemManager.getRedeemRequestDetails(1);
        RedeemQueueV1.RedeemRequest memory oldRequest2 = RedeemManager.getRedeemRequestDetails(2);
        RedeemQueueV1.RedeemRequest memory oldRequest3 = RedeemManager.getRedeemRequestDetails(3);
        RedeemQueueV1.RedeemRequest memory oldRequest4 = RedeemManager.getRedeemRequestDetails(4);
        RedeemQueueV1.RedeemRequest memory oldRequest5 = RedeemManager.getRedeemRequestDetails(5);
        RedeemQueueV1.RedeemRequest memory oldRequest6 = RedeemManager.getRedeemRequestDetails(6);
        address[] memory mockInitiators = _generateRandomAddress(7);

        // Set up the fork at a new block for testing the upgrade
        vm.createSelectFork(_rpcUrl, 2274558);
        // Upgrade the RedeemManager
        RedeemManagerV1 newImplementation = new RedeemManagerV1();
        vm.prank(REDEEM_MANAGER_MAINNET_PROXY_ADMIN_ADDRESS);
        ITransparentUpgradeableProxy(address(redeemManagerProxy)).upgradeToAndCall(
            address(newImplementation),
            abi.encodeWithSelector(RedeemManagerV1.initializeRedeemManagerV1_2.selector, mockInitiators)
        );

        // After upgrade: check that state before the upgrade, and state after upgrade are same.
        vm.roll(block.number + 1);
        MockIRedeemManagerV2 RManager = MockIRedeemManagerV2(REDEEM_MANAGER_MAINNET_ADDRESS);
        uint256 newCount = RedeemManager.getRedeemRequestCount();
        assertEq(newCount, 69);

        {
            RedeemQueueV2.RedeemRequest memory newRequest = RManager.getRedeemRequestDetails(0);
            assertEq(newRequest.amount, oldRequest0.amount);
            assertEq(newRequest.maxRedeemableEth, oldRequest0.maxRedeemableEth);
            assertEq(newRequest.recipient, oldRequest0.recipient);
            assertEq(newRequest.height, oldRequest0.height);
            assertEq(newRequest.initiator, mockInitiators[0]);
        }
        {
            RedeemQueueV2.RedeemRequest memory newRequest = RManager.getRedeemRequestDetails(1);
            assertEq(newRequest.amount, oldRequest1.amount);
            assertEq(newRequest.maxRedeemableEth, oldRequest1.maxRedeemableEth);
            assertEq(newRequest.recipient, oldRequest1.recipient);
            assertEq(newRequest.height, oldRequest1.height);
            assertEq(newRequest.initiator, mockInitiators[1]);
        }
        {
            RedeemQueueV2.RedeemRequest memory newRequest = RManager.getRedeemRequestDetails(2);
            assertEq(newRequest.amount, oldRequest2.amount);
            assertEq(newRequest.maxRedeemableEth, oldRequest2.maxRedeemableEth);
            assertEq(newRequest.recipient, oldRequest2.recipient);
            assertEq(newRequest.height, oldRequest2.height);
            assertEq(newRequest.initiator, mockInitiators[2]);
        }
        {
            RedeemQueueV2.RedeemRequest memory newRequest = RManager.getRedeemRequestDetails(3);
            assertEq(newRequest.amount, oldRequest3.amount);
            assertEq(newRequest.maxRedeemableEth, oldRequest3.maxRedeemableEth);
            assertEq(newRequest.recipient, oldRequest3.recipient);
            assertEq(newRequest.height, oldRequest3.height);
            assertEq(newRequest.initiator, mockInitiators[3]);
        }
        {
            RedeemQueueV2.RedeemRequest memory newRequest = RManager.getRedeemRequestDetails(4);
            assertEq(newRequest.amount, oldRequest4.amount);
            assertEq(newRequest.maxRedeemableEth, oldRequest4.maxRedeemableEth);
            assertEq(newRequest.recipient, oldRequest4.recipient);
            assertEq(newRequest.height, oldRequest4.height);
            assertEq(newRequest.initiator, mockInitiators[4]);
        }
        {
            RedeemQueueV2.RedeemRequest memory newRequest = RManager.getRedeemRequestDetails(5);
            assertEq(newRequest.amount, oldRequest5.amount);
            assertEq(newRequest.maxRedeemableEth, oldRequest5.maxRedeemableEth);
            assertEq(newRequest.recipient, oldRequest5.recipient);
            assertEq(newRequest.height, oldRequest5.height);
            assertEq(newRequest.initiator, mockInitiators[5]);
        }
        {
            RedeemQueueV2.RedeemRequest memory newRequest = RManager.getRedeemRequestDetails(6);
            assertEq(newRequest.amount, oldRequest6.amount);
            assertEq(newRequest.maxRedeemableEth, oldRequest6.maxRedeemableEth);
            assertEq(newRequest.recipient, oldRequest6.recipient);
            assertEq(newRequest.height, oldRequest6.height);
            assertEq(newRequest.initiator, mockInitiators[6]);
        }

        // Hardcoded values are actual values on chain for redeem requests [7,8,68], created after the upgrade with wrong structure
        uint256 heightDeficit = oldRequest6.height + oldRequest6.amount;
        {
            RedeemQueueV2.RedeemRequest memory newRequest = RManager.getRedeemRequestDetails(7);
            assertEq(newRequest.amount, 10000000000000000);
            assertEq(newRequest.maxRedeemableEth, 10007129786415920);
            assertEq(newRequest.recipient, 0x4D1BED3a669186130DAaF5859B242f3c788D736A); // Direct address use
            assertEq(newRequest.height, heightDeficit);
            assertEq(newRequest.initiator, 0xFFC58B6a27f6354eba6BB8F39fE163a1625C4B5B); // Direct address use
        }
        {
            RedeemQueueV2.RedeemRequest memory newRequest = RManager.getRedeemRequestDetails(8);
            assertEq(newRequest.amount, 0);
            assertEq(newRequest.maxRedeemableEth, 1558642719466);
            assertEq(newRequest.recipient, 0x333E2068E43c2d85cd0C5B872d4E6bCE470D7f4b); // Direct address use
            assertEq(newRequest.height, 20000000000000000 + heightDeficit);
            assertEq(newRequest.initiator, 0xFFC58B6a27f6354eba6BB8F39fE163a1625C4B5B); // Direct address use
        }
        {
            RedeemQueueV2.RedeemRequest memory newRequest = RManager.getRedeemRequestDetails(68);
            assertEq(newRequest.amount, 10000000000000000);
            assertEq(newRequest.maxRedeemableEth, 10017806286899914);
            assertEq(newRequest.recipient, 0x333E2068E43c2d85cd0C5B872d4E6bCE470D7f4b); // Direct address use
            assertEq(newRequest.height, 3733452766809450500 + heightDeficit);
            assertEq(newRequest.initiator, 0xFFC58B6a27f6354eba6BB8F39fE163a1625C4B5B); // Direct address use
        }
    }
}
