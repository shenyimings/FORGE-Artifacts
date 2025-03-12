// SPDX-License-Identifier: MIT
pragma solidity >=0.7.2;
pragma experimental ABIEncoderV2;

struct Order {
    address makerAddress; // Address that created the order.
    address takerAddress; // Address that is allowed to fill the order. If set to 0, any address is allowed to fill the order.
    address feeRecipientAddress; // Address that will recieve fees when order is filled.
    address senderAddress; // Address that is allowed to call Exchange contract methods that affect this order. If set to 0, any address is allowed to call these methods.
    uint256 makerAssetAmount; // Amount of makerAsset being offered by maker. Must be greater than 0.
    uint256 takerAssetAmount; // Amount of takerAsset being bid on by maker. Must be greater than 0.
    uint256 makerFee; // Fee paid to feeRecipient by maker when order is filled.
    uint256 takerFee; // Fee paid to feeRecipient by taker when order is filled.
    uint256 expirationTimeSeconds; // Timestamp in seconds at which order expires.
    uint256 salt; // Arbitrary number to facilitate uniqueness of the order's hash.
    bytes makerAssetData; // Encoded data that can be decoded by a specified proxy contract when transferring makerAsset. The leading bytes4 references the id of the asset proxy.
    bytes takerAssetData; // Encoded data that can be decoded by a specified proxy contract when transferring takerAsset. The leading bytes4 references the id of the asset proxy.
    bytes makerFeeAssetData; // Encoded data that can be decoded by a specified proxy contract when transferring makerFeeAsset. The leading bytes4 references the id of the asset proxy.
    bytes takerFeeAssetData; // Encoded data that can be decoded by a specified proxy contract when transferring takerFeeAsset. The leading bytes4 references the id of the asset proxy.
}

struct FillResults {
    uint256 makerAssetFilledAmount; // Total amount of makerAsset(s) filled.
    uint256 takerAssetFilledAmount; // Total amount of takerAsset(s) filled.
    uint256 makerFeePaid; // Total amount of fees paid by maker(s) to feeRecipient(s).
    uint256 takerFeePaid; // Total amount of fees paid by taker to feeRecipients(s).
    uint256 protocolFeePaid; // Total amount of fees paid by taker to the staking contract.
}

interface IZeroExExchange {
    function fillOrKillOrder(
        Order calldata order,
        uint256 takerAssetFillAmount,
        bytes calldata signature
    ) external payable returns (FillResults memory fillResults);

    function fillOrder(
        Order calldata order,
        uint256 takerAssetFillAmount,
        bytes calldata signature
    ) external payable returns (FillResults memory fillResults);
}
