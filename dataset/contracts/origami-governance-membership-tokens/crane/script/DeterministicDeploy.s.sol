// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {OrigamiGovernanceToken} from "src/OrigamiGovernanceToken.sol";
import {OrigamiMembershipToken} from "src/OrigamiMembershipToken.sol";
import {ERC20Base} from "src/token/governance/ERC20Base.sol";

import {Script, console2} from "@std/Script.sol";
import {TransparentUpgradeableProxy} from "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import {CREATE3Factory} from "@create3/CREATE3Factory.sol";

contract DeterministicDeployHelper is Script {
    function transparentProxyByteCode(address implementation, address proxyAdmin) public pure returns (bytes memory) {
        bytes memory contractBytecode = type(TransparentUpgradeableProxy).creationCode;
        bytes memory encodedInitialization = abi.encode(implementation, proxyAdmin, "");
        return abi.encodePacked(contractBytecode, encodedInitialization);
    }

    function deploy(address create3Factory, address implementation, address proxyAdmin, string memory salt)
        public
        returns (address)
    {
        CREATE3Factory c3 = CREATE3Factory(create3Factory);
        bytes memory bytecode = transparentProxyByteCode(implementation, proxyAdmin);

        return c3.deploy(bytes32(bytes(salt)), bytecode);
    }
}

contract DeterministicDeploy is DeterministicDeployHelper {
    function getDeterministicAddress(address create3Factory, address deployer, string calldata salt)
        public
        view
        returns (address)
    {
        return CREATE3Factory(create3Factory).getDeployed(deployer, bytes32(bytes(salt)));
    }

    function deployCreate3Factory() public {
        vm.startBroadcast();
        CREATE3Factory c3 = new CREATE3Factory();
        // solhint-disable-next-line no-console
        console2.log("CREATE3Factory deployed at", address(c3));
        vm.stopBroadcast();
    }

    function deployERC20BaseImpl(address create3Factory, string memory salt) public {
        CREATE3Factory c3 = CREATE3Factory(create3Factory);
        bytes memory bytecode = type(ERC20Base).creationCode;
        salt = string.concat("erc20-base-", salt);

        vm.startBroadcast();
        address erc20Base = c3.deploy(bytes32(bytes(salt)), bytecode);
        // solhint-disable-next-line no-console
        console2.log("ERC20Base deployed at", erc20Base);
        vm.stopBroadcast();
    }

    function deployGovernanceTokenImpl(address create3Factory, string memory salt) public {
        CREATE3Factory c3 = CREATE3Factory(create3Factory);
        bytes memory bytecode = type(OrigamiGovernanceToken).creationCode;
        salt = string.concat("gov-token-", salt);

        vm.startBroadcast();
        address govToken = c3.deploy(bytes32(bytes(salt)), bytecode);
        // solhint-disable-next-line no-console
        console2.log("OrigamiGovernanceToken deployed at", govToken);
        vm.stopBroadcast();
    }
}

contract DeterministicallyDeployMembershipToken is DeterministicDeployHelper {
    function deployMembershipTokenProxy(
        address implementation,
        address proxyAdmin,
        address contractAdmin,
        string calldata orgSnowflake,
        string calldata name,
        string calldata symbol,
        string calldata baseUri
    ) public {
        vm.startBroadcast();
        address memTokenProxy = deploy(
            vm.envAddress("CREATE3_FACTORY"),
            implementation,
            proxyAdmin,
            string.concat("membership-token-", orgSnowflake)
        );
        OrigamiMembershipToken token = OrigamiMembershipToken(memTokenProxy);
        token.initialize(contractAdmin, name, symbol, baseUri);
        vm.stopBroadcast();
    }
}

contract DeterministicallyDeployGovernanceToken is DeterministicDeployHelper {
    function deployGovernanceTokenProxy(
        address implementation,
        address proxyAdmin,
        address contractAdmin,
        string calldata orgSnowflake,
        string calldata name,
        string calldata symbol,
        uint256 supplyCap
    ) public {
        vm.startBroadcast();
        address govTokenProxy = deploy(
            vm.envAddress("CREATE3_FACTORY"),
            implementation,
            proxyAdmin,
            string.concat("governance-token-", orgSnowflake)
        );
        OrigamiGovernanceToken token = OrigamiGovernanceToken(govTokenProxy);
        token.initialize(contractAdmin, name, symbol, supplyCap);
        vm.stopBroadcast();
    }
}
