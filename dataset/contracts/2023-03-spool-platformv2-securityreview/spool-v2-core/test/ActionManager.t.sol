// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import "../src/managers/ActionManager.sol";
import "./mocks/MockToken.sol";
import "../src/access/SpoolAccessControl.sol";

import {MockAction, MockActionSetAmountTo100} from "./mocks/MockAction.sol";

contract ActionManagerTest is Test {
    IActionManager actionManager;
    IAction mockAction;
    MockToken mockToken;

    address smartVaultId = address(1);
    address user = address(256);

    function setUp() public {
        SpoolAccessControl accessControl = new SpoolAccessControl();
        accessControl.initialize();

        actionManager = new ActionManager(accessControl);
        mockAction = new MockAction();
        mockToken = new MockToken("MCK", "MCK");

        accessControl.grantRole(ROLE_SMART_VAULT_INTEGRATOR, address(this));
        accessControl.grantRole(ROLE_SMART_VAULT_MANAGER, smartVaultId);
    }

    function test_whitelistAction_addressIsNotWhitelisted() public {
        actionManager.whitelistAction(address(mockAction), true);
        vm.expectRevert(abi.encodeWithSelector(ActionStatusAlreadySet.selector));
        actionManager.whitelistAction(address(mockAction), true);
    }

    function test_setAction_tryAddingBlacklistedAction() public {
        IAction[] memory actions = new IAction[](1);
        actions[0] = mockAction;
        RequestType[] memory requestTypes = new RequestType[](1);
        requestTypes[0] = RequestType.Deposit;

        vm.expectRevert(abi.encodeWithSelector(InvalidAction.selector, address(mockAction)));
        actionManager.setActions(smartVaultId, actions, requestTypes);
    }

    function test_setAction() public {
        IAction[] memory actions = new IAction[](2);
        actions[0] = mockAction;
        RequestType[] memory requestTypes = new RequestType[](2);
        requestTypes[0] = RequestType.Deposit;
        requestTypes[1] = RequestType.Deposit;

        IAction mockActionSetsAmountsTo100 = new MockActionSetAmountTo100();
        actions[1] = mockActionSetsAmountsTo100;

        actionManager.whitelistAction(address(mockAction), true);
        actionManager.whitelistAction(address(mockActionSetsAmountsTo100), true);

        actionManager.setActions(smartVaultId, actions, requestTypes);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        ActionContext memory actionContext = ActionContext(
            smartVaultId, address(user), address(user), address(user), RequestType.Deposit, tokens, amounts
        );

        vm.prank(smartVaultId);
        actionManager.runActions(actionContext);
    }
}
