// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../interfaces/IOpenSkyMoneymarket.sol';

import '../dependencies/aave/ILendingPoolAddressesProvider.sol';
import '../dependencies/aave/ILendingPool.sol';
import '../dependencies/aave/IWETHGateway.sol';

import '../libraries/helpers/Errors.sol';

contract AaveV2MoneyMarket is IOpenSkyMoneymarket {
    address private immutable original;

    ILendingPoolAddressesProvider public immutable aaveLendingPoolAddressesProvider;
    IWETHGateway public immutable aaveWETHGateway;

    constructor(ILendingPoolAddressesProvider aaveLendingPoolAddressesProvider_, IWETHGateway aaveWETHGateway_) public {
        aaveLendingPoolAddressesProvider = ILendingPoolAddressesProvider(aaveLendingPoolAddressesProvider_);
        aaveWETHGateway = IWETHGateway(aaveWETHGateway_);
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
        address lendingPool = aaveLendingPoolAddressesProvider.getLendingPool();
        aaveWETHGateway.depositETH{value: amount}(lendingPool, address(this), uint16(0));
    }

    function withdrawCall(uint256 amount) external override requireDelegateCall {
        address to = address(this); // oToken
        require(amount > 0, Errors.MONEY_MARKET_WITHDRAW_AMOUNT_NOT_ALLOWED);

        address lendingPool = aaveLendingPoolAddressesProvider.getLendingPool();
        _approveAWETH(amount);
        aaveWETHGateway.withdrawETH(lendingPool, amount, to);
    }

    function _approveAWETH(uint256 amount) internal virtual {
        address aWETH = getAWETHAddress();
        require(IERC20(aWETH).approve(address(aaveWETHGateway), amount), Errors.MONEY_MARKET_APPROVAL_FAILED);
    }

    function getAWETHAddress() public view virtual returns (address) {
        address lendingPool = aaveLendingPoolAddressesProvider.getLendingPool();
        address WETH = aaveWETHGateway.getWETHAddress();
        address aWETH = ILendingPool(lendingPool).getReserveData(address(WETH)).aTokenAddress;

        return aWETH;
    }

    function getBalance(address account) external view override returns (uint256) {
        address aWETH = getAWETHAddress();
        return IERC20(aWETH).balanceOf(account);
    }

    function getSupplyRate() external view override returns (uint256) {
        address lendingPool = aaveLendingPoolAddressesProvider.getLendingPool();
        address WETH = aaveWETHGateway.getWETHAddress();
        return ILendingPool(lendingPool).getReserveData(WETH).currentLiquidityRate;
    }

    receive() external payable {
        revert('RECEIVE_NOT_ALLOWED');
    }

    fallback() external payable {
        revert('FALLBACK_NOT_ALLOWED');
    }
}
