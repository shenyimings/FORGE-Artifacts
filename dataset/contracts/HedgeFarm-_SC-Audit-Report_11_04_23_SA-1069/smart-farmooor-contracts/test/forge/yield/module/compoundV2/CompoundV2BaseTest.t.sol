// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../../../script/Deployer.s.sol";
import "../../../helper/TestHelper.sol";

contract CompoundV2BaseTest is Deployer, TestHelper {

    event Deposit(address token, uint256 amount);
    event Withdraw(address token, uint256 amount);
    event Collect(address token, uint256 amount);
    event Harvest(address token, uint256 amount);

    CompoundV2Module public yieldModule;

    uint256 public PRECISION;
    uint256 public VERY_SMALL_AMOUNT;
    uint256 public SMALL_AMOUNT;
    uint256 public BIG_AMOUNT;
    uint256 public ALL_SHARE_AS_FRACTION;
    address public COMPTROLLER;
    address public C_TOKEN;

    // NOTE: We test the forks of compoundV2 against benqi

    function setUp() public {
        loadTestData();

        smartFarmooor = SmartFarmooor(payable(address(0x100)));

        deployDex();
        deployBenqiYieldModuleImpl();
        deployBenqiYieldModule(address(smartFarmooor), address(dex));

        transferOwnershipDex(OWNER);
        transferOwnershipBenqiYieldModule(OWNER);

        yieldModule = benqiYieldModule;

        PRECISION = 1;
        uint256 decimals = IERC20Metadata(yieldModule.baseToken()).decimals();
        if (decimals == 18) {
            PRECISION = 10**9;
        }
        VERY_SMALL_AMOUNT = 10 ** IERC20Metadata(yieldModule.baseToken()).decimals() / 10000;
        SMALL_AMOUNT = 1000 * (10 ** IERC20Metadata(yieldModule.baseToken()).decimals());
        BIG_AMOUNT = 100000 * (10 ** IERC20Metadata(yieldModule.baseToken()).decimals());
        if (decimals == 18) {
            VERY_SMALL_AMOUNT = 1000000000000;
        }

        /**
        NOTE:
        When one withdraws 100% of the shares, shareFraction is equal to 1e18
        Reason:
         - The smart farmooor compute the shareFraction as follow: shareFraction = (_shares * 1e18) / totalSupply()
         - So in that particular case _shares equals to totalSupply() so shareFraction is equal to 1e18
        */
        ALL_SHARE_AS_FRACTION = 1e18;
        COMPTROLLER = BENQI_COMPTROLLER;
        C_TOKEN = BENQI_TOKEN;
    }

    function testInitIsCorrect() public {
        verifyBenqiYieldModule(OWNER, address(smartFarmooor), address(dex));
    }

    function testCanDeploy() public {
        CompoundV2Module benqiYieldModuleImpl = new CompoundV2Module();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(benqiYieldModuleImpl),
            ""
        );
        CompoundV2Module benqiYieldModule = CompoundV2Module(payable(proxy));

        address[] memory rewards = new address[](2);
        rewards[0] = QI;
        rewards[1] = WAVAX;
        benqiYieldModule.initialize(
            address(smartFarmooor),
            MANAGER,
            BASE_TOKEN,
            BENQI_EXECUTION_FEE,
            address(dex),
            rewards,
            BENQI_COMPTROLLER,
            BENQI_TOKEN,
            BENQI_YIELD_MODULE_NAME,
            WRAPPED_NATIVE_TOKEN);
    }

    /** helper **/

    function _deposit(address caller, uint256 amount) internal {
        deal(yieldModule.baseToken(), caller, amount);
        vm.startPrank(caller);
        IERC20(yieldModule.baseToken()).approve(address(yieldModule), amount);
        yieldModule.deposit(amount);
        vm.stopPrank();
    }

    function _withdraw(address caller, uint256 shareFraction, address receiver) internal {
        vm.prank(address(caller));
        yieldModule.withdraw(shareFraction, receiver);
    }

    function _harvest(address caller, address receiver) internal {
        vm.prank(address(caller));
        yieldModule.harvest(receiver);
    }
}
