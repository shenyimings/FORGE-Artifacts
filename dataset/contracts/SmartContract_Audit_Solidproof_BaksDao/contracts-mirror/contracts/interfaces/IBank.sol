// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import {IERC20} from "./ERC20.sol";

interface IBank {
    function nextVoiceMintingStage() external returns (uint256);

    function onNewDeposit(IERC20 token, uint256 amount) external;
}
