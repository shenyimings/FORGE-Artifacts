// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {ITokenHub} from "../interfaces/ITokenHub.sol";

contract TokenHubMock is ITokenHub {
    uint256 public constant TEN_DECIMALS = 1e10;

    function transferOut(
        address contractAddr,
        address recipient,
        uint256 amount,
        uint64 expireTime
    ) external payable override returns (bool) {
        require(
            expireTime >= block.timestamp + 120,
            "expireTime must be two minutes later"
        );
        require(
            msg.value % TEN_DECIMALS == 0,
            "invalid received BNB amount: precision loss in amount conversion"
        );
        return true;
    }

    function relayFee() external pure override returns (uint256) {
        uint256 fee = 10000000000000000; // 0.01 BNB on testnet, 0.002 BNB on mainnet
        return fee;
    }
}
