// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/FeeSettings.sol";
import "./resources/WrongFeeSettings.sol";
import "./resources/CloneCreators.sol";

contract tokenTest is Test {
    event AllowListChanged(AllowList indexed newAllowList);
    event NewFeeSettingsSuggested(IFeeSettingsV1 indexed _feeSettings);
    event FeeSettingsChanged(IFeeSettingsV1 indexed newFeeSettings);

    Token token;
    AllowList allowList;
    FeeSettings feeSettings;
    address public constant trustedForwarder = 0x9109709EcFA91A80626FF3989D68f67F5B1dD129;
    address public constant admin = 0x0109709eCFa91a80626FF3989D68f67f5b1dD120;
    address public constant requirer = 0x1109709ecFA91a80626ff3989D68f67F5B1Dd121;
    address public constant mintAllower = 0x2109709EcFa91a80626Ff3989d68F67F5B1Dd122;
    address public constant minter = 0x3109709ECfA91A80626fF3989D68f67F5B1Dd123;
    address public constant burner = 0x4109709eCFa91A80626ff3989d68F67f5b1DD124;
    address public constant transfererAdmin = 0x5109709EcFA91a80626ff3989d68f67F5B1dD125;
    address public constant transferer = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;
    address public constant pauser = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;
    address public constant feeSettingsOwner = 0x8109709ecfa91a80626fF3989d68f67F5B1dD128;

    event RequirementsChanged(uint256 newRequirements);

    function setUp() public {
        allowList = createAllowList(trustedForwarder, admin);
        Fees memory fees = Fees(1, 100, 1, 100, 1, 100, 0);
        feeSettings = createFeeSettings(trustedForwarder, feeSettingsOwner, fees, admin, admin, admin);
        Token implementation = new Token(trustedForwarder);
        TokenProxyFactory tokenCloneFactory = new TokenProxyFactory(address(implementation));
        token = Token(
            tokenCloneFactory.createTokenProxy(
                0,
                trustedForwarder,
                feeSettings,
                admin,
                allowList,
                0x0,
                "testToken",
                "TEST"
            )
        );
        console.log(msg.sender);

        // set up roles
        vm.startPrank(admin);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.TRANSFERER_ROLE(), transferer);
        token.grantRole(token.PAUSER_ROLE(), pauser);
        token.grantRole(token.REQUIREMENT_ROLE(), requirer);
        token.grantRole(token.MINTALLOWER_ROLE(), mintAllower);
        token.grantRole(token.TRANSFERERADMIN_ROLE(), transfererAdmin);

        // revoke roles from admin
        token.revokeRole(token.BURNER_ROLE(), admin);
        token.revokeRole(token.TRANSFERER_ROLE(), admin);
        token.revokeRole(token.PAUSER_ROLE(), admin);
        token.revokeRole(token.REQUIREMENT_ROLE(), admin);
        token.revokeRole(token.MINTALLOWER_ROLE(), admin);
        token.revokeRole(token.TRANSFERERADMIN_ROLE(), admin);

        vm.stopPrank();
    }

    function testUpdateAllowList() public {
        AllowList newAllowList = createAllowList(trustedForwarder, admin); // deploy new AllowList
        assertTrue(token.allowList() != newAllowList);
        vm.prank(admin);
        vm.expectEmit(true, true, true, true, address(token));
        emit AllowListChanged(newAllowList);
        token.setAllowList(newAllowList);
        assertTrue(token.allowList() == newAllowList);
    }

    function testUpdateAllowList0() public {
        vm.expectRevert("AllowList must not be zero address");
        vm.prank(admin);
        token.setAllowList(AllowList(address(0)));
    }

    function testSuggestNewFeeSettingsWrongCaller(address wrongUpdater) public {
        vm.assume(wrongUpdater != feeSettings.owner());
        Fees memory fees = Fees(0, 1, 0, 1, 0, 1, 0);
        FeeSettings newFeeSettings = createFeeSettings(trustedForwarder, address(this), fees, pauser, pauser, pauser);
        vm.prank(wrongUpdater);
        vm.expectRevert("Only fee settings owner can suggest fee settings update");
        token.suggestNewFeeSettings(newFeeSettings);
    }

    function testSuggestNewFeeSettingsFeeCollector() public {
        Fees memory fees = Fees(0, 1, 0, 1, 0, 1, 0);
        FeeSettings newFeeSettings = createFeeSettings(trustedForwarder, address(this), fees, pauser, pauser, pauser);
        vm.prank(feeSettings.feeCollector());
        vm.expectRevert("Only fee settings owner can suggest fee settings update");
        token.suggestNewFeeSettings(newFeeSettings);
    }

    function testSuggestNewFeeSettings0() public {
        vm.prank(feeSettings.owner());
        vm.expectRevert();
        token.suggestNewFeeSettings(FeeSettings(address(0)));
    }

    function testSuggestNewFeeSettings(address newCollector) public {
        vm.assume(newCollector != address(0));
        Fees memory fees = Fees(0, 1, 0, 1, 0, 1, 0);
        FeeSettings newFeeSettings = createFeeSettings(
            trustedForwarder,
            address(this),
            fees,
            newCollector,
            newCollector,
            newCollector
        );
        FeeSettings oldFeeSettings = FeeSettings(address(token.feeSettings()));
        uint oldInvestmentFeeDenominator = oldFeeSettings.defaultCrowdinvestingFeeDenominator();
        uint oldTokenFeeDenominator = oldFeeSettings.defaultTokenFeeDenominator();
        vm.expectEmit(true, true, true, true, address(token));
        emit NewFeeSettingsSuggested(newFeeSettings);
        vm.prank(feeSettings.owner());
        token.suggestNewFeeSettings(newFeeSettings);

        // make sure old fees are still in effect
        assertTrue(
            address(FeeSettings(address(token.feeSettings()))) == address(oldFeeSettings),
            "fee settings have changed!"
        );
        assertTrue(token.suggestedFeeSettings() == newFeeSettings, "suggested fee settings not set!");
        assertTrue(
            FeeSettings(address(token.feeSettings())).defaultCrowdinvestingFeeDenominator() ==
                oldInvestmentFeeDenominator,
            "investment fee denominator changed!"
        );
        assertTrue(
            FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator() == oldTokenFeeDenominator,
            "token fee denominator changed!"
        );
    }

    function testAcceptNewFeeSettings(address newCollector) public {
        vm.assume(newCollector != address(0));
        Fees memory fees = Fees(0, 1, 0, 1, 0, 1, 0);
        FeeSettings newFeeSettings = createFeeSettings(
            trustedForwarder,
            address(this),
            fees,
            newCollector,
            newCollector,
            newCollector
        );
        FeeSettings oldFeeSettings = FeeSettings(address(token.feeSettings()));
        uint oldInvestmentFeeDenominator = oldFeeSettings.defaultCrowdinvestingFeeDenominator();
        uint oldTokenFeeDenominator = oldFeeSettings.defaultTokenFeeDenominator();
        vm.prank(feeSettings.owner());
        token.suggestNewFeeSettings(newFeeSettings);

        // accept
        vm.expectEmit(true, true, true, true, address(token));
        emit FeeSettingsChanged(newFeeSettings);
        vm.prank(admin);
        token.acceptNewFeeSettings(newFeeSettings);
        assertTrue(FeeSettings(address(token.feeSettings())) == newFeeSettings, "fee settings not changed!");
        assertEq(FeeSettings(address(token.feeSettings())).feeCollector(), newCollector, "Wrong feeCollector");
        assertTrue(
            FeeSettings(address(token.feeSettings())).defaultCrowdinvestingFeeDenominator() !=
                oldInvestmentFeeDenominator,
            "investment fee denominator changed!"
        );
        assertTrue(
            FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator() != oldTokenFeeDenominator,
            "token fee denominator changed!"
        );
    }

    function testAcceptFeeCollectorInsteadOfFeeSettings(address newFeeSettingsPretendAddress) public {
        vm.assume(newFeeSettingsPretendAddress != address(0));
        Fees memory fees = Fees(0, 1, 0, 1, 0, 1, 0);
        FeeSettings newFeeSettings = createFeeSettings(
            trustedForwarder,
            address(this),
            fees,
            newFeeSettingsPretendAddress,
            newFeeSettingsPretendAddress,
            newFeeSettingsPretendAddress
        );
        vm.assume(newFeeSettingsPretendAddress != address(newFeeSettings));

        vm.prank(feeSettings.owner());
        token.suggestNewFeeSettings(newFeeSettings);
        console.log("Suggested fee settings: ", address(newFeeSettings));

        // admin thinks he is accepting a, but suggestion is b
        vm.expectRevert();
        vm.prank(admin);
        token.acceptNewFeeSettings(FeeSettings(newFeeSettingsPretendAddress));
    }

    function testAcceptWrongFeeSettings() public {
        Fees memory fees = Fees(0, 1, 0, 1, 0, 1, 0);
        FeeSettings realNewFeeSettings = createFeeSettings(
            trustedForwarder,
            feeSettings.owner(),
            fees,
            feeSettings.feeCollector(),
            feeSettings.feeCollector(),
            feeSettings.feeCollector()
        );
        FeeSettings fakeNewFeeSettings = createFeeSettings(
            trustedForwarder,
            address(this),
            fees,
            feeSettings.feeCollector(),
            feeSettings.feeCollector(),
            feeSettings.feeCollector()
        );

        assertTrue(
            address(fakeNewFeeSettings) != address(realNewFeeSettings),
            "fakeNewFeeSettings == realNewFeeSettings, that should never happen"
        );

        vm.prank(feeSettings.owner());
        token.suggestNewFeeSettings(realNewFeeSettings);
        console.log("Suggested fee settings: ", address(realNewFeeSettings));

        // admin thinks he is accepting a, but suggestion is b
        vm.expectRevert("Only suggested fee settings can be accepted");
        vm.prank(admin);
        token.acceptNewFeeSettings(fakeNewFeeSettings);
    }

    function testFeeCollectorCanAlwaysReceiveFee() public {
        address tokenHolder = vm.addr(1);
        address localMinter = vm.addr(2);
        address feeCollector = feeSettings.feeCollector();

        console.log("Token holder: ", tokenHolder);
        console.log("Local minter: ", localMinter);
        console.log("Fee collector: ", feeSettings.feeCollector());
        console.log("transfererAdmin: ", transfererAdmin);
        console.log("mintAllower: ", mintAllower);
        console.log("this: ", address(this));

        // set requirements
        vm.prank(requirer);
        token.setRequirements(812349);

        uint256 _amount = 2 * 10 ** 18;

        // allow minter to mint
        vm.prank(mintAllower);
        token.increaseMintingAllowance(localMinter, _amount);

        // allow token holder to transfer
        console.log("before");
        vm.startPrank(transfererAdmin);
        token.grantRole(token.TRANSFERER_ROLE(), tokenHolder);
        vm.stopPrank();

        console.log("after: ", tokenHolder);

        // ensure fee collector does not meet requirements
        assertTrue(token.requirements() > 0, "fee collector might meet requirements");
        assertTrue(token.allowList().map(feeCollector) == 0, "fee collector might meet requirements");
        // ensure fee collector is not a transferer
        assertEq(token.hasRole(token.TRANSFERER_ROLE(), feeCollector), false, "fee collector is a transferer");

        uint feeCollectorBalanceBeforeMint = token.balanceOf(feeCollector);
        // mint tokens for token holder. Currently, this also mints tokens to the fee collector, already proving they can receive tokens.
        // But if the test fee is ever set to 0, the tests above might fail if the fee collector can't send or receive tokens for some reason.
        vm.startPrank(localMinter);
        token.mint(tokenHolder, _amount);
        vm.stopPrank();

        uint feeCollectorBalanceAfterMint = token.balanceOf(feeCollector);

        assertTrue(
            feeCollectorBalanceBeforeMint <= feeCollectorBalanceAfterMint,
            "fee collector has not received tokens"
        );
        assertEq(
            feeCollectorBalanceAfterMint - feeCollectorBalanceBeforeMint,
            token.feeSettings().tokenFee(_amount, address(token)),
            "fee collector has received wrong token amount"
        );
    }

    function testFeeCollectorCanNotAlwaysBuy() public {
        address localMinter = vm.addr(2);
        address feeCollector = feeSettings.feeCollector();

        console.log("Local minter: ", localMinter);
        console.log("Fee collector: ", feeSettings.feeCollector());
        console.log("transfererAdmin: ", transfererAdmin);
        console.log("mintAllower: ", mintAllower);
        console.log("this: ", address(this));

        // set requirements
        vm.prank(requirer);
        token.setRequirements(812349);

        uint256 _amount = 2 * 10 ** 18;

        // allow minter to mint
        vm.prank(mintAllower);
        token.increaseMintingAllowance(localMinter, _amount);

        // ensure fee collector does not meet requirements
        assertTrue(token.requirements() > 0, "fee collector might meet requirements");
        assertTrue(token.allowList().map(feeCollector) == 0, "fee collector might meet requirements");
        // ensure fee collector is not a transferer
        assertEq(token.hasRole(token.TRANSFERER_ROLE(), feeCollector), false, "fee collector is a transferer");

        // mint tokens for feeCollector
        vm.startPrank(localMinter);
        vm.expectRevert(
            "Sender or Receiver is not allowed to transact. Either locally issue the role as a TRANSFERER or they must meet requirements as defined in the allowList"
        );
        token.mint(feeCollector, _amount);
        vm.stopPrank();
    }

    function testFeeSettingsUpdateRevertsWhenContractFailsERC165Check() public {
        Fees memory fees = Fees(0, 1, 0, 1, 0, 1, 0);
        FeeSettings[] memory feeSettingsArray = new FeeSettings[](3);
        feeSettingsArray[0] = new FeeSettingsFailERC165Check0(fees, feeSettings.feeCollector());
        feeSettingsArray[1] = new FeeSettingsFailERC165Check1(fees, feeSettings.feeCollector());
        feeSettingsArray[2] = new FeeSettingsFailIFeeSettingsV2Check(fees, feeSettings.feeCollector());

        vm.startPrank(feeSettings.owner());
        // cycle through the fake contracts and make sure each one triggers a revert
        for (uint i = 0; i < feeSettingsArray.length; i++) {
            vm.expectRevert("FeeSettings must implement IFeeSettingsV2");
            token.suggestNewFeeSettings(feeSettingsArray[i]);
        }
        vm.stopPrank();
    }
}
