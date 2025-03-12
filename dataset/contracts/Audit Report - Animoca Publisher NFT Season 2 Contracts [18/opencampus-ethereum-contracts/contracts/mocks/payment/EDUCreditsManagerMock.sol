// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {EDUCreditsManager} from "./../../payment/EDUCreditsManager.sol";

contract EDUCreditsManagerMock is EDUCreditsManager {
    constructor(
        IERC20 eduToken,
        address payable payoutWallet,
        address unclaimedEDUHolder,
        IForwarderRegistry forwarderRegistry
    ) EDUCreditsManager(eduToken, payoutWallet, unclaimedEDUHolder, forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
