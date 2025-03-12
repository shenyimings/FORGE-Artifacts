// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// taken from https://moveseventyeight.com/deploy-your-first-nft-contract-with-foundry#heading-prepare-a-basic-deployment-script

import "../lib/forge-std/src/Script.sol";
import "../contracts/FeeSettings.sol";
import "../contracts/AllowList.sol";
import "../contracts/factories/PrivateOfferFactory.sol";
import "../contracts/Token.sol";

/*
    This script is used to check the deployed token contract.
    It is not meant to be used in production, but rather as a reference for how to interact with the deployed contracts.

    To run this script, use the following command:
        forge script CheckToken.sol --rpc-url $GOERLI_RPC_URL

*/

address constant TOKEN_ADDRESS = 0x9693f471524Ba0629e540f368573711C76ACBABa;
address constant TRUSTED_FORWARDER = 0x994257AcCF99E5995F011AB2A3025063e5367629;
address constant FEE_SETTINGS = 0x147addF9C8E4030F8104c713Dad2A1d76E6c85a1;
address constant ALLOW_LIST = 0x274ca5f21Cdde06B6E4Fe063f5087EB6Cf3eAe55;
address constant ADMIN = 0x45a1cbD9788f5eA4061640ad7CB55031AE62b9dB;
bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

contract CheckToken is Script {
    function run() public view {
        Token token = Token(address(TOKEN_ADDRESS));

        console.log("Remember to update addresses in this script in order to check other deployments.");

        console.log("Token name: ", token.name());
        console.log("Token symbol: ", token.symbol());
        console.log("Token fee settings matches: ", address(token.feeSettings()) == FEE_SETTINGS);
        console.log(
            "Token trusted forwarder matches: ",
            token.isTrustedForwarder(0x994257AcCF99E5995F011AB2A3025063e5367629)
        );
        console.log("Token allow list matches: ", address(token.allowList()) == ALLOW_LIST);
        console.log("Token admin matches: ", token.hasRole(DEFAULT_ADMIN_ROLE, ADMIN));
    }
}
