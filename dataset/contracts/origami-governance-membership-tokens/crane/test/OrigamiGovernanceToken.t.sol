// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {Test} from "@std/Test.sol";
import {OrigamiGovernanceToken} from "src/OrigamiGovernanceToken.sol";
import {OrigamiGovernanceTokenTestVersion} from "test/versions/OrigamiGovernanceTokenTestVersion.sol";
import {TransparentUpgradeableProxy} from "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@oz/proxy/transparent/ProxyAdmin.sol";
import {Strings} from "@oz/utils/Strings.sol";

abstract contract OGTAddressHelper {
    address public deployer = address(0x6);
    address public owner = address(0x1);
    address public minter = address(0x2);
    address public mintee = address(0x3);
    address public pauser = address(0x4);
    address public transferrer = address(0x5);
    address public signer = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
}

abstract contract OGTHelper is OGTAddressHelper, Test {
    OrigamiGovernanceToken public impl;
    ProxyAdmin public proxyAdmin;
    OrigamiGovernanceToken public token;

    constructor() {
        vm.startPrank(deployer);
        impl = new OrigamiGovernanceToken();
        proxyAdmin = new ProxyAdmin();
        token = deployNewToken(owner, "Deciduous Tree DAO Governance", "DTDG", 10000000000000000000000000000);
        vm.stopPrank();
    }

    function deployNewToken(address _owner, string memory _name, string memory _symbol, uint256 _cap)
        public
        returns (OrigamiGovernanceToken _token)
    {
        TransparentUpgradeableProxy proxy;
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            ""
        );
        _token = OrigamiGovernanceToken(address(proxy));
        _token.initialize(_owner, _name, _symbol, _cap);
    }
}

contract DeployGovernanceTokenTest is OGTAddressHelper, Test {
    OrigamiGovernanceToken public impl;
    TransparentUpgradeableProxy public proxy;
    OrigamiGovernanceToken public token;
    ProxyAdmin public admin;

    function setUp() public {
        admin = new ProxyAdmin();
        impl = new OrigamiGovernanceToken();
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(admin),
            ""
        );
    }

    function testDeploy() public {
        token = OrigamiGovernanceToken(address(proxy));
        token.initialize(owner, "Deciduous Tree DAO Governance", "DTDG", 10000000000000000000000000000);
        assertEq(token.name(), "Deciduous Tree DAO Governance");
        assertEq(token.symbol(), "DTDG");
        assertEq(token.totalSupply(), 0);
        assertEq(token.cap(), 10000000000000000000000000000);
    }

    function testDeployRevertsWhenAdminIsAdressZero() public {
        token = OrigamiGovernanceToken(address(proxy));
        vm.expectRevert("Admin address cannot be zero");
        token.initialize(address(0), "Deciduous Tree DAO Governance", "DTDG", 10000000000000000000000000000);
    }
}

contract UpgradeGovernanceTokenTest is Test, OGTAddressHelper {
    OrigamiGovernanceToken public implV1;
    OrigamiGovernanceTokenTestVersion public implV2;
    TransparentUpgradeableProxy public proxy;
    OrigamiGovernanceToken public tokenV1;
    OrigamiGovernanceTokenTestVersion public tokenV2;
    ProxyAdmin public admin;

    event TransferEnabled(address indexed caller, bool value);

    function setUp() public {
        admin = new ProxyAdmin();
        implV1 = new OrigamiGovernanceToken();
        proxy = new TransparentUpgradeableProxy(
            address(implV1),
            address(admin),
            ""
        );
        tokenV1 = OrigamiGovernanceToken(address(proxy));

        tokenV1.initialize(owner, "Deciduous Tree DAO Governance", "DTDG", 10000000000000000000000000000);
    }

    function testCanInitialize() public {
        assertEq(tokenV1.name(), "Deciduous Tree DAO Governance");
    }

    function testCannotInitializeTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        tokenV1.initialize(owner, "EVEN MOAR Deciduous Tree DAO Governance", "EMDTDG", 10000000000000000000000000000);
    }

    function testCanUpgrade() public {
        implV2 = new OrigamiGovernanceTokenTestVersion();
        admin.upgrade(proxy, address(implV2));
        tokenV2 = OrigamiGovernanceTokenTestVersion(address(proxy));
        vm.prank(owner);

        vm.expectEmit(true, true, true, true, address(tokenV2));

        // TransferEnabled does not exist in tokenV1, so it being emited here is proof that the upgrade worked
        emit TransferEnabled(owner, true);

        tokenV2.enableTransfer();
    }
}

contract GovernanceTokenVotingPowerTest is OGTHelper {
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.TRANSFERRER_ROLE(), transferrer);

        // mint some tokens as owner
        token.enableTransfer();
        token.mint(mintee, 100);
        vm.stopPrank();

        // warp to a new timestamp
        vm.warp(42);

        // delegate to self
        vm.prank(mintee);
        token.delegate(mintee);

        // warp to a new timestamp
        vm.warp(43);
    }

    function testDelegateEmitsDelegateChanged() public {
        address other = address(0x7);
        vm.prank(mintee);
        vm.expectEmit(true, true, true, true, address(token));
        emit DelegateChanged(mintee, mintee, other);
        token.delegate(other);
    }

    function testDelegateEmitsDelegateVotesChanged() public {
        address other = address(0x7);
        address mintee2 = address(0x8);

        vm.prank(other);
        token.delegate(other);

        vm.prank(mintee);
        vm.expectEmit(true, true, true, true, address(token));
        emit DelegateVotesChanged(other, 0, 100);
        token.delegate(other);

        // mint some more tokens to mintee
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(token));
        emit DelegateVotesChanged(other, 100, 200);
        token.mint(mintee, 100);

        // transfers from the delegator to the delegatee do not trigger a DelegateVotesChanged event, since the balance delegated would not change.
        // vm.prank(mintee);
        // vm.expectEmit(true, true, true, true, address(token));
        // emit DelegateVotesChanged(other, 200, 200);
        // token.transfer(other, 10);

        // mintee2 delegates to other
        vm.prank(mintee2);
        vm.expectEmit(true, true, true, true, address(token));
        emit DelegateChanged(mintee2, address(0), other);
        token.delegate(other);

        // mintee2 gets more tokens
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(token));
        emit DelegateVotesChanged(other, 200, 210);
        token.mint(mintee2, 10);
    }

    function testDelegateOfSameDelegateeReverts() public {
        address other = address(0x7);

        vm.startPrank(other);
        token.delegate(other);
        vm.expectRevert("Delegate: already delegated to this delegatee");
        token.delegate(other);
    }

    function testGetVotesIsZeroBeforeDelegation() public {
        address other = address(0x7);

        vm.prank(owner);
        token.mint(other, 100);

        // check that other has no votes
        assertEq(token.getVotes(other), 0);

        // delegate and then check again
        vm.prank(other);
        token.delegate(other);
        assertEq(token.getVotes(other), 100);

        // mint and check updated balance
        vm.prank(owner);
        token.mint(other, 100);
        assertEq(token.getVotes(other), 200);
    }

    function testGetPastVotesSnapshotsAtTimestamp() public {
        // mint some more tokens as owner
        vm.warp(43);
        vm.prank(owner);
        token.mint(mintee, 100);

        // visit the next block and make assertions
        vm.warp(44);
        assertEq(token.getPastVotes(mintee, 41), 0); // minting happened at timestamp 1 but delegation hasn't happened yet
        assertEq(token.getPastVotes(mintee, 42), 100); // delegation happened at timestamp 42
        assertEq(token.getPastVotes(mintee, 43), 200); // more minting happened at timestamp 43
    }

    function testGetPastTotalSupplySnapshotsAtTimestamp() public {
        // mint some more tokens as owner
        vm.warp(43);
        vm.prank(owner);
        token.mint(mintee, 100);

        // visit the next block and make assertions
        vm.warp(44);
        assertEq(token.getPastTotalSupply(41), 100); // total supply is calc'd regardless of delegation
        assertEq(token.getPastTotalSupply(42), 100); // delegation happened at timestamp 42
        assertEq(token.getPastTotalSupply(43), 200); // more minting happened at timestamp 43
    }

    function testDelegatesReturnsDelegateOf(address delegatee) public {
        vm.assume(delegatee != mintee);
        vm.assume(delegatee != address(0));
        vm.prank(mintee);
        token.delegate(delegatee);
        assertEq(token.delegates(mintee), delegatee);
    }

    function testTransferVotingPower() public {
        address other = address(0x7);

        // mint some more tokens as owner
        vm.warp(43);
        vm.prank(owner);
        token.mint(other, 100);

        // self-delegate
        vm.prank(other);
        token.delegate(other);

        assertEq(token.getVotes(mintee), 100);
        assertEq(token.getVotes(other), 100);

        // transfer 10 tokens to mintee
        vm.prank(other);
        token.transfer(mintee, 10);

        // check that mintee has 110 votes
        assertEq(token.getVotes(mintee), 110);

        // check that other has 90 votes
        assertEq(token.getVotes(other), 90);
    }

    function testTransferWhenDelegationExists() public {
        address other = address(0x7);

        // mint some more tokens as owner
        vm.warp(43);
        vm.prank(owner);
        token.mint(other, 100);

        // mintee is self delegated already from setup
        // other should have balance of 100
        assertEq(token.balanceOf(other), 100);

        // delegate to mintee from other
        vm.startPrank(other);
        token.delegate(mintee);
        assertEq(token.getVotes(mintee), 200);
        assertEq(token.getVotes(other), 0);

        assertEq(token.balanceOf(other), 100);

        // transfer 10 tokens to mintee
        token.transfer(mintee, 10);

        // check that mintee has 110 votes
        assertEq(token.balanceOf(mintee), 110);
        // should still be 200 because it is self delegated
        assertEq(token.getVotes(mintee), 200);

        // check that other has 90 as balance and 0 voting power
        assertEq(token.balanceOf(other), 90);
        assertEq(token.getVotes(other), 0);
        vm.stopPrank();
    }

    function testBurnAndMintPastSupplyAndPastVotesInteractions() public {
        vm.prank(owner);
        token.enableBurn();

        // mint some more tokens as owner
        vm.warp(43);
        vm.prank(owner);
        token.mint(mintee, 100);

        // burn some tokens
        vm.warp(44);
        vm.prank(mintee);
        token.burn(10);

        // check that mintee has 90 votes
        assertEq(token.getVotes(mintee), 190);

        // check that total supply is 190
        assertEq(token.totalSupply(), 190);

        // check that mintee has 100 votes at timestamp 42
        assertEq(token.getPastVotes(mintee, 42), 100);

        // check that total supply is 100 at timestamp 42
        assertEq(token.getPastTotalSupply(42), 100);

        // check that mintee has 200 votes at timestamp 43
        assertEq(token.getPastVotes(mintee, 43), 200);

        // check that total supply is 200 at timestamp 43
        assertEq(token.getPastTotalSupply(43), 200);

        // check that mintee has 190 votes at timestamp 44
        assertEq(token.getPastVotes(mintee, 44), 190);

        // check that total supply is 190 at timestamp 44
        assertEq(token.getPastTotalSupply(44), 190);
    }

    function testDelegateBySig() public {
        bytes32 r = 0x269626c92cabf71b49d866b0e09f35882d08a260bdb59a67fae51a1ceabc7757;
        bytes32 s = 0x0935d9b1ba980a1df5943b4cf597d72e1f6256cdaabe310251e55d5bbfdf51d6;
        uint8 v = 27;

        // delegate to self
        vm.expectEmit(true, true, true, true, address(token));
        emit DelegateChanged(signer, address(0), mintee);
        token.delegateBySig(mintee, 0, 242, v, r, s);
    }
}

contract GovernanceTokenTransferLockTest is OGTHelper {
    function setUp() public {
        vm.startPrank(owner);
        token.enableTransfer();
        token.mint(mintee, 100);
        vm.stopPrank();
    }

    function testEmptyTransferLock() public {
        uint256 amount = token.getTransferLockTotal(mintee);
        assertEq(amount, 0);
    }

    function testAddTransferLock() public {
        assertEq(block.timestamp, 1);
        vm.prank(mintee);
        token.addTransferLock(100, 1000);
        uint256 amount = token.getTransferLockTotal(mintee);
        assertEq(amount, 100);
    }

    function testCannotAddTransferLockOfZero() public {
        vm.prank(mintee);
        vm.expectRevert("TransferLock: amount must be greater than zero");
        token.addTransferLock(0, 1000);
    }

    function testCannotAddTransferLockAmountHigherThanBalance() public {
        vm.prank(mintee);
        vm.expectRevert("TransferLock: amount cannot exceed available balance");
        token.addTransferLock(101, 1000);
    }

    function testCannotTransferWhileLocked() public {
        vm.warp(1673049600); // 2023-01-01
        vm.prank(mintee);
        token.addTransferLock(100, 1704585600); // 2024-01-01
        vm.prank(mintee);
        vm.expectRevert("TransferLock: this exceeds your unlocked balance");
        token.transfer(minter, 10);
    }
}
