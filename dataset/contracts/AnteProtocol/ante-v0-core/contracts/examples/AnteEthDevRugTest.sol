// SPDX-License-Identifier: GPL-3.0-only

// ┏━━━┓━━━━━┏┓━━━━━━━━━┏━━━┓━━━━━━━━━━━━━━━━━━━━━━━
// ┃┏━┓┃━━━━┏┛┗┓━━━━━━━━┃┏━━┛━━━━━━━━━━━━━━━━━━━━━━━
// ┃┗━┛┃┏━┓━┗┓┏┛┏━━┓━━━━┃┗━━┓┏┓┏━┓━┏━━┓━┏━┓━┏━━┓┏━━┓
// ┃┏━┓┃┃┏┓┓━┃┃━┃┏┓┃━━━━┃┏━━┛┣┫┃┏┓┓┗━┓┃━┃┏┓┓┃┏━┛┃┏┓┃
// ┃┃ ┃┃┃┃┃┃━┃┗┓┃┃━┫━┏┓━┃┃━━━┃┃┃┃┃┃┃┗┛┗┓┃┃┃┃┃┗━┓┃┃━┫
// ┗┛ ┗┛┗┛┗┛━┗━┛┗━━┛━┗┛━┗┛━━━┗┛┗┛┗┛┗━━━┛┗┛┗┛┗━━┛┗━━┛
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

pragma solidity ^0.7.0;

import "../AnteTest.sol";

/// @title ETHDev multisig doesn't rug test
/// @notice Ante Test to check if EthDev multisig "rugs" 99% of its ETH (as of May 2021)
contract AnteEthDevRugTest is AnteTest("EthDev MultiSig Doesnt Rug 99% of its ETH Test") {
    // https://etherscan.io/address/0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae
    address public immutable ethDevAddr;

    // 2021-05-24: EthDev has 394k ETH, so -99% is ~4k ETH
    uint256 public constant RUG_THRESHOLD = 4 * 1000 * 1e18;

    /// @param _ethDevAddr eth multisig address (0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae on mainnet)
    constructor(address _ethDevAddr) {
        protocolName = "ETH";
        ethDevAddr = _ethDevAddr;
        testedContracts = [_ethDevAddr];
    }

    /// @notice test to check balance of eth multisig
    /// @return true if eth multisig has over 4000 ETH
    function checkTestPasses() external view override returns (bool) {
        return ethDevAddr.balance >= RUG_THRESHOLD;
    }
}
