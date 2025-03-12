// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/VestingCloneFactory.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/FeeSettings.sol";
import "./resources/ERC20MintableByAnyone.sol";
import "./resources/CloneCreators.sol";

contract VestingDemoTest is Test {
    Vesting implementation;
    VestingCloneFactory vestingFactory;

    TokenProxyFactory tokenFactory;

    address trustedForwarder = address(1);
    address platformAdmin = address(2);
    address employee = address(3);
    address owner = address(7);

    function setUp() public {
        implementation = new Vesting(trustedForwarder);

        vestingFactory = new VestingCloneFactory(address(implementation));

        Token tokenLogic = new Token(trustedForwarder);
        tokenFactory = new TokenProxyFactory(address(tokenLogic));
    }

    /**
     * @notice does the full setup and payout without meta tx
     * @dev Many local variables had to be removed to avoid stack too deep error
     */
    function testDemoEverythingLocal(bytes32 salt, address localCompanyAdmin) public {
        vm.assume(localCompanyAdmin != address(0));
        vm.assume(localCompanyAdmin != trustedForwarder);
        vm.assume(localCompanyAdmin != platformAdmin);
        vm.assume(localCompanyAdmin != employee);
        uint256 amount = 1000e18;
        uint64 start = 1e9;
        uint64 cliff = 1e6;
        uint64 duration = 2e6;
        bool isMintable = true; // the tokens are minted on payout

        vm.startPrank(platformAdmin);
        FeeSettings feeSettings = createFeeSettings(
            trustedForwarder,
            platformAdmin,
            Fees(1, 100, 1, 200, 1, 200, 0),
            platformAdmin,
            platformAdmin,
            platformAdmin
        );
        AllowList allowList = createAllowList(trustedForwarder, owner);
        Token localCompanyToken = Token(
            tokenFactory.createTokenProxy(
                0,
                trustedForwarder,
                feeSettings,
                localCompanyAdmin,
                allowList,
                0,
                "test token",
                "TST"
            )
        );

        // Deploy clone
        Vesting vesting = Vesting(
            vestingFactory.createVestingClone(salt, trustedForwarder, localCompanyAdmin, address(localCompanyToken))
        );
        vm.stopPrank();

        // create vest as company admin
        vm.startPrank(localCompanyAdmin);
        uint64 id = vesting.createVesting(amount, employee, start, cliff, duration, isMintable);
        // grant necessary minting allowance
        localCompanyToken.increaseMintingAllowance(address(vesting), amount);
        vm.stopPrank();

        // accrued and claimable tokens can be checked at any time
        uint timeShift = (cliff * 4) / 5;
        vm.warp(start + timeShift);
        uint unpaid = vesting.releasable(id);
        assertEq(unpaid, 0, "unpaid is wrong: no tokens should be claimable yet");

        // claim tokens as employee
        timeShift = duration / 2;
        vm.warp(start + timeShift);
        assertEq(localCompanyToken.balanceOf(employee), 0, "employee already has tokens");
        vm.prank(employee);
        vesting.release(id);
        assertEq(
            localCompanyToken.balanceOf(employee),
            (amount * timeShift) / duration,
            "employee has received wrong token amount"
        );
    }
}
