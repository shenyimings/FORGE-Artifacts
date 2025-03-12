// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {EDuCoin} from "./EDuCoin.sol";

contract EDuCoinMock is EDuCoin {
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        address[] memory recipients,
        uint256[] memory amounts,
        IForwarderRegistry forwarderRegistry
    ) EDuCoin(tokenName, tokenSymbol, tokenDecimals, recipients, amounts, forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
