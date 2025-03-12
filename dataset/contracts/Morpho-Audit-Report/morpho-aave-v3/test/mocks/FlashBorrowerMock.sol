// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IPool} from "@aave-v3-core/interfaces/IPool.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

contract FlashBorrowerMock {
    using SafeTransferLib for ERC20;

    IPool internal immutable _POOL;

    constructor(address pool) {
        _POOL = IPool(pool);
    }

    function flashLoanSimple(address asset, uint256 amount) external {
        _POOL.flashLoanSimple(address(this), asset, amount, "", 0);
    }

    function executeOperation(address asset, uint256 amount, uint256 fee, address, bytes calldata)
        external
        returns (bool)
    {
        ERC20(asset).safeApprove(address(_POOL), amount + fee);

        return true;
    }
}
