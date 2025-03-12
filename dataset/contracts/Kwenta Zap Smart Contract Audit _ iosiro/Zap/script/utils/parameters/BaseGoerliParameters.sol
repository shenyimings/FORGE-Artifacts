// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

contract BaseGoerliParameters {
    // https://goerli.basescan.org/token/0xf175520c52418dfe19c8098071a252da48cd1c19
    address public constant USDC = 0xF175520C52418dfE19C8098071a252da48Cd1C19;

    // https://usecannon.com/packages/synthetix-spot-market/3.3.5/84531-andromeda
    address public constant SPOT_MARKET_PROXY =
        0x26f3EcFa0Aa924649cfd4b74C57637e910A983a4;

    // https://usecannon.com/packages/synthetix/3.3.5/84531-andromeda
    address public constant USD_PROXY =
        0xa89163A087fe38022690C313b5D4BBF12574637f;

    // https://usecannon.com/packages/synthetix-spot-market/3.3.5/84531-andromeda
    uint128 public constant SUSDC_SPOT_MARKET_ID = 1;
}
