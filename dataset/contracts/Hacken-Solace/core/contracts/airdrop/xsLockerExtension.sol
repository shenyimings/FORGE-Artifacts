// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./../interfaces/staking/IxsLocker.sol";
import "./../interfaces/airdrop/IxsLockerExtension.sol";

/**
 * @title xsLockerExtension
 * @author solace.fi
 * @notice A utility contract to distribute [**SOLACE**](./../SOLACE) to multiple [**xslocks**](./../staking/xsLocker).
 */
// solhint-disable-next-line contract-name-camelcase
contract xsLockerExtension is IxsLockerExtension, ReentrancyGuard {

    /// @notice [**SOLACE**](./../SOLACE) token.
    address public immutable solace;

    /// @notice xsLocker contract address.
    address public immutable xslocker;

    /**
     * @param solace_ Address of [**SOLACE**](./../SOLACE).
     * @param xslocker_ Address of [**xsLocker**](./../staking/xsLocker).
     */
    constructor(address solace_, address xslocker_) {
        require(solace_ != address(0x0), "zero address solace");
        require(xslocker_ != address(0x0), "zero address xslocker");
        solace = solace_;
        xslocker = xslocker_;
        IERC20(solace_).approve(xslocker_, type(uint256).max);
    }

    /**
     * @notice Deposit [**SOLACE**](./../../SOLACE) to increase the value of multiple existing locks.
     * @dev [**SOLACE**](./../../SOLACE) is transferred from msg.sender, assumes its already approved.
     * @param xsLockIDs Array of lock IDs to update.
     * @param amounts Array of [**SOLACE**](./../../SOLACE) amounts to deposit.
     */
    function increaseAmountMultiple(uint256[] calldata xsLockIDs, uint256[] calldata amounts) external override nonReentrant {
        require (xsLockIDs.length == amounts.length, "array length mismatch");

        // xsLocker.increaseAmount calls transferFrom with `from` = msg.sender
        // Within context of increaseAmountMultiple() call to xsLocker.increaseAmount
        // msg.sender = xsLockerExtension.sol contract
        // So need to first transfer SOLACE from caller to this contract.
        uint256 totalAmount = 0;
        uint256 refundAmount = 0;

        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        SafeERC20.safeTransferFrom(IERC20(solace), msg.sender, address(this), totalAmount);

        for (uint256 i = 0; i < xsLockIDs.length; i++) {
            // Guard against revert for non-existing lockIDs
            if ( IxsLocker(xslocker).exists(xsLockIDs[i]) ) {
                IxsLocker(xslocker).increaseAmount(xsLockIDs[i], amounts[i]);
                emit SolaceDistributed(xsLockIDs[i], amounts[i]);
            } else {
                refundAmount += amounts[i];
                emit SolaceNotDistributed(xsLockIDs[i], amounts[i]);
            }
        }

        SafeERC20.safeTransfer(IERC20(solace), msg.sender, refundAmount);
        emit SolaceRefunded(refundAmount);
    }
}
