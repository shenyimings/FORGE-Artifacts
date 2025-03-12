// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

interface IDCA {
    function deposit(uint256 amount, uint8 amountSplit) external;

    function withdrawAll(bool convertBluechipIntoDepositAsset) external;

    function withdrawAll(
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    ) external;

    function withdrawBluechip(bool convertBluechipIntoDepositAsset) external;

    function withdrawBluechip(
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    ) external;

    function depositToken() external view returns (IERC20Upgradeable);
}
