// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../../../script/Deployer.s.sol";
import "../../../helper/TestHelper.sol";
import "../../../../../contracts/yield/interface/aave/IPool.sol";

contract AaveBaseTest is Deployer, TestHelper {

    event Deposit(address token, uint256 amount);
    event Withdraw(address token, uint256 amount);
    event Collect(address token, uint256 amount);
    event Harvest(address token, uint256 amount);

    uint256 public SMALL_AMOUNT;
    uint256 public BIG_AMOUNT;
    uint256 public ALL_SHARE_AS_FRACTION;

    function setUp() public {
        loadTestData();

        smartFarmooor = SmartFarmooor(payable(address(0x100)));

        deployDex();
        deployAaveYieldModuleImpl();
        deployAaveYieldModule(address(smartFarmooor), address(dex));

        transferOwnershipDex(OWNER);
        transferOwnershipAaveYieldModule(OWNER);

        // We have to use smaller token amount with BTC to avoid reaching the max cap on Aave
        if (BASE_TOKEN == BTCB) {
            SMALL_AMOUNT = 1 * (10 ** IERC20Metadata(aaveYieldModule.baseToken()).decimals()) / 100;
            BIG_AMOUNT = 10 * (10 ** IERC20Metadata(aaveYieldModule.baseToken()).decimals());
        }
        else if (BASE_TOKEN == SAVAX) {
            SMALL_AMOUNT = 100 * (10 ** IERC20Metadata(aaveYieldModule.baseToken()).decimals());
            BIG_AMOUNT = 10000 * (10 ** IERC20Metadata(aaveYieldModule.baseToken()).decimals());
        } else {
            SMALL_AMOUNT = 1000 * (10 ** IERC20Metadata(aaveYieldModule.baseToken()).decimals());
            BIG_AMOUNT = 100000 * (10 ** IERC20Metadata(aaveYieldModule.baseToken()).decimals());
        }
        ALL_SHARE_AS_FRACTION = 1e18;
    }

    function testInitIsCorrect() public {
        verifyAaveYieldModule(OWNER, address(smartFarmooor), address(dex));
    }

    function testCanDeploy() public {
        AaveYieldModule aaveYieldModuleImpl = new AaveYieldModule();

        ERC1967Proxy proxy = new ERC1967Proxy(address(aaveYieldModuleImpl), "");
        AaveYieldModule aaveYieldModule = AaveYieldModule(payable(proxy));

        address[] memory rewards = new address[](1);
        rewards[0] = WAVAX;
        AaveYieldModule.AaveParams memory params = AaveYieldModule
        .AaveParams(
            AAVE_POOL,
            AAVE_POOL_DATA_PROVIDER,
            AAVE_REWARDS_CONTROLLER,
            AAVE_A_TOKEN
        );
        aaveYieldModule.initialize(
            address(smartFarmooor),
            MANAGER,
            BASE_TOKEN,
            AAVE_EXECUTION_FEE,
            address(dex),
            rewards,
            params,
            AAVE_YIELD_MODULE_NAME,
            WRAPPED_NATIVE_TOKEN
        );
    }

    /** helper **/

    function _deposit(address caller, uint256 amount) internal {
        deal(aaveYieldModule.baseToken(), caller, amount);
        vm.startPrank(caller);
        IERC20(aaveYieldModule.baseToken()).approve(address(aaveYieldModule), amount);
        aaveYieldModule.deposit(amount);
        vm.stopPrank();
    }

    function _withdraw(address caller, uint256 shareFraction, address receiver) internal {
        vm.prank(address(caller));
        aaveYieldModule.withdraw(shareFraction, receiver);
    }

    function _harvest(address caller, address receiver) internal {
        vm.prank(address(caller));
        aaveYieldModule.harvest(receiver);
    }
}
