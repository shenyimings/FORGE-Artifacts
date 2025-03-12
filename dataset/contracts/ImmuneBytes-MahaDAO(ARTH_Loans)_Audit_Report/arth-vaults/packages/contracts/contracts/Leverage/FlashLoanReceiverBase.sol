// SPDX-License-Identifier: MIT
// NOTE: taken from `https://github.com/DecenterApps/defisaver-contracts/blob/master/contracts/utils/FlashLoanReceiverBase.sol`.

pragma solidity 0.6.11;

import "../Dependencies/SafeERC20.sol";
import "../Dependencies/IFlashLoanReceiver.sol";
import "../Dependencies/ILendingPoolAddressesProvider.sol";

library EthAddressLib {
    function ethAddress() internal pure returns(address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;   // Need to confirm this addr.
    }
}

abstract contract FlashLoanReceiverBase is IFlashLoanReceiver {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    ILendingPoolAddressesProvider public addressesProvider;

    constructor(ILendingPoolAddressesProvider _provider) public {
        addressesProvider = _provider;
    }

    receive () external virtual payable {}

    function transferFundsBackToPoolInternal(address _reserve, uint256 _amount) internal {
        address payable core = addressesProvider.getLendingPoolCore();

        transferInternal(core,_reserve, _amount);
    }

    function transferInternal(address payable _destination, address _reserve, uint256  _amount) internal {
        if(_reserve == EthAddressLib.ethAddress()) {
            // solhint-disable-next-line
            (bool success,) = _destination.call{value: _amount}("");
            require(success, "FlashLoanReceiverBase: tx failed");
            return;
        }

        ERC20(_reserve).safeTransfer(_destination, _amount);
    }

    function getBalanceInternal(address _target, address _reserve) internal view returns(uint256) {
        if(_reserve == EthAddressLib.ethAddress()) {
            return _target.balance;
        }

        return ERC20(_reserve).balanceOf(_target);
    }
}