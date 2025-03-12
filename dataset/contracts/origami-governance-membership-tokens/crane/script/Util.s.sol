// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {IAccessControl} from "src/interfaces/IAccessControl.sol";
import {OrigamiGovernanceToken} from "src/OrigamiGovernanceToken.sol";
import {L2StandardERC20} from "src/utils/L2StandardERC20.sol";

import {ProxyAdmin} from "@oz/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Script} from "@std/Script.sol";

contract GrantPermissions is Script {
    bytes32 internal constant REVOKER_ROLE = 0xce3f34913921da558f105cefb578d87278debbbd073a8d552b5de0d168deee30;
    bytes32 internal constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;

    function run(address target, address[] calldata accounts) external {
        vm.startBroadcast();

        IAccessControl accessControl = IAccessControl(target);
        for (uint256 i = 0; i < accounts.length; i++) {
            accessControl.grantRole(REVOKER_ROLE, accounts[i]);
            accessControl.grantRole(MINTER_ROLE, accounts[i]);
        }

        vm.stopBroadcast();
    }
}

contract ConfigureContractsForBridge is Script {
    function configureGovernanceTokenProxyForL2(address govTokenProxy, address l2Bridge, address contractAdmin)
        public
    {
        vm.startBroadcast();
        L2StandardERC20 token = L2StandardERC20(govTokenProxy);
        token.setL1Token(govTokenProxy); // relies on CREATE3Factory to deploy to same address on L1 and L2
        token.setL2Bridge(l2Bridge);

        OrigamiGovernanceToken govToken = OrigamiGovernanceToken(govTokenProxy);
        govToken.enableTransfer();
        govToken.enableBurn();
        govToken.revokeRole(govToken.MINTER_ROLE(), contractAdmin);
        govToken.grantRole(govToken.MINTER_ROLE(), l2Bridge);
        govToken.grantRole(govToken.BURNER_ROLE(), l2Bridge);
        vm.stopBroadcast();
    }

    function configureGovernanceTokenProxyForL1(address govTokenProxy) public {
        vm.startBroadcast();
        OrigamiGovernanceToken govToken = OrigamiGovernanceToken(govTokenProxy);
        govToken.enableTransfer();
        govToken.enableBurn();
        vm.stopBroadcast();
    }
}

contract DeployAndRenounceNewProxyAdmin is Script {
    function run(address oldProxyAdmin, address payable transparentProxy) public {
        vm.startBroadcast();
        ProxyAdmin oldAdmin = ProxyAdmin(oldProxyAdmin);
        ProxyAdmin newProxyAdmin = new ProxyAdmin();
        TransparentUpgradeableProxy tug = TransparentUpgradeableProxy(transparentProxy);
        oldAdmin.changeProxyAdmin(tug, address(newProxyAdmin));
        newProxyAdmin.renounceOwnership();
        vm.stopBroadcast();
    }
}
