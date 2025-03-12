// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {BaseGoerliParameters} from "./utils/parameters/BaseGoerliParameters.sol";
import {BaseParameters} from "./utils/parameters/BaseParameters.sol";
import {OptimismGoerliParameters} from
    "./utils/parameters/OptimismGoerliParameters.sol";
import {OptimismParameters} from "./utils/parameters/OptimismParameters.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {Zap} from "../src/Zap.sol";
import {ZapExposed} from "../test/utils/exposed/ZapExposed.sol";

/// @title Zap deployment script
/// @notice ZapExposed is deployed (not Zap) and
/// ZapExposed is unsafe and not meant for production
/// @author JaredBorders (jaredborders@pm.me)
contract Setup is Script {
    function deploySystem(
        address _usdc,
        address _susd,
        address _spotMarketProxy,
        uint128 _sUSDCId
    ) public returns (address zapAddress) {
        zapAddress =
            address(new ZapExposed(_usdc, _susd, _spotMarketProxy, _sUSDCId));
    }
}

/// @dev steps to deploy and verify on Base:
/// (1) load the variables in the .env file via `source .env`
/// (2) run `forge script script/Deploy.s.sol:DeployBase --rpc-url $BASE_RPC_URL --etherscan-api-key $BASESCAN_API_KEY --broadcast --verify -vvvv`
contract DeployBase is Setup, BaseParameters {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        Setup.deploySystem(
            USDC, USD_PROXY, SPOT_MARKET_PROXY, SUSDC_SPOT_MARKET_ID
        );

        vm.stopBroadcast();
    }
}

/// @dev steps to deploy and verify on Base Goerli:
/// (1) load the variables in the .env file via `source .env`
/// (2) run `forge script script/Deploy.s.sol:DeployBaseGoerli --rpc-url $BASE_GOERLI_RPC_URL --etherscan-api-key $BASESCAN_API_KEY --broadcast --verify -vvvv`
contract DeployBaseGoerli is Setup, BaseGoerliParameters {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        Setup.deploySystem(
            USDC, USD_PROXY, SPOT_MARKET_PROXY, SUSDC_SPOT_MARKET_ID
        );

        vm.stopBroadcast();
    }
}

/// @dev steps to deploy and verify on Optimism:
/// (1) load the variables in the .env file via `source .env`
/// (2) run `forge script script/Deploy.s.sol:DeployOptimism --rpc-url $OPTIMISM_RPC_URL --etherscan-api-key $OPTIMISM_ETHERSCAN_API_KEY --broadcast --verify -vvvv`
contract DeployOptimism is Setup, OptimismParameters {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        Setup.deploySystem(
            USDC, USD_PROXY, SPOT_MARKET_PROXY, SUSDC_SPOT_MARKET_ID
        );

        vm.stopBroadcast();
    }
}

/// @dev steps to deploy and verify on Optimism Goerli:
/// (1) load the variables in the .env file via `source .env`
/// (2) run `forge script script/Deploy.s.sol:DeployOptimismGoerli --rpc-url $OPTIMISM_GOERLI_RPC_URL --etherscan-api-key $OPTIMISM_ETHERSCAN_API_KEY --broadcast --verify -vvvv`

contract DeployOptimismGoerli is Setup, OptimismGoerliParameters {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        Setup.deploySystem(
            USDC, USD_PROXY, SPOT_MARKET_PROXY, SUSDC_SPOT_MARKET_ID
        );

        vm.stopBroadcast();
    }
}
