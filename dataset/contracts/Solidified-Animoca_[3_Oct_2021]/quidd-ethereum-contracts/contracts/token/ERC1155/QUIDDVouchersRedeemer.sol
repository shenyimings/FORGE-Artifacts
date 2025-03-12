// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

// solhint-disable-next-line max-line-length
import {IWrappedERC20, IERC1155InventoryBurnable, TokenLaunchpadVouchersRedeemer} from "@animoca/tokenlaunchpad-ethereum-contracts-1.0.0/contracts/token/ERC1155/TokenLaunchpadVouchersRedeemer.sol";

/**
 * @title QUIDDVouchersRedeemer
 * A TokenLaunchpadVouchersRedeemer contract for QUIDD vouchers.
 */
contract QUIDDVouchersRedeemer is TokenLaunchpadVouchersRedeemer {
    /**
     * Constructor.
     * @param vouchersContract the address of the vouchers contract.
     * @param tokenContract the address of the ERC20 token contract.
     * @param tokenHolder the address of the ERC20 token holder.
     */
    constructor(
        IERC1155InventoryBurnable vouchersContract,
        IWrappedERC20 tokenContract,
        address tokenHolder
    ) TokenLaunchpadVouchersRedeemer(vouchersContract, tokenContract, tokenHolder) {}

    // todo change based on metadata
    /**
     * Validates the validity of the QUIDD voucher and returns its value.
     * @dev Reverts if the voucher is not a valid QUIDD voucher.
     * @param tokenId the id of the QUIDD voucher.
     * @return the value of the voucher in QUIDD ERC20 token.
     */
    function _voucherValue(uint256 tokenId) internal pure virtual override returns (uint256) {
        return tokenId;
    }
}
