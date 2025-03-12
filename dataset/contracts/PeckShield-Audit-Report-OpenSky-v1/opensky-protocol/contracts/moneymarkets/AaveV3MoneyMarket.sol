// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

pragma experimental ABIEncoderV2;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../interfaces/IOpenSkyMoneymarket.sol';
import '../dependencies/aave-v3/IPoolAddressesProvider.sol';
import '../dependencies/aave-v3/IPool.sol';
import '../dependencies/aave-v3/IWETHGateway.sol';
import '../libraries/helpers/Errors.sol';

contract AaveV3MoneyMarket is IOpenSkyMoneymarket {
    address private immutable original;

    IPoolAddressesProvider public immutable aaveLendingPoolAddressesProvider;
    IWETHGateway public immutable aaveWETHGateway;
    IERC20 public immutable aWETH;

    constructor(
        IPoolAddressesProvider aaveLendingPoolAddressesProvider_,
        IWETHGateway aaveWETHGateway_,
        IERC20 aWETH_
    ) public {
        aaveLendingPoolAddressesProvider = aaveLendingPoolAddressesProvider_;
        aaveWETHGateway = aaveWETHGateway_;
        aWETH = aWETH_;
        original = address(this);
    }

    function _requireDelegateCall() private view {
        require(address(this) != original);
    }

    modifier requireDelegateCall() {
        _requireDelegateCall();
        _;
    }

    function depositCall(uint256 amount) external payable override requireDelegateCall {
        require(amount > 0, Errors.MONEY_MARKET_DEPOSIT_AMOUNT_ALLOWED);
        address lendingPool = aaveLendingPoolAddressesProvider.getPool();
        aaveWETHGateway.depositETH{value: amount}(lendingPool, address(this), uint16(0));
    }

    function withdrawCall(uint256 amount) external override requireDelegateCall {
        address to = address(this); // oToken
        require(amount > 0, Errors.MONEY_MARKET_WITHDRAW_AMOUNT_NOT_ALLOWED);
        address lendingPool = aaveLendingPoolAddressesProvider.getPool();
        _approveAWETH(amount);
        aaveWETHGateway.withdrawETH(lendingPool, amount, to);
    }

    function _approveAWETH(uint256 amount) internal virtual {
        require(aWETH.approve(address(aaveWETHGateway), amount), Errors.MONEY_MARKET_APPROVAL_FAILED);
    }

    function getBalance(address account) public view override returns (uint256) {
        return IERC20(aWETH).balanceOf(account);
    }

    function getSupplyRate() external view override returns (uint256) {
        address lendingPool = aaveLendingPoolAddressesProvider.getPool();
        address WETH = aaveWETHGateway.getWETHAddress();
        return IPool(lendingPool).getReserveData(WETH).currentLiquidityRate;
    }

    receive() external payable {
        revert('RECEIVE_NOT_ALLOWED');
    }

    fallback() external payable {
        revert('FALLBACK_NOT_ALLOWED');
    }
}
