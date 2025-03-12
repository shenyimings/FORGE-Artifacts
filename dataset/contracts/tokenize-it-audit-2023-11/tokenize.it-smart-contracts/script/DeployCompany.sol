// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// taken from https://moveseventyeight.com/deploy-your-first-nft-contract-with-foundry#heading-prepare-a-basic-deployment-script

import "../lib/forge-std/src/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/FeeSettings.sol";
import "../contracts/AllowList.sol";
import "../contracts/factories/PrivateOfferFactory.sol";
import "../contracts/Token.sol";
import "../contracts/Crowdinvesting.sol";
import "../contracts/PrivateOffer.sol";

contract DeployCompany is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        AllowList allowList = AllowList(0x47EE5950B9a790A292B731789a35CcCB7381667E);
        FeeSettings feeSettings = FeeSettings(0x147addF9C8E4030F8104c713Dad2A1d76E6c85a1);

        vm.startBroadcast(deployerPrivateKey);
        console.log("Deployer address: ", deployerAddress);

        console.log("FeeSettings at: ", address(feeSettings));
        console.log("Allowlist at: ", address(allowList));
        // ERC20 usdc = ERC20(0x07865c6E87B9F70255377e024ace6630C1Eaa37F);

        // address companyAdmin = 0x6CcD9E07b035f9E6e7f086f3EaCf940187d03A29; // testing founder
        // address forwarder = 0x0445d09A1917196E1DC12EdB7334C70c1FfB1623;
        // address investor = 0x35bb2Ded62588f7fb3771658dbE699826Cd1041A;

        // string memory name = "MyTasticToken";
        // string memory symbol = "MTT";
        // uint256 requirements = 0x0;

        // console.log("Deploying Token contract...");

        // Token token = new Token(forwarder, feeSettings, companyAdmin, allowList, requirements, name, symbol);

        // Token token = Token(0x6BC442F04C727a19Cc0AF14ec9b2acD3e12651F3);
        // console.log("Token at: ", address(token));

        // Crowdinvesting fundraising = new Crowdinvesting(
        //     forwarder,
        //     companyAdmin,
        //     0,
        //     1000 * 10 ** 18,
        //     3 * 10 ** 6,
        //     100000 * 10 ** 18,
        //     usdc,
        //     token
        // );

        // console.log("Fundraising deployed at: ", address(fundraising));
        // fundraising.transferOwnership(companyAdmin);
        // console.log("Fundraising ownership transferred to: ", companyAdmin);

        // // manual deployment of private offer for verification
        // //  calculate private offer address
        // //uint256 nextNonce = vm.getNonce(deployerAddress) - 3;
        // address nextContract = address(
        //     uint160(
        //         uint256(
        //             keccak256(
        //                 abi.encodePacked(
        //                     bytes1(0xd6),
        //                     bytes1(0x94),
        //                     deployerAddress,
        //                     bytes1(0x1f) // replace 0x1f with nextNonce in hex
        //                 )
        //             )
        //         )
        //     )
        // );
        // console.log("Next contract address: ", nextContract);

        // PrivateOffer privateOffer = new PrivateOffer(
        //     investor,
        //     investor,
        //     companyAdmin,
        //     100 * 10 ** 18,
        //     3 * 10 ** 5, // 30 usdc
        //     1676641750 + 1 days,
        //     usdc,
        //     token
        // );

        // console.log("PrivateOffer deployed at: ", address(privateOffer));

        vm.stopBroadcast();
    }
}
