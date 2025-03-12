//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

// import "forge-std/Test.sol";

// import "../../../src/TUPProxy.sol";
// import "../../../src/RedeemManager.1.sol";
// import "../../../src/state/redeemManager/RedeemQueue.1.sol";
// import "../../../src/state/redeemManager/RedeemQueue.2.sol";
// import "../../../src/state/redeemManager/WithdrawalStack.sol";
// import {ITransparentUpgradeableProxy} from
//     "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// interface MockIRedeemManagerV1 {
//     function getRedeemRequestDetails(uint32 _redeemRequestId)
//         external
//         view
//         returns (RedeemQueueV1.RedeemRequest memory);

//     function getRedeemRequestCount() external view returns (uint256);
// }

// contract RedeemQueueMigrationV1_2 is Test {
//     bool internal _skip = false;
//     string internal _rpcUrl;

//     address internal constant REDEEM_MANAGER_MAINNET_ADDRESS = 0x080b3a41390b357Ad7e8097644d1DEDf57AD3375;
//     address internal constant REDEEM_MANAGER_MAINNET_PROXY_ADMIN_ADDRESS = 0x2fDeF0b5e87Cf840FfE46E3A5318b1d59960DfCd;

//     function setUp() external {
//         try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
//             _rpcUrl = rpcUrl;
//             vm.createSelectFork(rpcUrl, 20677000);
//             console.log("1.RedeemQueueMigrationV1_2.t.sol is active");
//         } catch {
//             _skip = true;
//         }
//     }

//     function _generateRandomAddress(uint256 length) internal view returns (address[] memory) {
//         // Generate a random 20-byte address
//         address[] memory randomAddresses = new address[](length);

//         // Populate the array with random addresses
//         for (uint256 i = 0; i < length; i++) {
//             randomAddresses[i] =
//                 address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i)))));
//         }

//         return randomAddresses;
//     }

//     modifier shouldSkip() {
//         if (!_skip) {
//             _;
//         }
//     }

//     function test_migrate_allRequestInOneCall() external shouldSkip {
//         // Setting up the Redeem Manager
//         TUPProxy redeemManagerProxy = TUPProxy(payable(REDEEM_MANAGER_MAINNET_ADDRESS));

//         MockIRedeemManagerV1 RedeemManager = MockIRedeemManagerV1(REDEEM_MANAGER_MAINNET_ADDRESS);
//         uint256 oldCount = RedeemManager.getRedeemRequestCount();
//         RedeemQueueV1.RedeemRequest memory oldRequest0 = RedeemManager.getRedeemRequestDetails(0);
//         RedeemQueueV1.RedeemRequest memory oldRequest1 = RedeemManager.getRedeemRequestDetails(1);
//         RedeemQueueV1.RedeemRequest memory oldRequestN = RedeemManager.getRedeemRequestDetails(uint32(oldCount - 1));

//         address[] memory mockInitiators = _generateRandomAddress(oldCount);

//         // Set up the fork at a new block for testing the upgrade
//         vm.createSelectFork(_rpcUrl, 20678000);
//         // Upgrade the RedeemManager
//         RedeemManagerV1 newImplementation = new RedeemManagerV1();
//         vm.prank(REDEEM_MANAGER_MAINNET_PROXY_ADMIN_ADDRESS);
//         ITransparentUpgradeableProxy(address(redeemManagerProxy)).upgradeToAndCall(
//             address(newImplementation),
//             abi.encodeWithSelector(RedeemManagerV1.initializeRedeemManagerV1_2.selector, mockInitiators)
//         );

//         // After upgrade: check that state before the upgrade, and state after upgrade are same.
//         RedeemManagerV1 RManager = RedeemManagerV1(REDEEM_MANAGER_MAINNET_ADDRESS);
//         uint256 newCount = RedeemManager.getRedeemRequestCount();
//         assertEq(newCount, oldCount);

//         {
//             RedeemQueueV2.RedeemRequest memory newRequest = RManager.getRedeemRequestDetails(0);
//             assertEq(newRequest.amount, oldRequest0.amount);
//             assertEq(newRequest.maxRedeemableEth, oldRequest0.maxRedeemableEth);
//             assertEq(newRequest.recipient, oldRequest0.recipient);
//             assertEq(newRequest.height, oldRequest0.height);
//             assertEq(newRequest.initiator, mockInitiators[0]);
//         }
//         {
//             RedeemQueueV2.RedeemRequest memory newRequest = RManager.getRedeemRequestDetails(1);
//             assertEq(newRequest.amount, oldRequest1.amount);
//             assertEq(newRequest.maxRedeemableEth, oldRequest1.maxRedeemableEth);
//             assertEq(newRequest.recipient, oldRequest1.recipient);
//             assertEq(newRequest.height, oldRequest1.height);
//             assertEq(newRequest.initiator, mockInitiators[1]);
//         }
//         {
//             RedeemQueueV2.RedeemRequest memory newRequest = RManager.getRedeemRequestDetails(uint32(newCount - 1));
//             assertEq(newRequest.amount, oldRequestN.amount);
//             assertEq(newRequest.maxRedeemableEth, oldRequestN.maxRedeemableEth);
//             assertEq(newRequest.recipient, oldRequestN.recipient);
//             assertEq(newRequest.height, oldRequestN.height);
//             assertEq(newRequest.initiator, mockInitiators[newCount - 1]);
//         }
//     }
// }
