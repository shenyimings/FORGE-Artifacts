// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {IWrappedERC20, IERC1155InventoryBurnable, QUIDDVouchersRedeemer} from "../../../token/ERC1155/QUIDDVouchersRedeemer.sol";

contract QUIDDVouchersRedeemerMock is QUIDDVouchersRedeemer {
    constructor(
        IERC1155InventoryBurnable vouchersContract,
        IWrappedERC20 tokenContract,
        address tokenHolder
    ) QUIDDVouchersRedeemer(vouchersContract, tokenContract, tokenHolder) {}

    function voucherValue(uint256 tokenId) external pure returns (uint256) {
        return _voucherValue(tokenId);
    }
}
