// SPDX-License-Identifier: MIT

pragma solidity 0.6;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/utils/Address.sol';

import '../../../Fodl/modules/Lender/LendingDispatcher.sol';

interface ILendingPlatformBSC {
    function redeemAll(address platform, address token) external;

    function getLiquidity(address platform, address token) external returns (uint256);

    function accrueInterest(address platform, address token) external;
}

//  Delegates the calls to adapter
contract LendingDispatcherBSC is LendingDispatcher {
    using Address for address;

    function redeemAll(
        address adapter,
        address platform,
        address token
    ) internal {
        adapter.functionDelegateCall(abi.encodeWithSelector(ILendingPlatformBSC.redeemAll.selector, platform, token));
    }

    function getLiquidity(
        address adapter,
        address platform,
        address token
    ) internal returns (uint256 liquidity) {
        bytes memory returnData = adapter.functionDelegateCall(
            abi.encodeWithSelector(ILendingPlatformBSC.getLiquidity.selector, platform, token)
        );
        return abi.decode(returnData, (uint256));
    }

    function accrueInterest(
        address adapter,
        address platform,
        address token
    ) internal {
        adapter.functionDelegateCall(
            abi.encodeWithSelector(ILendingPlatformBSC.accrueInterest.selector, platform, token)
        );
    }
}
