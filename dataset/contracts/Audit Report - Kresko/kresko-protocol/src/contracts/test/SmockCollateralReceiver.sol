// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;
import {IDepositWithdrawFacet} from "../minter/interfaces/IDepositWithdrawFacet.sol";
import {ICollateralReceiver} from "../minter/interfaces/ICollateralReceiver.sol";
import {IERC20Permit} from "../shared/IERC20Permit.sol";
import {ProxyConnector} from "@redstone-finance/evm-connector/contracts/core/ProxyConnector.sol";

contract SmockCollateralReceiver is ICollateralReceiver, ProxyConnector {
    IDepositWithdrawFacet public kresko;
    function(address, address, uint256, bytes memory) internal callbackLogic;

    address public account;
    address public collateralAsset;
    uint256 public withdrawalAmountRequested;
    uint256 public withdrawalAmountReceived;
    Params public userData;

    struct Params {
        uint256 val;
        uint256 val1;
        address addr;
    }

    constructor(address _kresko) {
        kresko = IDepositWithdrawFacet(_kresko);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Callback                                  */
    /* -------------------------------------------------------------------------- */

    function onUncheckedCollateralWithdraw(
        address _account,
        address _collateralAsset,
        uint256 _withdrawalAmount,
        uint256 _depositedCollateralAssetIndex,
        bytes memory _userData
    ) external returns (bytes memory) {
        _depositedCollateralAssetIndex;
        callbackLogic(_account, _collateralAsset, _withdrawalAmount, _userData);
        return "";
    }

    function execute(
        address _collateralAsset,
        uint256 _amount,
        function(address, address, uint256, bytes memory) internal logic
    ) internal {
        bytes memory data = abi.encode(_amount, 0, address(0));
        execute(_collateralAsset, _amount, data, logic);
    }

    function execute(
        address _collateralAsset,
        uint256 _amount,
        bytes memory data,
        function(address, address, uint256, bytes memory) internal logic
    ) internal {
        callbackLogic = logic;
        withdrawalAmountRequested = _amount;
        bytes memory encodedFunction = abi.encodeWithSelector(
            kresko.withdrawCollateralUnchecked.selector,
            msg.sender,
            _collateralAsset,
            _amount,
            0,
            data
        );
        proxyCalldata(address(kresko), encodedFunction, false);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Test functions                               */
    /* -------------------------------------------------------------------------- */

    // should send correct values to the callback
    function test(address _collateralAsset, uint256 _amount) external {
        execute(_collateralAsset, _amount, logicBase);
    }

    function testWithdrawalAmount(address _collateralAsset, uint256 _amount) external {
        execute(_collateralAsset, _amount, logicTestWithdrawalAmount);
    }

    // should be able to redeposit
    function testRedeposit(address _collateralAsset, uint256 _amount) external {
        execute(_collateralAsset, _amount, logicRedeposit);
    }

    // should be able to redeposit
    function testInsufficientRedeposit(address _collateralAsset, uint256 _amount) external {
        execute(_collateralAsset, _amount, logicInsufficientRedeposit);
    }

    function testDepositAlternate(address _collateralWithdraw, uint _amount, address _collateralDeposit) external {
        bytes memory data = abi.encode(_amount, 0, _collateralDeposit);
        execute(_collateralWithdraw, _amount, data, logicDepositAlternate);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Callback Execution                             */
    /* -------------------------------------------------------------------------- */

    function logicDepositAlternate(
        address _account,
        address _collateralAsset,
        uint256 _withdrawalAmount,
        bytes memory _userData
    ) internal {
        _collateralAsset;
        userData = abi.decode(_userData, (Params));
        withdrawalAmountReceived = _withdrawalAmount;
        IERC20Permit(userData.addr).transferFrom(_account, address(this), userData.val);
        IERC20Permit(userData.addr).approve(address(kresko), userData.val);
        // redeposit all
        kresko.depositCollateral(_account, userData.addr, userData.val);
    }

    function logicBase(
        address _account,
        address _collateralAsset,
        uint256 _withdrawalAmount,
        bytes memory _userData
    ) internal {
        // just set data
        account = _account;
        collateralAsset = _collateralAsset;
        withdrawalAmountReceived = _withdrawalAmount;
        userData = abi.decode(_userData, (Params));
    }

    function logicTestWithdrawalAmount(
        address _account,
        address _collateralAsset,
        uint256 _withdrawalAmount,
        bytes memory _userData
    ) internal {
        _userData;
        account = _account;
        require(IERC20Permit(_collateralAsset).balanceOf(address(this)) == _withdrawalAmount, "wrong amount received");
    }

    function logicRedeposit(
        address _account,
        address _collateralAsset,
        uint256 _withdrawalAmount,
        bytes memory _userData
    ) internal {
        _userData;
        withdrawalAmountReceived = _withdrawalAmount;
        IERC20Permit(_collateralAsset).approve(address(kresko), _withdrawalAmount);
        // redeposit all
        kresko.depositCollateral(_account, _collateralAsset, _withdrawalAmount);
    }

    function logicInsufficientRedeposit(
        address _account,
        address _collateralAsset,
        uint256 _withdrawalAmount,
        bytes memory _userData
    ) internal {
        _userData;
        withdrawalAmountReceived = _withdrawalAmount;
        IERC20Permit(_collateralAsset).approve(address(kresko), 1);
        // bare minimum redeposit
        kresko.depositCollateral(_account, _collateralAsset, 1);
    }
}
