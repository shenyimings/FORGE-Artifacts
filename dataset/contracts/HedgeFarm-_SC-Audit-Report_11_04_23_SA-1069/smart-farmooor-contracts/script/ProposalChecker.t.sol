// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Deployer.s.sol";
import "../test/forge/helper/TestHelper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ProposalChecker is Deployer, TestHelper {
    using SafeERC20 for IERC20;

    uint256 public DEPOSIT_AMOUNT;
    uint256 public BIG_DEPOSIT_AMOUNT;
    uint256 public NEW_MIN_HARVEST_THRESHOLD;
    uint256 public PRECISION;
    uint256 public IOU_DECIMALS;

    function setUp() public {
        // Load data and set components needed for the deployment
        // BASE_TOKEN_NAME, TIMELOCK, OWNER, and MANAGER must be set in .env
        loadData();

        // Fetch and set components that have been already deployed
        // [TOKEN]_SMART_FARMOOOR, DEX AND TIMELOCK must be set in .env
        fetchAddresses(SMART_FARMOOOR_ADDRESS);
        setAll();

        IOU_DECIMALS = 1e18;
        PRECISION = 1;
        uint256 decimals = IERC20Metadata(smartFarmooor.baseToken()).decimals();
        if (decimals == 18) {
            PRECISION = 1e12;
            DEPOSIT_AMOUNT = 1000 * 10 ** IERC20Metadata(BASE_TOKEN).decimals();
            BIG_DEPOSIT_AMOUNT =
            100000 *
            10 ** IERC20Metadata(BASE_TOKEN).decimals();
        }
        if (decimals == 8) {
            PRECISION = 1e2;
            DEPOSIT_AMOUNT = 10 ** IERC20Metadata(BASE_TOKEN).decimals();
            BIG_DEPOSIT_AMOUNT = 100 * 10 ** IERC20Metadata(BASE_TOKEN).decimals();
        }
        if (decimals == 6) {
            PRECISION = 1e3;
            DEPOSIT_AMOUNT = 1000 * 10 ** IERC20Metadata(BASE_TOKEN).decimals();
            BIG_DEPOSIT_AMOUNT =
            10000000 *
            10 ** IERC20Metadata(BASE_TOKEN).decimals();
        }
        NEW_MIN_HARVEST_THRESHOLD = 42 * 10 ** IERC20Metadata(BASE_TOKEN).decimals();
    }

    function testSimulateProposal() public {
        // explicitly set the values for active modules, by default they are set to current on chain status of SmartFarmooor fetched using fetchAddresses()
        // if you wish to use values from config file to deploy/stop new module comment lines below
        STARGATE_ACTIVE = STARGATE_ACTIVE_CURRENT_VALUE;
        BENQI_ACTIVE = BENQI_ACTIVE_CURRENT_VALUE;
        BANKER_JOE_ACTIVE = BANKER_JOE_ACTIVE_CURRENT_VALUE;
        AAVE_ACTIVE = AAVE_ACTIVE_CURRENT_VALUE;

        // Deploy, set and configure new components here
        vm.startPrank(DEPLOYER);
        deploySmartFarmooorImpl();
        vm.stopPrank();

        // Execute proposal
        vm.startPrank(TIMELOCK);

        // ... put proposal function calls here
        
        vm.stopPrank();

        // check that the contract have been correctly deployed and initialized
        verifyAll(true, false);

        // Check invariants
        checkInvariants();

        // print the addresses of the components
        printComponentAddresses();
        
        // print the storage of the components
        printComponentStorage();
    }

    function checkInvariants() internal {
        canDeposit();

        _moveBlock(100000);

        canHarvest();

        _moveBlock(5);

        canWithdraw();

        canDeposit();

        canPanic();

        _moveBlock(5);

        canFinishPanic();
    }

    function canDeposit() internal {
        uint256 lastUpdatedPricePerShareBefore = smartFarmooor.lastUpdatedPricePerShare();
        uint256 pricePerShareBefore = smartFarmooor.pricePerShare();

        depositHelper(ALICE, DEPOSIT_AMOUNT);
        
        uint256 lastUpdatedPricePerShareAfter = smartFarmooor.lastUpdatedPricePerShare();
        uint256 pricePerShareAfter = smartFarmooor.pricePerShare();
        assertGt(pricePerShareAfter, pricePerShareBefore);
        assertGt(lastUpdatedPricePerShareAfter, lastUpdatedPricePerShareBefore);
        assertEq(IERC20(BASE_TOKEN).balanceOf(ALICE), 0);
        assertGt(smartFarmooor.balanceOf(ALICE), 0);
    }

    function canHarvest() internal {
        uint256 lastUpdatedPricePerShareBefore = smartFarmooor
            .lastUpdatedPricePerShare();
        uint256 pricePerShareBefore = smartFarmooor.pricePerShare();
        _moveBlock(1000);
        if (BASE_TOKEN != SAVAX) {
            // SAVAX cannot be borrowed so their is no LP interest
            assertGt(
                smartFarmooor.lastUpdatedPricePerShare(),
                lastUpdatedPricePerShareBefore
            );
            assertLt(
                smartFarmooor.lastUpdatedPricePerShare(),
                smartFarmooor.pricePerShare()
            );
        }

        smartFarmooor.harvest();

        uint256 lastUpdatedPricePerShareAfter = smartFarmooor
            .lastUpdatedPricePerShare();
        uint256 pricePerShareAfter = smartFarmooor.pricePerShare();
        assertGt(pricePerShareAfter, pricePerShareBefore);
        assertGt(lastUpdatedPricePerShareAfter, lastUpdatedPricePerShareBefore);
    }

    function canWithdraw() internal {
        uint sharesBefore = smartFarmooor.balanceOf(ALICE);

        withdrawHelper(ALICE, sharesBefore);

        uint sharesAfter = smartFarmooor.balanceOf(ALICE);
        assertEq(sharesAfter, 0);
        assertGt(IERC20(smartFarmooor.baseToken()).balanceOf(ALICE), DEPOSIT_AMOUNT);
    }

    function canPanic() internal {
        vm.prank(MANAGER);
        smartFarmooor.panic();

        assertGt(IERC20(smartFarmooor.baseToken()).balanceOf(address(smartFarmooor)), DEPOSIT_AMOUNT);
        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (IYieldModule module,) = smartFarmooor.yieldOptions(i);
            assertApproxEqAbs(module.getBalance(), 0, smartFarmooor.numberOfModules() * PRECISION);
        }
    }

    function canFinishPanic() internal {
        vm.prank(MANAGER);
        smartFarmooor.finishPanic();

        assertEq(IERC20(smartFarmooor.baseToken()).balanceOf(address(smartFarmooor)), 0);
        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (IYieldModule module,) = smartFarmooor.yieldOptions(i);
            assertGt(module.getBalance(), 0);
        }
    }

    function depositHelper(address user, uint256 amount) internal {
        vm.startPrank(address(user));
        address token = smartFarmooor.baseToken();
        deal(token, user, amount);
        if (IERC20(token).allowance(user, address(smartFarmooor)) == 0) {
            IERC20(token).safeApprove(
                address(smartFarmooor),
                type(uint256).max
            );
        }
        uint256 sharesBefore = smartFarmooor.balanceOf(user);
        
        smartFarmooor.deposit(amount);

        uint256 sharesAfter = smartFarmooor.balanceOf(user);
        assertGt(sharesAfter, sharesBefore);
        vm.stopPrank();
    }

    function withdrawHelper(address user, uint256 shares) internal {
        vm.startPrank(address(user));
        uint256 sharesBefore = smartFarmooor.balanceOf(user);

        smartFarmooor.withdraw(shares);

        uint256 sharesAfter = smartFarmooor.balanceOf(user);
        assertLt(sharesAfter, sharesBefore);
        vm.stopPrank();
    }
}