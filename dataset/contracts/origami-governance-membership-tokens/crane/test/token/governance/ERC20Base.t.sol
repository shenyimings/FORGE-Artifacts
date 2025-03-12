// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {Test} from "@std/Test.sol";
import {ERC20Base} from "src/token/governance/ERC20Base.sol";
import {TransparentUpgradeableProxy} from "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@oz/proxy/transparent/ProxyAdmin.sol";
import {Strings} from "@oz/utils/Strings.sol";

abstract contract ERC20AddressHelper {
    address public deployer = address(0x6);
    address public owner = address(0x1);
    address public minter = address(0x2);
    address public mintee = address(0x3);
    address public pauser = address(0x4);
    address public transferrer = address(0x5);
    address public signer = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
}

contract ERC20BaseInitializationTest is ERC20AddressHelper, Test {
    ERC20Base public impl;
    ProxyAdmin public proxyAdmin;
    ERC20Base public token;

    function testInitializing() public {
        vm.startPrank(deployer);
        impl = new ERC20Base();
        proxyAdmin = new ProxyAdmin();

        TransparentUpgradeableProxy proxy;
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            ""
        );
        token = ERC20Base(address(proxy));
        vm.expectRevert("ERC20Base: Token name cannot be empty");
        token.initialize(owner, "", "sym", 10000000000000000000000000000);

        vm.expectRevert("ERC20Base: Token symbol cannot be empty");
        token.initialize(owner, "name", "", 10000000000000000000000000000);

        vm.expectRevert("ERC20Capped: cap is 0");
        token.initialize(owner, "thing", "THI", 0);
    }
}

abstract contract ERC20BaseHelper is ERC20AddressHelper, Test {
    ERC20Base public impl;
    ProxyAdmin public proxyAdmin;
    ERC20Base public token;

    constructor() {
        vm.startPrank(deployer);
        impl = new ERC20Base();
        proxyAdmin = new ProxyAdmin();
        token = deployNewToken(owner, "Deciduous Tree DAO Governance", "DTDG", 10000000000000000000000000000);
        vm.stopPrank();
    }

    function deployNewToken(address _owner, string memory _name, string memory _symbol, uint256 _cap)
        public
        returns (ERC20Base _token)
    {
        TransparentUpgradeableProxy proxy;
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            ""
        );
        _token = ERC20Base(address(proxy));
        _token.initialize(_owner, _name, _symbol, _cap);
    }
}

contract MintingGovernanceTokenTest is ERC20BaseHelper {
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.startPrank(minter);
    }

    function testMinting(uint96 amount) public {
        vm.assume(amount < token.cap());
        token.mint(mintee, amount);
        assertEq(token.balanceOf(mintee), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testMintingRevertsWhenNotMinter() public {
        vm.stopPrank();
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(address(this)),
                " is missing role 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6"
            )
        );
        token.mint(mintee, 100);
    }

    function testMintingRevertsWhenPaused() public {
        vm.stopPrank();
        vm.prank(owner);
        token.pause();
        vm.prank(minter);
        vm.expectRevert("Pausable: paused");
        token.mint(mintee, 100);
    }

    function testMintingRevertsWhenMintingMoreThanCap() public {
        vm.expectRevert("ERC20Capped: cap exceeded");
        token.mint(mintee, 10000000000000000000000000001);
    }

    function testMintingRevertsWhenMintingMoreThanCapAfterMinting() public {
        token.mint(mintee, 10000000000000000000000000000);
        vm.expectRevert("ERC20Capped: cap exceeded");
        token.mint(mintee, 1);
    }

    function testMintingRevertsWhenMintingToZeroAddress() public {
        vm.expectRevert("ERC20: mint to the zero address");
        token.mint(address(0), 100);
    }

    function testEmitsAnEventWhenMinting() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), mintee, 100);
        token.mint(mintee, 100);
    }
}

contract CappedGovernanceTokenTest is ERC20BaseHelper {
    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.startPrank(minter);
    }

    function testCanMintUpToCappedSupply() public {
        token.mint(mintee, 10000000000000000000000000000);
        assertEq(token.balanceOf(mintee), 10000000000000000000000000000);
    }

    function testCannotMintMoreThanCappedSupply() public {
        vm.expectRevert("ERC20Capped: cap exceeded");
        token.mint(mintee, 10000000000000000000000000001);
    }
}

contract BurnGovernanceTokenTest is ERC20BaseHelper {
    event BurnEnabled(address indexed caller, bool value);

    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.MINTER_ROLE(), minter);
    }

    function testCanEnableBurnAsAdmin() public {
        token.enableBurn();
        assertTrue(token.burnable());
    }

    function testCanDisableBurnAsAdmin() public {
        token.enableBurn();
        token.disableBurn();
        assertFalse(token.burnable());
    }

    function testRevertsWhenNonAdminAttemptsToEnableBurn(address nonAdmin) public {
        vm.assume(nonAdmin != owner);
        vm.assume(nonAdmin != address(proxyAdmin));
        vm.stopPrank();
        vm.startPrank(nonAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonAdmin),
                " is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.enableBurn();
    }

    function testRevertsWhenNonAdminAttemptsToDisableBurn(address nonAdmin) public {
        vm.assume(nonAdmin != owner);
        vm.assume(nonAdmin != address(proxyAdmin));
        vm.stopPrank();
        vm.startPrank(nonAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonAdmin),
                " is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.disableBurn();
    }

    function testRevertsWhenCallingEnableBurnAndBurnIsAlreadyEnabled() public {
        token.enableBurn();
        vm.expectRevert("Burnable: burning is enabled");
        token.enableBurn();
    }

    function testRevertsWhenCallingDisableBurnAndBurnIsAlreadyDisabled() public {
        vm.expectRevert("Burnable: burning is disabled");
        token.disableBurn();
    }

    function testEmitsBurnEnabledWhenEnabled() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit BurnEnabled(owner, true);
        token.enableBurn();
    }

    function testEmitsBurnEnabledWhenDisabled() public {
        token.enableBurn();
        vm.expectEmit(true, true, true, true, address(token));
        emit BurnEnabled(owner, false);
        token.disableBurn();
    }

    function testCannotBurnAsNonHolder() public {
        token.enableBurn();
        vm.stopPrank();
        vm.startPrank(minter);
        token.mint(mintee, 100);
        vm.expectRevert("ERC20: insufficient allowance");
        token.burnFrom(mintee, 10);
    }

    function testCannotBurnAsHolderWhenBurnIsDisabled() public {
        vm.stopPrank();
        vm.prank(minter);
        token.mint(mintee, 100);
        assertEq(token.balanceOf(mintee), 100);
        vm.prank(mintee);
        vm.expectRevert("Burnable: burning is disabled");
        token.burn(100);
    }

    function testCanBurnAsHolderWhenBurnIsEnabled(uint96 amount) public {
        vm.assume(amount < token.cap());
        token.enableBurn();
        vm.stopPrank();
        vm.prank(minter);
        token.mint(mintee, amount);
        vm.prank(mintee);
        token.burn(amount);
        assertEq(token.balanceOf(mintee), 0);
    }

    function testCanBurnFromWalletWithAllowanceWhenEnabled(uint96 amount) public {
        vm.assume(amount < token.cap());
        token.enableBurn();
        vm.stopPrank();
        vm.prank(minter);
        token.mint(mintee, amount);
        vm.prank(mintee);
        token.approve(minter, amount);
        vm.prank(minter);
        token.burnFrom(mintee, amount);
        assertEq(token.balanceOf(mintee), 0);
    }

    function testCannotBurnMoreThanAllowanceWhenEnabled() public {
        token.enableBurn();
        vm.stopPrank();
        vm.prank(minter);
        token.mint(mintee, 100);
        vm.prank(mintee);
        token.approve(minter, 10);
        vm.expectRevert("ERC20: insufficient allowance");
        vm.prank(minter);
        token.burnFrom(mintee, 11);
    }
}

contract PauseGovernanceTokenTest is ERC20BaseHelper {
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.PAUSER_ROLE(), pauser);
    }

    function testCanPauseAsPauser() public {
        vm.stopPrank();
        vm.prank(pauser);
        vm.expectEmit(true, true, true, true, address(token));
        emit Paused(pauser);
        token.pause();
        assertTrue(token.paused());
    }

    function testCannotPauseAsNonPauser(address nonPauser) public {
        vm.assume(nonPauser != owner);
        vm.assume(nonPauser != pauser);
        vm.assume(nonPauser != address(proxyAdmin));

        vm.stopPrank();
        vm.prank(nonPauser);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonPauser),
                " is missing role 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a"
            )
        );
        token.pause();
    }

    function testCanUnpauseAsPauser() public {
        vm.stopPrank();
        vm.prank(pauser);
        token.pause();
        vm.prank(pauser);
        vm.expectEmit(true, true, true, true, address(token));
        emit Unpaused(pauser);
        token.unpause();
        assertFalse(token.paused());
    }

    function testCannotUnpauseAsNonPauser(address nonPauser) public {
        vm.assume(nonPauser != owner);
        vm.assume(nonPauser != pauser);
        vm.assume(nonPauser != address(proxyAdmin));

        token.pause();
        vm.stopPrank();
        vm.prank(nonPauser);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonPauser),
                " is missing role 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a"
            )
        );
        token.unpause();
    }

    function testCanMintWhenUnpaused(uint96 amount) public {
        vm.assume(amount < token.cap());
        assertFalse(token.paused());
        token.mint(mintee, amount);
        assertEq(token.balanceOf(mintee), amount);
    }

    function testCannotMintWhenPaused() public {
        token.pause();
        vm.expectRevert("Pausable: paused");
        token.mint(mintee, 100);
    }

    function testCanBurnWhenUnpausedAndBurnable(uint96 amount) public {
        vm.assume(amount < token.cap());
        assertFalse(token.paused());
        token.mint(mintee, amount);
        token.enableBurn();
        vm.stopPrank();
        vm.prank(mintee);
        token.burn(amount);
        assertEq(token.balanceOf(mintee), 0);
    }

    function testCannotBurnWhenPaused() public {
        token.mint(mintee, 100);
        token.pause();
        token.enableBurn();
        vm.stopPrank();
        vm.expectRevert("Pausable: paused");
        vm.prank(mintee);
        token.burn(100);
    }

    function testCanTransferWhenUnpausedAndTransferrable(uint96 amount) public {
        vm.assume(amount < token.cap());
        assertFalse(token.paused());
        token.mint(mintee, amount);
        token.enableTransfer();
        vm.stopPrank();
        vm.prank(mintee);
        token.transfer(minter, amount);
        assertEq(token.balanceOf(minter), amount);
    }

    function testCannotTransferWhenPausedAndTransferEnabled(uint96 amount) public {
        vm.assume(amount < token.cap());
        token.mint(mintee, amount);
        token.enableTransfer();
        token.pause();
        vm.stopPrank();
        vm.expectRevert("Pausable: paused");
        vm.prank(mintee);
        token.transfer(minter, amount);
    }

    function testTransferrerRoleCannotTransferWhenPaused() public {
        token.grantRole(token.TRANSFERRER_ROLE(), mintee);
        token.mint(mintee, 100);
        token.pause();
        vm.stopPrank();
        vm.expectRevert("Pausable: paused");
        vm.prank(mintee);
        token.transfer(minter, 100);
    }

    function testBurnerRoleCannotBurnWhenPaused() public {
        token.grantRole(token.BURNER_ROLE(), mintee);
        token.mint(mintee, 100);
        token.pause();
        vm.stopPrank();
        vm.expectRevert("Pausable: paused");
        vm.prank(mintee);
        token.burn(100);
    }
}

contract TransferGovernanceTokenTest is ERC20BaseHelper {
    event TransferEnabled(address indexed caller, bool value);

    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.TRANSFERRER_ROLE(), transferrer);
    }

    function testEmitsTransferEnabledEventWhenEnabled() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferEnabled(owner, true);
        token.enableTransfer();
    }

    function testEmitsTransferEnabledEventWhenDisabled() public {
        token.enableTransfer();
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferEnabled(owner, false);
        token.disableTransfer();
    }

    function testCanOnlyEnableTransferAsAdmin(address nonAdmin) public {
        vm.assume(nonAdmin != owner);
        vm.assume(nonAdmin != address(proxyAdmin));
        vm.stopPrank();
        vm.prank(nonAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonAdmin),
                " is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.enableTransfer();
        vm.prank(owner);
        token.enableTransfer();
        assertTrue(token.transferrable());
    }

    function testCanOnlyDisableTransferAsAdmin(address nonAdmin) public {
        vm.assume(nonAdmin != owner);
        vm.assume(nonAdmin != address(proxyAdmin));
        token.enableTransfer();
        vm.stopPrank();
        vm.prank(nonAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonAdmin),
                " is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.disableTransfer();
        vm.prank(owner);
        token.disableTransfer();
        assertFalse(token.transferrable());
    }

    function testCannotEnableTransferWhenAlreadyEnabled() public {
        token.enableTransfer();
        vm.expectRevert("Transferrable: transfers are enabled");
        token.enableTransfer();
    }

    function testCannotDisableTransferWhenAlreadyDisabled() public {
        vm.expectRevert("Transferrable: transfers are disabled");
        token.disableTransfer();
    }

    function testCanMintWhenTransferIsDisabled() public {
        assertFalse(token.transferrable());
        token.mint(mintee, 100);
        assertEq(token.balanceOf(mintee), 100);
    }

    function testCannotTransferWhenTransferDisabled() public {
        token.enableBurn();
        assertFalse(token.transferrable());
        token.mint(mintee, 100);
        vm.stopPrank();
        vm.startPrank(mintee);
        vm.expectRevert("Transferrable: transfers are disabled");
        token.transfer(minter, 10);
        vm.expectRevert("Transferrable: transfers are disabled");
        token.transferFrom(mintee, minter, 10);
    }

    function testCanTransferWhenTransfersAreEnabled() public {
        token.enableTransfer();
        token.mint(mintee, 100);
        vm.stopPrank();
        vm.prank(mintee);
        token.transfer(minter, 10);
        assertEq(token.balanceOf(minter), 10);
        vm.prank(minter);
        token.transfer(mintee, 1);
        assertEq(token.balanceOf(minter), 9);
        assertEq(token.balanceOf(mintee), 91);
        vm.prank(mintee);
        token.approve(minter, 10);
        vm.prank(minter);
        token.transferFrom(mintee, minter, 10);
        assertEq(token.balanceOf(minter), 19);
        assertEq(token.balanceOf(mintee), 81);
    }

    function testCanTransferAsTransferrerWhenTransfersAreDisabled() public {
        assertFalse(token.transferrable());
        token.mint(transferrer, 100);
        vm.stopPrank();
        vm.prank(transferrer);
        token.transfer(mintee, 10);
        assertEq(token.balanceOf(mintee), 10);
    }

    function testCanTransferAsTransferrerWhenTransfersAreEnabled() public {
        token.enableTransfer();
        token.mint(transferrer, 100);
        vm.stopPrank();
        vm.prank(transferrer);
        token.transfer(mintee, 10);
        assertEq(token.balanceOf(mintee), 10);
    }
}

// This contract is stripped down as much as possible and intended to be used
// for snapshotting estimated gas costs for functions used by holders. Each test
// comes in a fuzzed and non-fuzzed version, providing multiple runs on a
// variety of inputs versus a baseline.  This is not an accurate measurement of
// gas costs, but can be a good way to ballpark gas consumption or to compare it
// with snapshots to see how changes might impact gas costs.
contract HolderFunctionGasEstimateTests is ERC20BaseHelper {
    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.PAUSER_ROLE(), pauser);
        token.mint(mintee, 100_000_000);
        token.enableTransfer();
        token.enableBurn();
        vm.stopPrank();
    }

    function testTransferGasCostFuzzed(uint96 amount) public {
        vm.assume(amount < 100_000_000);
        vm.prank(mintee);
        token.transfer(minter, amount);
    }

    function testTransferGasCost() public {
        vm.prank(mintee);
        token.transfer(minter, 10);
    }

    function testApproveAndTransferFromGasCostFuzzed(uint96 amount) public {
        vm.assume(amount < 100_000_000);
        vm.prank(mintee);
        token.approve(minter, amount);
        vm.prank(minter);
        token.transferFrom(mintee, minter, amount);
    }

    function testApproveAndTransferFromGasCost() public {
        vm.prank(mintee);
        token.approve(minter, 10);
        vm.prank(minter);
        token.transferFrom(mintee, minter, 10);
    }

    function testBurnGasCostFuzzed(uint96 amount) public {
        vm.assume(amount < 100_000_000);
        vm.prank(mintee);
        token.burn(amount);
    }

    function testBurnGasCost() public {
        vm.prank(mintee);
        token.burn(10);
    }

    function testApproveGasCostFuzzed(uint96 amount) public {
        vm.assume(amount < 100_000_000);
        vm.prank(mintee);
        token.approve(minter, amount);
    }

    function testApproveGasCost() public {
        vm.prank(mintee);
        token.approve(minter, 10);
    }

    function testIncreaseAllowanceGasCostFuzzed(uint96 amount) public {
        vm.assume(amount < 100_000_000);
        vm.prank(mintee);
        token.increaseAllowance(minter, amount);
    }

    function testIncreaseAllowanceGasCost() public {
        vm.prank(mintee);
        token.increaseAllowance(minter, 10);
    }

    function testDecreaseAllowanceGasCostFuzzed(uint96 amount) public {
        vm.assume(amount < 100_000_000);
        vm.startPrank(mintee);
        token.approve(minter, amount);
        token.decreaseAllowance(minter, amount / 2);
    }

    function testDecreaseAllowanceGasCost() public {
        vm.startPrank(mintee);
        token.approve(minter, 15);
        token.decreaseAllowance(minter, 10);
    }
}
