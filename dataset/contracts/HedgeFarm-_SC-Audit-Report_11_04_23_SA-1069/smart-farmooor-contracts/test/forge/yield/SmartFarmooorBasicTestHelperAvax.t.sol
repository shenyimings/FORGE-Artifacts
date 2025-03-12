// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../script/Deployer.s.sol";
import "../helper/TestHelper.sol";
import "../mock/StargateYieldModuleDeltaCreditMock.sol";

contract SmartFarmooorBasicTestHelperAvax is Deployer, TestHelper {
    using SafeERC20 for IERC20;

    uint256 public DEPOSIT_AMOUNT;
    uint256 public BIG_DEPOSIT_AMOUNT;
    uint256 public NEW_MIN_HARVEST_THRESHOLD;
    uint256 public PRECISION;
    uint256 public IOU_DECIMALS;

    address[] public emptyAddresses;

    event Deposit(address indexed user, uint256 amount);
    event Harvest(uint256 profit);
    event Withdraw(address indexed user, uint256 shares, uint amount);

    function setUp() public virtual {
        loadTestData();

        bool doDex = true;
        bool doTimelock = true;
        bool doNativeGateway = BASE_TOKEN == WRAPPED_NATIVE_TOKEN ? true : false;

        vm.startPrank(DEPLOYER);
        deployAll(doDex, doTimelock, doNativeGateway, setPrivateAccessAccounts());
        addAllModules();
        setModuleAllocation();
        smartFarmooor.unpause();
        transferAllOwnership(doDex, doNativeGateway);
        renounceAllRoles(DEPLOYER);
        vm.stopPrank();

        IOU_DECIMALS = 1e18;
        PRECISION = 1;
        uint256 decimals = IERC20Metadata(smartFarmooor.baseToken()).decimals();
        if (decimals == 18) {
            PRECISION = 1e12;
            DEPOSIT_AMOUNT = 1000 * 10 ** IERC20Metadata(BASE_TOKEN).decimals();
            BIG_DEPOSIT_AMOUNT = 100000 * 10 ** IERC20Metadata(BASE_TOKEN).decimals();
        }
        if (decimals == 8) {
            PRECISION = 1e2;
            DEPOSIT_AMOUNT = 10 ** IERC20Metadata(BASE_TOKEN).decimals();
            BIG_DEPOSIT_AMOUNT = 100 * 10 ** IERC20Metadata(BASE_TOKEN).decimals();
        }
        if (decimals == 6) {
            PRECISION = 1e3;
            DEPOSIT_AMOUNT = 1000 * 10 ** IERC20Metadata(BASE_TOKEN).decimals();
            BIG_DEPOSIT_AMOUNT = 10000000 * 10 ** IERC20Metadata(BASE_TOKEN).decimals();
        }
        NEW_MIN_HARVEST_THRESHOLD = 42 * 10 ** IERC20Metadata(BASE_TOKEN).decimals();
    }

    function setPrivateAccessAccounts() internal virtual view returns(address[] memory) {
        return new address[](0);
    }

    function testInitIsCorrect() public {
        verifySmartFarmooor(address(timelock));
    }

    function testCanDeploy() public {
        SmartFarmooor smartFarmooorImpl = new SmartFarmooor();

        ERC1967Proxy proxy = new ERC1967Proxy(address(smartFarmooorImpl), "");
        SmartFarmooor smartFarmooor = SmartFarmooor(payable(proxy));

        smartFarmooor.initialize(
            SM_NAME,
            SM_SYMBOL,
            SM_FEE_MANAGER,
            BASE_TOKEN,
            SM_MIN_HARVEST_THRESHOLD_IN_BASE_TOKEN,
            SM_PERFORMANCE_FEE,
            SM_CAP,
            MANAGER,
            address(timelock),
            SM_MIN_AMOUNT,
            setPrivateAccessAccounts()
        );
        smartFarmooor.pause();
    }

    //Will only make sure that user has more share after deposit than before
    function depositHelper(address user, uint256 amount) public {
        address token = smartFarmooor.baseToken();
        vm.startPrank(address(user));

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

    function withdrawHelper(address user, uint256 shares) public {
        vm.startPrank(address(user));

        uint256 sharesBefore = smartFarmooor.balanceOf(user);
        smartFarmooor.withdraw(shares);

        uint256 sharesAfter = smartFarmooor.balanceOf(user);
        assertLt(sharesAfter, sharesBefore);
        vm.stopPrank();
    }
}
