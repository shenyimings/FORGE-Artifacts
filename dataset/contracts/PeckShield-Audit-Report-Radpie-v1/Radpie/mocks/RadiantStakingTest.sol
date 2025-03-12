// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../radiant/RadiantStaking.sol";
import "../libraries/RadiantUtilLib.sol";

contract RadiantStakingTest is RadiantStaking {
    function safeWithdrawAsset(
        address _asset,
        address _rToken,
        uint256 _liquidity,
        bool _isNative
    ) external {
        RadiantUtilLib._safeWithdrawAsset(
            wethGateway,
            lendingPool,
            _asset,
            _rToken,
            _liquidity,
            _isNative
        );
    }

    function depositHelper(
        address _asset,
        address _vdToken,
        uint256 _amount,
        bool isNative,
        bool _isFromBorrow
    ) external {
        RadiantUtilLib._depositHelper(
            wethGateway,
            lendingPool,
            _asset,
            _vdToken,
            _amount,
            isNative,
            _isFromBorrow
        );
    }
}
