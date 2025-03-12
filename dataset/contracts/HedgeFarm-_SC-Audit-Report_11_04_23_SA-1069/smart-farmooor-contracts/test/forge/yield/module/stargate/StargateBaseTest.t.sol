// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../../../script/Deployer.s.sol";
import "../../../helper/TestHelper.sol";
import "../../../mock/StargateYieldModuleDeltaCreditMock.sol";

contract StargateBaseTest is Deployer, TestHelper {
    uint256 constant public IOU_DECIMALS = 10 ** 18;

    uint256 public SMALL_AMOUNT;
    uint256 public BIG_AMOUNT;

    event Deposit(address token, uint256 amount);
    event Withdraw(address token, uint256 amount);
    event Collect(address token, uint256 amount);
    event Harvest(address token, uint256 amount);

    function setUp() public {
        loadTestData();

        smartFarmooor = SmartFarmooor(payable(address(0x100)));

        deployDex();
        deployStargateYieldModuleImpl();
        deployStargateYieldModule(address(smartFarmooor), address(dex));

        transferOwnershipDex(OWNER);
        transferOwnershipStargateYieldModule(OWNER);

        SMALL_AMOUNT = 1000 * (10 ** IERC20Metadata(BASE_TOKEN).decimals());
        BIG_AMOUNT = 100000 * (10 ** IERC20Metadata(BASE_TOKEN).decimals());
    }

    function testInitIsCorrect() public {
        verifyStargateYieldModule(OWNER, address(smartFarmooor), address(dex));
    }

    function testCanDeploy() public {
        StargateYieldModule stargateYieldModuleImpl = new StargateYieldModule();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(stargateYieldModuleImpl),
            ""
        );
        StargateYieldModule stargateYieldModule = StargateYieldModule(payable(proxy));

        address[] memory rewards = new address[](1);
        rewards[0] = STG;
        StargateYieldModule.StargateParams memory params = StargateYieldModule
        .StargateParams(
            STARGATE_LP_STAKING,
            STARGATE_ROUTER,
            STARGATE_POOL,
            STARGATE_ROUTER_POOL_ID,
            STARGATE_REDEEM_FROM_CHAIN_ID,
            STARGATE_LP_STAKING_POOL_ID,
            STARGATE_LP_PROFIT_WITHDRAWL_THRESHOLD_IN_BASE_TOKEN
        );
        stargateYieldModule.initialize(
            address(smartFarmooor),
            MANAGER,
            BASE_TOKEN,
            STARGATE_EXECUTION_FEE,
            address(dex),
            rewards,
            params,
            STARGATE_YIELD_MODULE_NAME,
            WRAPPED_NATIVE_TOKEN
        );
    }

    /** helper **/

    function deployStargateYieldModuleImpl() internal override {
        stargateYieldModuleImpl = new StargateYieldModuleDeltaCreditMock();
    }

    function deployStargateYieldModule(address smartFarmooor, address dex) internal override {
        ERC1967Proxy proxy = new ERC1967Proxy(address(stargateYieldModuleImpl), "");
        stargateYieldModule = StargateYieldModuleDeltaCreditMock(payable(proxy));

        address[] memory rewards = new address[](1);
        rewards[0] = STG;
        StargateYieldModule.StargateParams memory params = StargateYieldModule
        .StargateParams(
            STARGATE_LP_STAKING,
            STARGATE_ROUTER,
            STARGATE_POOL,
            STARGATE_ROUTER_POOL_ID,
            STARGATE_REDEEM_FROM_CHAIN_ID,
            STARGATE_LP_STAKING_POOL_ID,
            STARGATE_LP_PROFIT_WITHDRAWL_THRESHOLD_IN_BASE_TOKEN
        );
        stargateYieldModule.initialize(
            smartFarmooor,
            MANAGER,
            BASE_TOKEN,
            STARGATE_EXECUTION_FEE,
            dex,
            rewards,
            params,
            STARGATE_YIELD_MODULE_NAME,
            WRAPPED_NATIVE_TOKEN
        );
    }

    function _transferOwnershipToTimelock() internal {
        deployTimelock();
        vm.startPrank(OWNER);
        transferOwnershipDex(address(timelock));
        transferOwnershipStargateYieldModule(address(timelock));
        vm.stopPrank();
    }

    function _deposit(address caller, uint256 amount) internal {
        deal(BASE_TOKEN, caller, amount);
        vm.startPrank(caller);
        IERC20(BASE_TOKEN).approve(address(stargateYieldModule), amount);
        stargateYieldModule.deposit(amount);
        vm.stopPrank();
    }

    function _withdraw(
        address caller,
        uint256 shareFraction,
        address receiver
    ) internal returns (uint256 instant, uint256 pending) {
        uint256 executionFee = stargateYieldModule.getExecutionFee(shareFraction);
        deal(caller, executionFee);
        vm.prank(address(caller));
        return stargateYieldModule.withdraw{value : executionFee}(shareFraction, receiver);
    }

    function _harvest(
        address caller,
        uint256 aum,
        address receiver
    ) internal {
        vm.prank(address(caller));
        stargateYieldModule.harvest(receiver);
    }

    // Fraction for withdrawal of 100%; share == totalShare
    function _calculateTotalShareFraction() internal view returns (uint256) {
        return _calculateShareFraction(1, 1);
    }

    function _calculateShareFraction(uint256 share, uint256 totalShare) internal view returns (uint256) {
        return share * IOU_DECIMALS / totalShare;
    }
}
