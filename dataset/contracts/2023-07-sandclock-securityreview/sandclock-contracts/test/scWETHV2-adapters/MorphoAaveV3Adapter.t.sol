// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {IAdapter} from "../../src/steth/IAdapter.sol";
import {MorphoAaveV3Adapter} from "../../src/steth/scWethV2-adapters/MorphoAaveV3Adapter.sol";
import {AaveV3Adapter} from "../../src/steth/scWethV2-adapters/AaveV3Adapter.sol";
import {Constants as C} from "../../src/lib/Constants.sol";
import {IMorpho} from "../../src/interfaces/morpho/IMorpho.sol";

contract MorphoAaveV3AdapterTest is Test {
    using Address for address;

    uint256 mainnetFork;

    MorphoAaveV3Adapter adapter;

    uint256 initWstEthAmount = 100 ether;

    function setUp() public {
        vm.createFork(vm.envString("RPC_URL_MAINNET"));
        vm.selectFork(mainnetFork);
        vm.rollFork(17180994);

        adapter = new MorphoAaveV3Adapter();

        deal(C.WSTETH, address(this), initWstEthAmount);

        address(adapter).functionDelegateCall(abi.encodeWithSelector(IAdapter.setApprovals.selector));
    }

    function test_id() public {
        assertEq(adapter.id(), uint256(keccak256("MorphoAaveV3Adapter")));
    }

    function test_supply() public {
        uint256 amount = 1 ether;

        assertEq(adapter.getCollateral(address(this)), 0);

        _delegateCall(IAdapter.supply.selector, amount);

        assertEq(ERC20(C.WSTETH).balanceOf(address(this)), initWstEthAmount - amount);
        assertApproxEqRel(adapter.getCollateral(address(this)), amount, 10, "collateral supply error");
    }

    function test_withdraw() public {
        uint256 supplyAmount = 1 ether; // in wstEth
        _delegateCall(IAdapter.supply.selector, supplyAmount);

        assertEq(ERC20(C.WSTETH).balanceOf(address(this)), initWstEthAmount - supplyAmount);

        uint256 withdrawAmount = 0.5 ether; // in wstEth

        _delegateCall(IAdapter.withdraw.selector, withdrawAmount);

        assertApproxEqRel(
            ERC20(C.WSTETH).balanceOf(address(this)), initWstEthAmount - supplyAmount + withdrawAmount, 10
        );

        assertApproxEqRel(adapter.getCollateral(address(this)), supplyAmount - withdrawAmount, 10);
    }

    function test_borrow() public {
        uint256 supplyAmount = 1 ether; // in wstEth
        _delegateCall(IAdapter.supply.selector, supplyAmount);

        assertEq(adapter.getDebt(address(this)), 0);

        uint256 borrowAmount = 0.7 ether; // in weth
        _delegateCall(IAdapter.borrow.selector, borrowAmount);

        assertEq(ERC20(C.WETH).balanceOf(address(this)), 0.7 ether);
        assertApproxEqRel(adapter.getDebt(address(this)), borrowAmount, 1, "debt borrow error");
    }

    function test_repay() public {
        uint256 supplyAmount = 1 ether; // in wstEth
        _delegateCall(IAdapter.supply.selector, supplyAmount);

        uint256 borrowAmount = 0.7 ether; // in weth
        _delegateCall(IAdapter.borrow.selector, borrowAmount);

        _delegateCall(IAdapter.repay.selector, borrowAmount);

        assertEq(adapter.getDebt(address(this)), 0, "debt error");
        assertApproxEqRel(ERC20(C.WETH).balanceOf(address(this)), 1, 10, "weth balance error");
    }

    function test_setApprovals() public {
        address morpho = address(adapter.morpho());

        address(adapter).functionDelegateCall(abi.encodeWithSelector(IAdapter.revokeApprovals.selector));

        assertEq(ERC20(C.WSTETH).allowance(address(this), morpho), 0);
        assertEq(ERC20(C.WETH).allowance(address(this), morpho), 0);

        address(adapter).functionDelegateCall(abi.encodeWithSelector(IAdapter.setApprovals.selector));

        // allowances to morpho must be max
        assertEq(ERC20(C.WSTETH).allowance(address(this), morpho), type(uint256).max);
        assertEq(ERC20(C.WETH).allowance(address(this), morpho), type(uint256).max);
    }

    function test_revokeApprovals() public {
        address morpho = address(adapter.morpho());

        address(adapter).functionDelegateCall(abi.encodeWithSelector(IAdapter.revokeApprovals.selector));

        // allowances to morpho must be zero
        assertEq(ERC20(C.WSTETH).allowance(address(this), morpho), 0);
        assertEq(ERC20(C.WETH).allowance(address(this), morpho), 0);

        // must fail
        vm.expectRevert();
        _delegateCall(IAdapter.supply.selector, 1 ether);
    }

    function test_claimRewards() public {
        IMorpho morpho = adapter.morpho();
        address[] memory assets = new address[](1);
        assets[0] = C.WSTETH;

        bytes memory data = abi.encode(assets);

        if (morpho.isClaimRewardsPaused()) {
            // if rewards are paused currently on morpho aave v3 this should revert
            vm.expectRevert();
            address(adapter).functionDelegateCall(abi.encodeWithSelector(IAdapter.claimRewards.selector, data));
        } else {
            address(adapter).functionDelegateCall(abi.encodeWithSelector(IAdapter.claimRewards.selector, data));
        }
    }

    function test_maxLtv() public {
        AaveV3Adapter aaveV3Adapter = new AaveV3Adapter();
        assertEq(adapter.getMaxLtv(), aaveV3Adapter.getMaxLtv());
    }

    function _delegateCall(bytes4 selector, uint256 amount) internal {
        address(adapter).functionDelegateCall(abi.encodeWithSelector(selector, amount));
    }
}
