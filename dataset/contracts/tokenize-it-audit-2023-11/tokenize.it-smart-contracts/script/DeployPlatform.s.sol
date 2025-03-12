// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// taken from https://moveseventyeight.com/deploy-your-first-nft-contract-with-foundry#heading-prepare-a-basic-deployment-script

import "../lib/forge-std/src/Script.sol";
import "../contracts/factories/FeeSettingsCloneFactory.sol";
import "../contracts/factories/AllowListCloneFactory.sol";
import "../contracts/factories/PrivateOfferFactory.sol";
import "../contracts/factories/VestingCloneFactory.sol";

contract DeployPlatform is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        // Goerli
        //address platformColdWallet = 0x1695F52e342f3554eC8BC06621B7f5d1644cCE39;
        //address platformAdminWallet = 0x1695F52e342f3554eC8BC06621B7f5d1644cCE39;

        // Mainnet
        address platformColdWallet = 0x9E23f8AA17B2721cf69D157b8a15bd7b64ac881C;
        address trustedForwarder = 0xAa3E82b4c4093b4bA13Cb5714382C99ADBf750cA;

        console.log("Deployer address: ", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying FeeSettingsCloneFactory contract...");
        FeeSettings feeSettingsLogicContract = new FeeSettings(trustedForwarder);
        FeeSettingsCloneFactory feeSettingsCloneFactory = new FeeSettingsCloneFactory(
            address(feeSettingsLogicContract)
        );
        console.log("FeeSettingsCloneFactory deployed at: ", address(feeSettingsCloneFactory));

        console.log("Deploying FeeSettings contract...");
        Fees memory fees = Fees(1, 100, 1, 100, 1, 100, 0);
        FeeSettings feeSettings = FeeSettings(
            feeSettingsCloneFactory.createFeeSettingsClone(
                bytes32(0),
                trustedForwarder,
                platformColdWallet,
                fees,
                platformColdWallet,
                platformColdWallet,
                platformColdWallet
            )
        );
        console.log("FeeSettings deployed at: ", address(feeSettings));
        feeSettings.transferOwnership(platformColdWallet);
        console.log("Started ownership transfer to: ", platformColdWallet);

        console.log("Deploying AllowListCloneFactory contract...");
        AllowList allowListLogicContract = new AllowList(trustedForwarder);
        AllowListCloneFactory allowListCloneFactory = new AllowListCloneFactory(address(allowListLogicContract));
        console.log("AllowListCloneFactory deployed at: ", address(allowListCloneFactory));

        console.log("Deploying AllowList contract...");
        AllowList allowList = AllowList(
            allowListCloneFactory.createAllowListClone(bytes32(0), trustedForwarder, platformColdWallet)
        );
        console.log("Allowlist deployed at: ", address(allowList));

        console.log("Deploying VestingCloneFactory contract...");
        Vesting vestingImplementation = new Vesting(trustedForwarder);
        VestingCloneFactory vestingCloneFactory = new VestingCloneFactory(address(vestingImplementation));
        console.log("VestingCloneFactory deployed at: ", address(vestingCloneFactory));

        console.log("Deploying PrivateOfferFactory contract...");
        PrivateOfferFactory privateOfferFactory = new PrivateOfferFactory(vestingCloneFactory);
        console.log("PrivateOfferFactory deployed at: ", address(privateOfferFactory));

        vm.stopBroadcast();

        console.log("Don't forget to check and finalize ownership transfers for all contracts!");
    }
}
