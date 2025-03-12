// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IDCAFor {
    function depositFor(
        address sender,
        uint256 amount,
        uint8 amountSplit
    ) external;

    function withdrawAllFor(
        address sender,
        bool convertBluechipIntoDepositAsset
    ) external;

    function withdrawAllFor(
        address sender,
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    ) external;

    function withdrawBluechipFor(
        address sender,
        bool convertBluechipIntoDepositAsset
    ) external;

    function withdrawBluechipFor(
        address sender,
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    ) external;
}
