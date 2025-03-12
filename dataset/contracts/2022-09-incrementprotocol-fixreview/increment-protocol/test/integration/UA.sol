// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {ERC20Permit} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {Deployment} from "../helpers/Deployment.MainnetFork.sol";
import {SigUtils} from "../helpers/SigUtils.sol";

// interfaces
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IUA} from "../../contracts/interfaces/IUA.sol";

// libraries
import {LibPerpetual} from "../../contracts/lib/LibPerpetual.sol";
import "../../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../../contracts/lib/LibMath.sol";
import {LibReserve} from "../../contracts/lib/LibReserve.sol";

contract UA is Deployment {
    // events
    event ReserveTokenAdded(IERC20Metadata indexed newToken, uint256 numReserveTokens);
    event ReserveTokenMaxMintCapUpdated(IERC20Metadata indexed token, uint256 newMintCap);

    // libraries
    using LibMath for uint256;
    using LibMath for int256;

    // config
    uint256 mintCap;
    uint256 mintCapInUSDC;

    // permit
    ERC20Permit internal usdcPermit;
    SigUtils internal sigUtils;

    function setUp() public virtual override {
        super.setUp();
        mintCap = ua.getReserveToken(0).mintCap;
        mintCapInUSDC = LibReserve.wadToToken(usdc.decimals(), mintCap);
        usdcPermit = ERC20Permit(USDC);
        sigUtils = new SigUtils(usdcPermit.DOMAIN_SEPARATOR());
    }

    function test_ShouldDeployWithCorrectValues() public {
        assertEq(ua.name(), "Increment Unit of Account");
        assertEq(ua.symbol(), "UA");

        IUA.ReserveToken memory firstReserveToken = ua.getReserveToken(0);
        assertEq(address(firstReserveToken.asset), address(usdc));
        assertEq(firstReserveToken.currentReserves, 0);
        assertEq(firstReserveToken.mintCap, mintCap);

        assertEq(address(ua.initialReserveToken()), address(firstReserveToken.asset));
    }

    function testFuzz_FailsToAddReserveTokenWithoutGovernanceRole(address caller) public {
        vm.assume(caller != address(this));
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                Strings.toHexString(uint256(ua.GOVERNANCE()), 32)
            )
        );
        vm.startPrank(caller);
        ua.addReserveToken(IERC20Metadata(DAI), 0);
        vm.stopPrank();
    }

    function test_FailsIfGovernanceTriesToAddSameReserveTokenTwice() public {
        assertEq(ua.getNumReserveTokens(), 1);

        vm.expectRevert(IUA.UA_ReserveTokenAlreadyAssigned.selector);
        ua.addReserveToken(usdc, 0);

        assertEq(ua.getNumReserveTokens(), 1);
    }

    function test_FailsToAddReserveTokenWithZeroAddress() public {
        vm.expectRevert(IUA.UA_ReserveTokenZeroAddress.selector);
        ua.addReserveToken(IERC20Metadata(address(0)), 0);
    }

    function testFuzz_ShouldBeAbleToAddNewReserveToken(uint256 newMintCap) public {
        assertEq(ua.getNumReserveTokens(), 1);

        vm.expectEmit(true, true, true, true, address(ua));
        emit ReserveTokenAdded(IERC20Metadata(DAI), 2);
        ua.addReserveToken(IERC20Metadata(DAI), newMintCap);

        assertEq(ua.getNumReserveTokens(), 2);

        IUA.ReserveToken memory secondReserveToken = ua.getReserveToken(1);
        assertEq(address(secondReserveToken.asset), address(DAI));
        assertEq(secondReserveToken.currentReserves, 0);
        assertEq(secondReserveToken.mintCap, newMintCap);
    }

    function testFuzz_FailsToUpdateMaxMitCapWithoutGovernanceRole(address caller, uint256 newMintCap) public {
        vm.assume(caller != address(this));
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                Strings.toHexString(uint256(ua.GOVERNANCE()), 32)
            )
        );
        vm.startPrank(caller);
        ua.changeReserveTokenMaxMintCap(usdc, newMintCap);
        vm.stopPrank();
    }

    function testFuzz_FailsToUpdateMaxMintCapForNonExistingReserveToken(uint256 newMintCap) public {
        vm.expectRevert(IUA.UA_UnsupportedReserveToken.selector);
        ua.changeReserveTokenMaxMintCap(IERC20Metadata(DAI), newMintCap);
    }

    function testFuzz_ShouldUpdateMaxMintCapForExistingReserveToken(uint256 newMintCap) public {
        vm.expectEmit(true, true, true, true, address(ua));
        emit ReserveTokenMaxMintCapUpdated(IERC20Metadata(USDC), newMintCap);
        ua.changeReserveTokenMaxMintCap(usdc, newMintCap);

        assertEq(ua.getReserveToken(0).mintCap, newMintCap);
    }

    function testFuzz_FailsToMintWithUnsupportedToken(uint256 amount, address caller) public {
        vm.expectRevert(IUA.UA_UnsupportedReserveToken.selector);
        vm.startPrank(caller);
        ua.mintWithReserve(IERC20Metadata(DAI), amount);
        vm.stopPrank();
    }

    function testFuzz_FailsToMintUAWithoutAmountAllowance(uint256 amount) public {
        amount = bound(amount, 1, mintCapInUSDC);
        deal(address(usdc), address(this), amount);
        assertEq(ua.allowance(address(this), address(ua)), 0);

        vm.expectRevert(abi.encodePacked("ERC20: transfer amount exceeds allowance"));
        ua.mintWithReserve(usdc, amount);
    }

    function testFuzz_FailsToMintWithInsufficientReserveValue(uint256 amount) public {
        amount = bound(amount, 2, mintCapInUSDC);
        deal(address(usdc), address(this), amount - 1);

        usdc.approve(address(ua), amount);
        vm.expectRevert(abi.encodePacked("ERC20: transfer amount exceeds balance"));
        ua.mintWithReserve(usdc, amount);
    }

    function testFuzz_FailsToMintMoreThanMintCap(uint256 amount) public {
        amount = bound(amount, 1, mintCapInUSDC);
        uint256 newMintCap = bound(amount, 0, amount - 1);
        deal(address(usdc), address(this), amount);

        ua.changeReserveTokenMaxMintCap(usdc, newMintCap);

        usdc.approve(address(ua), amount);
        vm.expectRevert(IUA.UA_ExcessiveTokenMintCapReached.selector);
        ua.mintWithReserve(usdc, amount);
    }

    function testFuzz_ShouldMintUAIfCorrectAmountOfWhitelistedReserveTokenProvided(uint256 amount) public {
        amount = bound(amount, 1, mintCapInUSDC);
        deal(address(usdc), address(this), amount);

        uint256 initialUASupply = ua.totalSupply();
        uint256 initialUAReserveBalanceOf = usdc.balanceOf(address(ua));
        uint256 initialUAReserveBalance = ua.getReserveToken(0).currentReserves;
        uint256 initialUAUABalance = ua.balanceOf(address(ua));
        uint256 initialUserUABalance = ua.balanceOf(address(this));
        uint256 initialUserReserveBalance = usdc.balanceOf(address(this));

        usdc.approve(address(ua), amount);
        ua.mintWithReserve(usdc, amount);

        assertEq(ua.totalSupply(), initialUASupply + (amount * 1e18) / 1e6);
        assertEq(usdc.balanceOf(address(ua)), initialUAReserveBalanceOf + amount);
        assertEq(ua.getReserveToken(0).currentReserves, initialUAReserveBalance + (amount * 1e18) / 1e6);
        assertEq(ua.balanceOf(address(ua)), initialUAUABalance); // no change
        assertEq(ua.balanceOf(address(this)), initialUserUABalance + (amount * 1e18) / 1e6);
        assertEq(usdc.balanceOf(address(this)), initialUserReserveBalance - amount);
    }

    function testFuzz_HelperShouldMintAndDepositUAApproved(uint256 amount) public {
        amount = bound(amount, 1, mintCapInUSDC);
        deal(address(usdc), address(this), amount);

        uint256 initialUASupply = ua.totalSupply();
        uint256 initialUAReserveBalanceOf = usdc.balanceOf(address(ua));
        uint256 initialUAReserveBalance = ua.getReserveToken(0).currentReserves;
        uint256 initialVaultUABalance = ua.balanceOf(address(vault));
        uint256 initialUserUABalance = ua.balanceOf(address(this));
        uint256 initialUserReserveBalance = usdc.balanceOf(address(this));

        usdc.approve(address(uaHelper), amount);
        uaHelper.depositReserveToken(usdc, amount);

        assertEq(ua.totalSupply(), initialUASupply + (amount * 1e18) / 1e6);
        assertEq(usdc.balanceOf(address(ua)), initialUAReserveBalanceOf + amount);
        assertEq(ua.getReserveToken(0).currentReserves, initialUAReserveBalance + (amount * 1e18) / 1e6);
        assertEq(ua.balanceOf(address(vault)), initialVaultUABalance + (amount * 1e18) / 1e6);
        assertEq(ua.balanceOf(address(this)), initialUserUABalance); // no change
        assertEq(usdc.balanceOf(address(this)), initialUserReserveBalance - amount);
    }

    function testFuzz_HelperShouldMintAndDepositUAPermit(uint256 amount) public {
        amount = bound(amount, 1, mintCapInUSDC);
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        deal(address(usdc), owner, amount);

        uint256 initialUAReserveBalanceOf = usdc.balanceOf(address(ua));
        uint256 initialUAReserveBalance = ua.getReserveToken(0).currentReserves;
        uint256 initialVaultUABalance = ua.balanceOf(address(vault));
        uint256 initialUserReserveBalance = usdc.balanceOf(owner);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: address(uaHelper),
            value: amount,
            nonce: usdcPermit.nonces(owner),
            deadline: type(uint256).max
        });
        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        vm.startPrank(owner);
        uaHelper.depositReserveToken(usdcPermit, amount, type(uint256).max, v, r, s);

        assertEq(usdc.balanceOf(address(ua)), initialUAReserveBalanceOf + amount);
        assertEq(ua.getReserveToken(0).currentReserves, initialUAReserveBalance + (amount * 1e18) / 1e6);
        assertEq(ua.balanceOf(address(vault)), initialVaultUABalance + (amount * 1e18) / 1e6);
        assertEq(usdc.balanceOf(owner), initialUserReserveBalance - amount);
    }

    function testFuzz_FailsToWithdrawAmountLargerThanOwned(uint256 amount) public {
        amount = bound(amount, 1, mintCapInUSDC);
        deal(address(usdc), address(this), amount);

        usdc.approve(address(ua), amount);
        ua.mintWithReserve(usdc, amount);

        vm.expectRevert();
        ua.withdraw(usdc, ((amount * 1e18) / 1e6) + 1);
    }

    function testFuzz_HelperFailsToWithdrawAmountLargerThanOwned(uint256 amount) public {
        amount = bound(amount, 1, mintCapInUSDC);
        deal(address(usdc), address(this), amount);

        usdc.approve(address(uaHelper), amount);
        uaHelper.depositReserveToken(usdc, amount);

        uint256 uaAmount = (amount * 1e18) / 1e6;
        clearingHouse.increaseAllowance(address(uaHelper), uaAmount + 1, ua);
        vm.expectRevert();
        uaHelper.withdrawReserveToken(usdc, uaAmount + 1);
    }

    function testFuzz_ShouldWithdrawAmountOwned(uint256 amount) public {
        amount = bound(amount, 1, mintCapInUSDC);
        deal(address(usdc), address(this), amount);

        uint256 initialUASupply = ua.totalSupply();
        uint256 initialUAReserveBalanceOf = usdc.balanceOf(address(ua));
        uint256 initialUAReserveBalance = ua.getReserveToken(0).currentReserves;
        uint256 initialUAUABalance = ua.balanceOf(address(ua));
        uint256 initialUserUABalance = ua.balanceOf(address(this));
        uint256 initialUserReserveBalance = usdc.balanceOf(address(this));

        usdc.approve(address(ua), amount);
        ua.mintWithReserve(usdc, amount);
        ua.withdraw(usdc, (amount * 1e18) / 1e6);

        assertEq(ua.totalSupply(), initialUASupply);
        assertEq(usdc.balanceOf(address(ua)), initialUAReserveBalanceOf);
        assertEq(ua.getReserveToken(0).currentReserves, initialUAReserveBalance);
        assertEq(ua.balanceOf(address(ua)), initialUAUABalance); // no change
        assertEq(ua.balanceOf(address(this)), initialUserUABalance);
        assertEq(usdc.balanceOf(address(this)), initialUserReserveBalance);
    }

    function testFuzz_HelperShouldWithdrawAmountOwned(uint256 amount) public {
        amount = bound(amount, 1, mintCapInUSDC);
        deal(address(usdc), address(this), amount);

        uint256 initialUASupply = ua.totalSupply();
        uint256 initialUAReserveBalanceOf = usdc.balanceOf(address(ua));
        uint256 initialUAReserveBalance = ua.getReserveToken(0).currentReserves;
        uint256 initialVaultUABalance = ua.balanceOf(address(vault));
        uint256 initialUserUABalance = ua.balanceOf(address(this));
        uint256 initialUserReserveBalance = usdc.balanceOf(address(this));

        usdc.approve(address(uaHelper), amount);
        uaHelper.depositReserveToken(usdc, amount);

        uint256 uaAmount = (amount * 1e18) / 1e6;
        clearingHouse.increaseAllowance(address(uaHelper), uaAmount, ua);
        uaHelper.withdrawReserveToken(usdc, uaAmount);

        assertEq(ua.totalSupply(), initialUASupply);
        assertEq(usdc.balanceOf(address(ua)), initialUAReserveBalanceOf);
        assertEq(ua.getReserveToken(0).currentReserves, initialUAReserveBalance);
        assertEq(ua.balanceOf(address(vault)), initialVaultUABalance);
        assertEq(ua.balanceOf(address(this)), initialUserUABalance); // no change
        assertEq(usdc.balanceOf(address(this)), initialUserReserveBalance);
    }

    function testFuzz_FailsToReturnReserveTokenOutOfRange(uint256 tokenIdx) public {
        tokenIdx = bound(tokenIdx, ua.getNumReserveTokens(), type(uint256).max);
        vm.expectRevert(IUA.UA_UnsupportedReserveToken.selector);
        ua.getReserveToken(tokenIdx);
    }

    function testFuzz_FailsToWithdrawUnsupportedToken(IERC20Metadata token) public {
        vm.assume(address(token) != address(usdc));
        vm.expectRevert(IUA.UA_UnsupportedReserveToken.selector);
        ua.withdraw(token, 0);
    }
}
