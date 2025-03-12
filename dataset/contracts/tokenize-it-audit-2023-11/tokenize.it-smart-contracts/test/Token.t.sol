// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "./resources/CloneCreators.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract tokenTest is Test {
    event RequirementsChanged(uint newRequirements);
    event MintingAllowanceChanged(address indexed minter, uint256 newAllowance);

    Token token;
    Token implementation = new Token(trustedForwarder);
    TokenProxyFactory tokenCloneFactory = new TokenProxyFactory(address(implementation));

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

    function setUp() public {
        allowList = createAllowList(trustedForwarder, admin);
        vm.prank(feeSettingsOwner);
        Fees memory fees = Fees(1, 100, 1, 100, 1, 100, 0);
        feeSettings = createFeeSettings(trustedForwarder, address(this), fees, admin, admin, admin);
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

    function testSetUp() public {
        assertTrue(token.hasRole(token.getRoleAdmin(token.REQUIREMENT_ROLE()), admin));
        assertTrue(token.allowList() == allowList);
        assertTrue(keccak256(bytes(token.name())) == keccak256(bytes("testToken")));
        assertTrue(keccak256(bytes(token.symbol())) == keccak256(bytes("TEST")));
    }

    function testLogicContractCreation() public {
        Token _logic = new Token(address(1));

        console.log("address of logic contract: ", address(_logic));

        // try to initialize
        vm.expectRevert("Initializable: contract is already initialized");
        _logic.initialize(IFeeSettingsV2(address(2)), address(3), AllowList(address(4)), 3, "testToken", "TEST");

        // all settings are 0
        assertTrue(address(_logic.feeSettings()) == address(0));
        assertTrue(address(_logic.allowList()) == address(0));
        assertTrue(_logic.requirements() == 0);
        assertTrue(keccak256(abi.encodePacked(_logic.name())) == keccak256(bytes("")));
        assertTrue(keccak256(abi.encodePacked(_logic.symbol())) == keccak256(bytes("")));

        // we are not the admin
        assertFalse(_logic.hasRole(_logic.DEFAULT_ADMIN_ROLE(), address(this)));
    }

    function testAllowList0() public {
        AllowList _noList = AllowList(address(0));
        vm.expectRevert("AllowList must not be zero address");
        tokenCloneFactory.createTokenProxy(0, trustedForwarder, feeSettings, admin, _noList, 0x0, "testToken", "TEST");
    }

    function testFeeSettings0() public {
        FeeSettings _noFeeSettings = FeeSettings(address(0));
        console.log("fee settings address:", address(_noFeeSettings));
        vm.expectRevert();
        tokenCloneFactory.createTokenProxy(
            0,
            trustedForwarder,
            _noFeeSettings,
            admin,
            allowList,
            0x0,
            "testToken",
            "TEST"
        );
    }

    function testFeeSettingsNoERC165() public {
        vm.expectRevert();
        tokenCloneFactory.createTokenProxy(
            0,
            trustedForwarder,
            FeeSettings(address(allowList)),
            admin,
            allowList,
            0x0,
            "testToken",
            "TEST"
        );
    }

    function testFailAdmin() public {
        assertTrue(token.hasRole(token.MINTALLOWER_ROLE(), address(this)));
    }

    function testFailAdmin2() public {
        assertTrue(token.hasRole(token.MINTALLOWER_ROLE(), msg.sender));
    }

    /**
    @notice test that addresses that are not the admin cannot perform the mint allower tasks
     */
    function testIsNotAdmin(address x) public {
        // test would fail (to fail) if x = admin. This has actually happened! Abort test in that case.
        vm.assume(x != admin);
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), x));
    }

    function testAdmin() public {
        assertTrue(token.hasRole(token.getRoleAdmin(token.REQUIREMENT_ROLE()), admin));
    }

    function testMinterAdmin() public {
        assertTrue(token.hasRole(token.MINTALLOWER_ROLE(), mintAllower));
    }

    function testMintAllower(address x) public {
        vm.assume(x != mintAllower);
        assertFalse(token.hasRole(token.MINTALLOWER_ROLE(), x));
    }

    function testFailSetRequirements() public {
        token.setRequirements(3);
    }

    function testDecimals() public {
        assertTrue(token.decimals() == 18);
    }

    function testFailSetRequirementsAdmin() public {
        // admin has not the Requirements role, only the right to grant this role
        vm.prank(admin);
        token.setRequirements(3);
    }

    function testFailSetRequirementsX(address X) public {
        // x is missing the Requirements role
        vm.assume(X != requirer);
        vm.prank(X);
        token.setRequirements(3);
    }

    function testSetRoleRequirements() public {
        bytes32 role = token.REQUIREMENT_ROLE();
        vm.prank(admin);
        token.grantRole(role, requirer);
        assertTrue(token.hasRole(role, requirer));
    }

    function testSetRoleMintallower() public {
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        assertTrue(token.hasRole(roleMintAllower, mintAllower));
    }

    function testSetRoleBurner() public {
        bytes32 role = token.BURNER_ROLE();
        vm.prank(admin);
        token.grantRole(role, burner);
        assertTrue(token.hasRole(role, burner));
    }

    function testSetRoleTransferer() public {
        bytes32 roleTransfererAdmin = token.TRANSFERERADMIN_ROLE();
        bytes32 roleTransferer = token.TRANSFERER_ROLE();

        vm.prank(admin);
        token.grantRole(roleTransfererAdmin, transfererAdmin);
        vm.prank(transfererAdmin);
        token.grantRole(roleTransferer, transferer);
        assertTrue(token.hasRole(roleTransferer, transferer));
    }

    function testSetRolePauser() public {
        bytes32 role = token.PAUSER_ROLE();
        vm.prank(admin);
        token.grantRole(role, pauser);
        assertTrue(token.hasRole(role, pauser));
    }

    function testSetRoleDefaultAdmin() public {
        bytes32 role = token.DEFAULT_ADMIN_ROLE();
        vm.prank(admin);
        token.grantRole(role, pauser);
        assertTrue(token.hasRole(role, pauser));
    }

    function testSetRequirements(uint256 newRequirements) public {
        bytes32 role = token.REQUIREMENT_ROLE();
        vm.prank(admin);
        token.grantRole(role, requirer);
        vm.prank(requirer);
        vm.expectEmit(true, true, true, true, address(token));
        emit RequirementsChanged(newRequirements);
        token.setRequirements(newRequirements);
        assertTrue(token.requirements() == newRequirements);
    }

    function testFailSetRequirementsWrongRole() public {
        vm.prank(pauser);
        token.setRequirements(3);
        assertTrue(token.requirements() == 3);
    }

    function testSetUpMinter(uint256 newAllowance, uint256 mintAmount) public {
        vm.assume(newAllowance < type(uint256).max / 2); // avoid overflow because of fees
        vm.assume(mintAmount <= newAllowance);
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.expectEmit(true, true, true, true, address(token));
        emit MintingAllowanceChanged(minter, newAllowance);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, newAllowance);
        assertTrue(token.mintingAllowance(minter) == newAllowance, "minting allowance should be newAllowance");

        vm.prank(minter);
        token.mint(pauser, mintAmount);
        assertTrue(token.balanceOf(pauser) == mintAmount, "balance of pauser should be mintAmount");
        assertTrue(
            token.mintingAllowance(minter) == newAllowance - mintAmount,
            "minting allowance should be newAllowance - mintAmount"
        );

        // set allowance to 0
        vm.prank(mintAllower);
        token.decreaseMintingAllowance(minter, UINT256_MAX);
        assertTrue(token.mintingAllowance(minter) == 0);
    }

    function testMintOnce(uint256 x) public {
        vm.assume(x <= UINT256_MAX - x / FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator()); // avoid overflow
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, x);
        assertTrue(token.mintingAllowance(minter) == x);

        vm.prank(minter);
        token.mint(pauser, x);
        assertTrue(token.balanceOf(pauser) == x);
        assertTrue(token.mintingAllowance(minter) == 0);
    }

    function testMint0() public {
        uint x = 0;
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, x);
        assertTrue(token.mintingAllowance(minter) == x);

        vm.prank(minter);
        token.mint(pauser, x);
        assertTrue(token.balanceOf(pauser) == x);
        assertTrue(token.mintingAllowance(minter) == 0);
    }

    function testMintAllowerDoesNotNeedAllowance(uint256 x) public {
        vm.assume(x <= UINT256_MAX - x / FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator()); // avoid overflow
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        assertTrue(token.mintingAllowance(mintAllower) == 0);

        vm.prank(mintAllower);
        token.mint(pauser, x);
        assertTrue(token.balanceOf(pauser) == x);
        assertTrue(token.mintingAllowance(minter) == 0);
    }

    function testMintWith0Fee() public {
        uint256 x = 1; // fee is 1%, so fee will be 0

        vm.prank(mintAllower);
        token.mint(pauser, x);
        assertTrue(token.balanceOf(pauser) == x);
        assertTrue(token.totalSupply() == x);
    }

    function testIncreaseAllowance(uint256 x, uint256 y) public {
        vm.assume(
            x < UINT256_MAX - y &&
                x + y <= UINT256_MAX - (x + y) / FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator()
        ); // avoid overflow

        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);

        vm.startPrank(mintAllower);
        token.increaseMintingAllowance(minter, x);
        assertTrue(token.mintingAllowance(minter) == x);

        token.increaseMintingAllowance(minter, y);
        assertTrue(token.mintingAllowance(minter) == x + y);
        vm.stopPrank();

        vm.prank(minter);
        token.mint(pauser, y);
        assertTrue(token.balanceOf(pauser) == y);
        assertTrue(token.mintingAllowance(minter) == x);

        vm.prank(minter);
        token.mint(pauser, x);
        assertTrue(token.balanceOf(pauser) == x + y);
        assertTrue(token.mintingAllowance(minter) == 0);
    }

    function testDecreaseAllowance(uint256 x, uint256 y) public {
        vm.assume(x > y);

        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);

        vm.expectEmit(true, true, true, true, address(token));
        emit MintingAllowanceChanged(minter, x);
        vm.startPrank(mintAllower);
        token.increaseMintingAllowance(minter, x);
        assertTrue(token.mintingAllowance(minter) == x);

        vm.expectEmit(true, true, true, true, address(token));
        emit MintingAllowanceChanged(minter, x - y);
        token.decreaseMintingAllowance(minter, y);
        assertTrue(token.mintingAllowance(minter) == x - y);

        // decrease works with more than the current allowance and results in 0
        token.decreaseMintingAllowance(minter, x);
        vm.stopPrank();

        assertTrue(token.mintingAllowance(minter) == 0);
    }

    function testFailMintAllowanceUsed(uint256 x) public {
        vm.prank(admin);
        token.increaseMintingAllowance(minter, x);
        assertTrue(token.mintingAllowance(minter) == x);

        vm.prank(minter);
        token.mint(pauser, x);
        assertTrue(token.balanceOf(pauser) == x);
        assertTrue(token.mintingAllowance(minter) == 0);

        vm.prank(minter);
        token.mint(pauser, 1);
    }

    /**
    @notice test if the minter can mint exactly the amount of tokens that is allowed, but in multiple steps
    */
    function testMintAgain(uint256 totalMintAmount, uint256 steps) public {
        vm.assume(
            totalMintAmount <=
                UINT256_MAX - totalMintAmount / FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator()
        ); // avoid overflow
        //vm.assume(steps < 200);

        steps = steps % 100; // don't be ridiculous

        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, totalMintAmount);
        assertTrue(token.mintingAllowance(minter) == totalMintAmount);

        // mint in steps
        uint256 minted = 0;
        for (uint256 i = 0; i < steps; i++) {
            uint256 mintAmount = totalMintAmount / steps;
            vm.prank(minter);
            token.mint(pauser, mintAmount);
            minted += mintAmount;
            assertTrue(token.balanceOf(pauser) == minted);
            assertTrue(token.mintingAllowance(minter) == totalMintAmount - minted);
        }

        // mint the rest
        if (totalMintAmount - minted > 0) {
            vm.prank(minter);
            token.mint(pauser, totalMintAmount - minted);
            assertTrue(token.balanceOf(pauser) == totalMintAmount);
            assertTrue(token.mintingAllowance(minter) == 0);
        }
    }

    function testFailZeroAllowanceMint(uint256 x) public {
        vm.assume(x > 0);

        vm.prank(admin);
        token.decreaseMintingAllowance(minter, token.mintingAllowance(minter)); // set allowance to 0
        assertTrue(token.mintingAllowance(minter) == 0); // check allowance is 0

        vm.prank(minter);
        token.mint(pauser, x); // try to mint -> must fail!
    }

    function testBurnSimple(uint256 x) public {
        vm.assume(x <= UINT256_MAX - x / FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator()); // avoid overflow
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();
        bytes32 role = token.BURNER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, x);
        assertTrue(token.mintingAllowance(minter) == x);

        console.log("minting %s tokens", x);
        console.log("fee demoninator: %s", FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator());
        console.log("amount: %s", x);

        console.log("remainder: %s", x % FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator());
        console.log(
            "amount without remainder: %s",
            x - (x % FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator())
        );

        console.log(
            "total tokens to mint (amount + fee): %s",
            x + x / FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator()
        );

        uint fee = x / FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator();
        console.log("fee: %s", fee);
        vm.prank(minter);
        token.mint(pauser, x);
        console.log("failed minting");
        assertTrue(token.balanceOf(pauser) == x, "pauser balance is wrong before burn");
        vm.prank(admin);
        token.grantRole(role, burner);
        vm.prank(burner);
        token.burn(pauser, x);
        assertTrue(token.balanceOf(pauser) == 0, "pauser balance is wrong");
    }

    /*
    Burn with requirements
     */
    function testBurnWithRequirements(uint256 x) public {
        vm.assume(x <= UINT256_MAX - x / FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator()); // avoid overflow
        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, x);
        assertTrue(token.mintingAllowance(minter) == x);

        vm.prank(minter);
        token.mint(pauser, x);
        assertTrue(token.balanceOf(pauser) == x);

        // set requirements
        vm.prank(requirer);
        token.setRequirements(3);

        vm.prank(burner);
        token.burn(pauser, x);
        assertTrue(token.balanceOf(pauser) == 0);
    }

    function testBurn0() public {
        vm.prank(mintAllower);
        token.decreaseMintingAllowance(minter, UINT256_MAX);
        assertTrue(token.mintingAllowance(minter) == 0);

        vm.prank(minter);
        token.mint(pauser, 0);
        assertTrue(token.balanceOf(pauser) == 0);

        vm.prank(burner);
        token.burn(pauser, 0);
        assertTrue(token.balanceOf(pauser) == 0);
    }

    function testTransferTo0(address _address) public {
        vm.assume(token.balanceOf(_address) == 0);
        vm.assume(_address != address(0));
        vm.assume(_address != FeeSettings(address(token.feeSettings())).feeCollector());

        uint _amount = 100;

        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, _amount);

        vm.prank(minter);
        token.mint(_address, _amount);
        assertTrue(token.balanceOf(_address) == _amount, "balance is wrong");

        vm.expectRevert("ERC20: transfer to the zero address");
        vm.prank(_address);
        token.transfer(address(0), _amount);
    }

    function testTransferFrom0(address _address) public {
        uint _amount = 100;

        vm.expectRevert("ERC20: transfer from the zero address");
        vm.prank(address(0));
        token.transfer(_address, _amount);
    }

    function testFailBurn0() public {
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();
        bytes32 role = token.BURNER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.decreaseMintingAllowance(minter, token.mintingAllowance(minter));
        assertTrue(token.mintingAllowance(minter) == 0);

        vm.prank(minter);
        token.mint(pauser, 0);
        assertTrue(token.balanceOf(pauser) == 0);
        vm.prank(admin);
        token.grantRole(role, burner);
        vm.prank(burner);
        token.burn(pauser, 1);
        assertTrue(token.balanceOf(pauser) == 0);
    }

    function testBeforeTokenTransfer() public {
        // create tokens
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, 100);
        assertTrue(token.mintingAllowance(minter) == 100);

        vm.prank(minter);
        token.mint(pauser, 50);
        assertTrue(token.balanceOf(pauser) == 50);

        // create transferer
        bytes32 roleTransfererAdmin = token.TRANSFERERADMIN_ROLE();
        bytes32 roleTransferer = token.TRANSFERER_ROLE();

        vm.prank(admin);
        token.grantRole(roleTransfererAdmin, transfererAdmin);

        vm.prank(transfererAdmin);
        token.grantRole(roleTransferer, transferer);
        assertTrue(token.hasRole(roleTransferer, transferer));

        vm.prank(transfererAdmin);
        token.grantRole(roleTransferer, burner);
        assertTrue(token.hasRole(roleTransferer, burner));

        // move tokens around
        vm.prank(pauser);
        token.transfer(burner, 50);
        assertTrue(token.balanceOf(burner) == 50);
    }

    function testFailBeforeTokenTransferRequirements1() public {
        // create tokens
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, 100);
        assertTrue(token.mintingAllowance(minter) == 100);

        //testSetRequirements

        bytes32 role = token.REQUIREMENT_ROLE();
        vm.prank(admin);
        token.grantRole(role, requirer);
        vm.prank(requirer);
        token.setRequirements(3);
        assertTrue(token.requirements() == 3);

        vm.prank(minter);
        token.mint(pauser, 50);

        assertTrue(token.balanceOf(pauser) == 50);

        // create transferer
        bytes32 roleTransfererAdmin = token.TRANSFERERADMIN_ROLE();
        bytes32 roleTransferer = token.TRANSFERER_ROLE();

        vm.prank(admin);
        token.grantRole(roleTransfererAdmin, transfererAdmin);

        vm.prank(transfererAdmin);
        token.grantRole(roleTransferer, transferer);
        assertTrue(token.hasRole(roleTransferer, transferer));

        vm.prank(transfererAdmin);
        token.grantRole(roleTransferer, burner);
        assertTrue(token.hasRole(roleTransferer, burner));

        // move tokens around
        vm.prank(pauser);
        token.transfer(burner, 50);
        assertTrue(token.balanceOf(burner) == 50);
    }

    function testBeforeTokenTransferRequirementsOverfulfilled() public {
        // create tokens
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, 100);
        assertTrue(token.mintingAllowance(minter) == 100);

        //testSetRequirements

        bytes32 role = token.REQUIREMENT_ROLE();
        vm.prank(admin);
        token.grantRole(role, requirer);
        vm.prank(requirer);
        token.setRequirements(3);
        assertTrue(token.requirements() == 3, "requirements not set");

        vm.prank(admin);
        allowList.set(pauser, 7);
        vm.prank(minter);
        token.mint(pauser, 50);

        assertTrue(token.balanceOf(pauser) == 50, "balance not minted");
    }

    function testFailBeforeTokenTransferRequirementsNotfulfilled() public {
        // create tokens
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, 100);
        assertTrue(token.mintingAllowance(minter) == 100);

        //testSetRequirements

        bytes32 role = token.REQUIREMENT_ROLE();
        vm.prank(admin);
        token.grantRole(role, requirer);
        vm.prank(requirer);
        token.setRequirements(3);
        assertTrue(token.requirements() == 3);

        vm.prank(admin);
        allowList.set(pauser, 4); // onle on bit set, but bit 1 and 2 (=3) should be set
        vm.prank(minter);
        token.mint(pauser, 50);

        assertTrue(token.balanceOf(pauser) == 50);
    }

    function testBeforeTokenTransferRequirements2() public {
        // create tokens
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, 100);
        assertTrue(token.mintingAllowance(minter) == 100);

        //testSetRequirements

        bytes32 role = token.REQUIREMENT_ROLE();
        vm.prank(admin);
        token.grantRole(role, requirer);
        vm.prank(requirer);
        token.setRequirements(3);
        assertTrue(token.requirements() == 3); // 0x0011

        vm.prank(admin);
        allowList.set(pauser, 7); // 0x0111 -> includes required 0x0011
        vm.prank(minter);
        token.mint(pauser, 50);

        assertTrue(token.balanceOf(pauser) == 50);

        // create transferer
        bytes32 roleTransfererAdmin = token.TRANSFERERADMIN_ROLE();
        bytes32 roleTransferer = token.TRANSFERER_ROLE();

        vm.prank(admin);
        token.grantRole(roleTransfererAdmin, transfererAdmin);

        vm.prank(transfererAdmin);
        token.grantRole(roleTransferer, transferer);
        assertTrue(token.hasRole(roleTransferer, transferer));

        vm.prank(transfererAdmin);
        token.grantRole(roleTransferer, burner);
        assertTrue(token.hasRole(roleTransferer, burner));

        // move tokens around
        vm.prank(pauser);
        token.transfer(burner, 20);
        assertTrue(token.balanceOf(burner) == 20);
        assertTrue(token.balanceOf(pauser) == 30);
    }

    function testFailTransferPause() public {
        // create tokens
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, 100);
        assertTrue(token.mintingAllowance(minter) == 100);

        //testSetRequirements

        bytes32 role = token.REQUIREMENT_ROLE();
        vm.prank(admin);
        token.grantRole(role, requirer);
        vm.prank(requirer);
        token.setRequirements(3);
        assertTrue(token.requirements() == 3);

        vm.prank(admin);
        allowList.set(minter, 3);
        vm.prank(admin);
        allowList.set(pauser, 3);
        vm.prank(minter);
        token.mint(pauser, 50);

        assertTrue(token.balanceOf(pauser) == 50);

        // create transferer
        bytes32 roleTransfererAdmin = token.TRANSFERERADMIN_ROLE();
        bytes32 roleTransferer = token.TRANSFERER_ROLE();

        vm.prank(admin);
        token.grantRole(roleTransfererAdmin, transfererAdmin);

        vm.prank(transfererAdmin);
        token.grantRole(roleTransferer, transferer);
        assertTrue(token.hasRole(roleTransferer, transferer));

        vm.prank(transfererAdmin);
        token.grantRole(roleTransferer, burner);
        assertTrue(token.hasRole(roleTransferer, burner));

        // move tokens around
        vm.prank(pauser);
        token.transfer(burner, 20);
        assertTrue(token.balanceOf(burner) == 20);

        //pause
        bytes32 rolePauser = token.PAUSER_ROLE();
        vm.prank(admin);
        token.grantRole(rolePauser, pauser);
        assertTrue(token.hasRole(rolePauser, pauser));

        vm.prank(pauser);
        token.pause();

        // move tokens around with pause
        vm.prank(pauser);
        token.transfer(burner, 20);
        assertTrue(token.balanceOf(burner) == 20);
    }

    function testTransferUnpaused() public {
        // create tokens
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, 100);
        assertTrue(token.mintingAllowance(minter) == 100);

        //testSetRequirements

        bytes32 role = token.REQUIREMENT_ROLE();
        vm.prank(admin);
        token.grantRole(role, requirer);
        vm.prank(requirer);
        token.setRequirements(3);
        assertTrue(token.requirements() == 3);

        vm.prank(admin);
        allowList.set(minter, 3);
        vm.prank(admin);
        allowList.set(pauser, 3);
        vm.prank(minter);
        token.mint(pauser, 50);

        assertTrue(token.balanceOf(pauser) == 50);

        // create transferer
        bytes32 roleTransfererAdmin = token.TRANSFERERADMIN_ROLE();
        bytes32 roleTransferer = token.TRANSFERER_ROLE();

        vm.prank(admin);
        token.grantRole(roleTransfererAdmin, transfererAdmin);

        vm.prank(transfererAdmin);
        token.grantRole(roleTransferer, transferer);
        assertTrue(token.hasRole(roleTransferer, transferer));

        vm.prank(transfererAdmin);
        token.grantRole(roleTransferer, burner);
        assertTrue(token.hasRole(roleTransferer, burner));

        // move tokens around
        vm.prank(pauser);
        token.transfer(burner, 20);
        assertTrue(token.balanceOf(burner) == 20);

        //pause
        bytes32 rolePauser = token.PAUSER_ROLE();
        vm.prank(admin);
        token.grantRole(rolePauser, pauser);
        assertTrue(token.hasRole(rolePauser, pauser));

        vm.prank(pauser);
        token.pause();

        assertTrue(token.paused());

        vm.prank(pauser);
        token.unpause();

        assertFalse(token.paused());

        // move tokens around with pause
        vm.prank(pauser);
        token.transfer(burner, 20);
        assertTrue(token.balanceOf(burner) == 40);
    }

    function testTransferWith0Requirements() public {
        uint256 mintAmount = 200;
        uint256 transferAmount = 82;
        address receiver = address(0x123);
        vm.assume(mintAmount >= transferAmount);
        vm.assume(mintAmount < type(uint256).max / 2); // avoid overflow due to fees
        vm.assume(receiver != address(0));
        vm.assume(receiver != pauser);

        // create tokens
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, mintAmount);
        assertTrue(token.mintingAllowance(minter) == mintAmount);

        // set requirements to 0
        bytes32 role = token.REQUIREMENT_ROLE();
        vm.prank(admin);
        token.grantRole(role, requirer);
        vm.prank(requirer);
        token.setRequirements(0);
        assertTrue(token.requirements() == 0);

        // mint some tokens
        vm.prank(minter);
        token.mint(pauser, mintAmount);

        assertTrue(token.balanceOf(pauser) == mintAmount);

        // transfer token
        vm.prank(pauser);
        uint256 gasAfter = gasleft();
        uint256 gasBefore = gasleft();
        token.transfer(receiver, transferAmount);
        gasAfter = gasleft();

        console.log("gas used: ", gasBefore - gasAfter);

        assertTrue(token.balanceOf(pauser) == mintAmount - transferAmount);
        assertTrue(token.balanceOf(receiver) == transferAmount);
    }

    function testLoseAndGainRequirements() public {
        address person1 = vm.addr(1);
        address person2 = vm.addr(2);

        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, 100);
        assertTrue(token.mintingAllowance(minter) == 100);

        // //testSetRequirements
        vm.prank(requirer);
        token.setRequirements(11);
        assertTrue(token.requirements() == 11); // 0x1011

        vm.prank(admin);
        allowList.set(person1, 27); // 0x0111 -> includes required 0x0011
        vm.prank(admin);
        allowList.set(person2, 11); // 0x1011

        vm.prank(minter);
        token.mint(person1, 50);
        assertTrue(token.balanceOf(person1) == 50);

        vm.prank(person1);
        token.transfer(person2, 20);
        assertTrue(token.balanceOf(person2) == 20);
        assertTrue(token.balanceOf(person1) == 30);

        // person1 loses requirements
        vm.prank(admin);
        allowList.set(person1, 3); // 0x0011 -> does not include required 0x1011

        console.log("person1: ", person1);

        vm.prank(person1);
        vm.expectRevert(
            "Sender or Receiver is not allowed to transact. Either locally issue the role as a TRANSFERER or they must meet requirements as defined in the allowList"
        );
        token.transfer(person2, 20);
        assertTrue(token.balanceOf(person2) == 20);
        assertTrue(token.balanceOf(person1) == 30);

        vm.prank(person2);
        vm.expectRevert(
            "Sender or Receiver is not allowed to transact. Either locally issue the role as a TRANSFERER or they must meet requirements as defined in the allowList"
        );
        token.transfer(person1, 10);
        assertTrue(token.balanceOf(person2) == 20);
        assertTrue(token.balanceOf(person1) == 30);

        // requirements are lowered to 3
        vm.prank(requirer);
        token.setRequirements(3); // 0x0011
        assertTrue(token.requirements() == 3);

        // now transfers should work again between person 1 and 2
        vm.prank(person1);
        token.transfer(person2, 20);
        assertTrue(token.balanceOf(person2) == 40);
        assertTrue(token.balanceOf(person1) == 10);

        vm.prank(person2);
        token.transfer(person1, 10);
        assertTrue(token.balanceOf(person2) == 30);
        assertTrue(token.balanceOf(person1) == 20);
    }

    /*
        mint more than mintingAllowance
        behavior of mintingAllowance is to not take into account tokens
        already minted once a new allowance is set
    */
    function testExceedMintingAllowance() public {
        address person1 = vm.addr(1);
        address person2 = vm.addr(2);

        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, 100);
        assertTrue(token.mintingAllowance(minter) == 100);

        // //testSetRequirements
        vm.prank(requirer);
        token.setRequirements(11);
        assertTrue(token.requirements() == 11); // 0x1011

        vm.prank(admin);
        allowList.set(person1, 27); // 0x0111 -> includes required 0x0011
        vm.prank(admin);
        allowList.set(person2, 11); // 0x1011

        vm.prank(minter);
        token.mint(person1, 50);
        assertTrue(token.balanceOf(person1) == 50);

        vm.prank(mintAllower);
        token.decreaseMintingAllowance(minter, UINT256_MAX);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, 10);
        assertTrue(token.mintingAllowance(minter) == 10);

        vm.prank(minter);
        //vm.expectRevert("Minting allowance exceeded");
        token.mint(person2, 3);
        assertTrue(token.balanceOf(person2) == 3);
    }

    function testFailSetAllowanceTo0BeforeResetting() public {
        address person1 = vm.addr(1);
        address person2 = vm.addr(2);

        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, 100);
        assertTrue(token.mintingAllowance(minter) == 100);

        // //testSetRequirements
        vm.prank(requirer);
        token.setRequirements(11);
        assertTrue(token.requirements() == 11); // 0x1011

        vm.prank(admin);
        allowList.set(person1, 27); // 0x0111 -> includes required 0x0011
        vm.prank(admin);
        allowList.set(person2, 11); // 0x1011

        vm.prank(minter);
        token.mint(person1, 50);
        assertTrue(token.balanceOf(person1) == 50);

        vm.prank(mintAllower);
        token.increaseMintingAllowance(minter, 10);
        assertTrue(token.mintingAllowance(minter) == 10);

        vm.prank(minter);
        //vm.expectRevert("Minting allowance exceeded");
        token.mint(person2, 3);
        assertTrue(token.balanceOf(person2) == 3);
    }

    function testDeployerDoesNotGetRole() public {
        Token localToken = Token(
            tokenCloneFactory.createTokenProxy(
                0,
                trustedForwarder,
                feeSettings,
                admin,
                allowList,
                0x0,
                "testTokenRole",
                "TEST"
            )
        );
        address deployer = msg.sender;
        assertFalse(localToken.hasRole(localToken.REQUIREMENT_ROLE(), deployer));
        assertFalse(localToken.hasRole(localToken.MINTALLOWER_ROLE(), deployer));
        assertFalse(localToken.hasRole(localToken.BURNER_ROLE(), deployer));
        assertFalse(localToken.hasRole(localToken.TRANSFERERADMIN_ROLE(), deployer));
        assertFalse(localToken.hasRole(localToken.TRANSFERER_ROLE(), deployer));
        assertFalse(localToken.hasRole(localToken.PAUSER_ROLE(), deployer));
    }

    function testAcceptFeeSettings0() public {
        vm.prank(admin);
        vm.expectRevert();
        token.acceptNewFeeSettings(FeeSettings(address(0)));
    }

    /**
     * This test checks if the token contract's storage begins at slot 1000.
     * This is important. For more information, see ../docs/upgradeability.md
     */
    function testTokenStorageGap(address _allowList) public {
        vm.assume(_allowList != address(0));
        vm.startPrank(admin);
        token.setAllowList(AllowList(_allowList));
        vm.stopPrank();

        bytes32 inputAddress = bytes32(uint256(uint160(_allowList)));
        console.logBytes32(inputAddress);
        bytes32 storedAddress = vm.load(address(token), bytes32(uint256(1000)));
        console.logBytes32(storedAddress);

        assertEq(
            storedAddress,
            inputAddress,
            "stored address is not the same as input address. Storage slot of allowList in Token changed!"
        );
    }
}
