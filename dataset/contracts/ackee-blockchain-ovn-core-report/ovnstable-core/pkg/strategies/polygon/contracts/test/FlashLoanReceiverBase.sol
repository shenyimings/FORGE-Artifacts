pragma solidity ^0.8.0;

import "./IFlashLoanSimpleReceiver.sol";
import "@overnight-contracts/connectors/contracts/stuff/AaveV3.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@overnight-contracts/common/contracts/libraries/SafeMath.sol";

abstract contract FlashLoanReceiverBase is IFlashLoanSimpleReceiver {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
    IPool public immutable override POOL;

    constructor(address provider) {
        ADDRESSES_PROVIDER = IPoolAddressesProvider(provider);
        POOL = IPool(IPoolAddressesProvider(provider).getPool());
    }
}
