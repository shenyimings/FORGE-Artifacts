// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../../src/interfaces/RequestType.sol";
import "../../src/managers/ActionManager.sol";
import "../../src/managers/AssetGroupRegistry.sol";
import "../../src/managers/GuardManager.sol";
import "../../src/managers/RiskManager.sol";
import "../../src/managers/SmartVaultManager.sol";
import "../../src/managers/StrategyRegistry.sol";
import "../../src/managers/UsdPriceFeedManager.sol";
import "../../src/MasterWallet.sol";
import "../../src/SmartVault.sol";
import "../../src/SmartVaultFactory.sol";
import "../../src/Swapper.sol";
import "../mocks/MockStrategy.sol";
import "../mocks/MockNft.sol";
import "../mocks/MockToken.sol";
import "../mocks/MockPriceFeedManager.sol";
import "../libraries/Arrays.sol";
import "../fixtures/TestFixture.sol";

contract NftGateGuardDemoTest is TestFixture {
    address private alice;
    address private bob;
    address private charlie;
    address private eve;

    MockNft private nft;

    function setUp() public {
        alice = address(0xa);
        bob = address(0xb);
        charlie = address(0xc);
        eve = address(0xe);

        nft = new MockNft("Nft", "N");

        setUpBase();

        uint256 assetGroupId;
        {
            address[] memory assetGroup = new address[](1);
            assetGroup[0] = address(token);
            assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);
        }

        MockStrategy strategy = new MockStrategy("Strategy", assetGroupRegistry, accessControl, swapper);
        {
            uint256[] memory strategyRatios = new uint256[](1);
            strategyRatios[0] = 1_000;
            strategy.initialize(assetGroupId, strategyRatios);
            strategyRegistry.registerStrategy(address(strategy));
        }

        (GuardDefinition[][] memory guards, RequestType[] memory guardRequestTypes) = setUpNftGateGuard();

        {
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(1_000))
            );

            smartVault = smartVaultFactory.deploySmartVault(
                SmartVaultSpecification({
                    smartVaultName: "SmartVault",
                    assetGroupId: assetGroupId,
                    actions: new IAction[](0),
                    actionRequestTypes: new RequestType[](0),
                    guards: guards,
                    guardRequestTypes: guardRequestTypes,
                    strategies: Arrays.toArray(address(strategy)),
                    strategyAllocation: uint16a16.wrap(0),
                    riskTolerance: 4,
                    riskProvider: riskProvider,
                    managementFeePct: 0,
                    depositFeePct: 0,
                    allowRedeemFor: false,
                    allocationProvider: address(allocationProvider),
                    performanceFeePct: 0
                })
            );
        }
    }

    function setUpNftGateGuard() private returns (GuardDefinition[][] memory, RequestType[] memory) {
        // Setup smart vault with one guard:
        // - check that the person receiving the deposit NFT has at least one selected NFT
        // The guard is implemented using the `balanceOf` function of the IERC721 contract.
        GuardDefinition[][] memory guards = new GuardDefinition[][](1);
        guards[0] = new GuardDefinition[](1);

        // guard call receives one parameter:
        // - address to check the NFT balance of
        GuardParamType[] memory guardParamTypes = new GuardParamType[](1);
        bytes[] memory guardParamValues = new bytes[](0);

        // the guard will check the NFT balance of the receiver
        guardParamTypes[0] = GuardParamType.Receiver;

        // define the guard
        guards[0][0] = GuardDefinition({ // guard checking the NFT balance of the receiver
            contractAddress: address(nft),
            methodSignature: "balanceOf(address)",
            methodParamTypes: guardParamTypes,
            methodParamValues: guardParamValues,
            operator: ">=", // balance must be equal to or greater than 1
            expectedValue: bytes32(uint256(1))
        });

        RequestType[] memory requestTypes = new RequestType[](1);
        requestTypes[0] = RequestType.Deposit;

        // mint one NFT for Bob and two NFTs for Charlie
        nft.mint(bob);
        nft.mint(charlie);
        nft.mint(charlie);

        return (guards, requestTypes);
    }

    function test() public {
        token.mint(alice, 2 ether);

        vm.prank(alice);
        token.approve(address(smartVaultManager), 2 ether);

        uint256[] memory depositAmounts = new uint256[](1);
        depositAmounts[0] = 1 ether;

        vm.prank(alice);
        // deposit for Bob who has one NFT, should pass
        smartVaultManager.deposit(DepositBag(address(smartVault), depositAmounts, bob, address(0), false));
        vm.prank(alice);
        // deposit for Charlie who has two NFTs, should pass
        smartVaultManager.deposit(DepositBag(address(smartVault), depositAmounts, charlie, address(0), false));
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(GuardFailed.selector, 0));
        // deposit for Eve who doesn't have any NFT, should fail
        smartVaultManager.deposit(DepositBag(address(smartVault), depositAmounts, eve, address(0), false));
    }
}
