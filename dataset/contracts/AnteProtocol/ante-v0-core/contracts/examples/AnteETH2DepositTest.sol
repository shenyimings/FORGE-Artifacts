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

/// @title ETH2 beacon contract doesn't lose 99.99% of its ETH test
/// @notice Ante Test to check that ETH2 beacon depositcontract.eth doesn't lose 99.99% of
/// its ETH (as of May 2021)
contract AnteETH2DepositTest is AnteTest("ETH2 beacon deposit contract doesn't lose 99.99% of its ETH") {
    // depositcontract.eth, verified on https://ethereum.org/en/eth2/deposit-contract/
    // https://etherscan.io/address/0x00000000219ab540356cBB839Cbe05303d7705Fa
    address public immutable depositContractAddr;

    // As of 20210524 with 4.88m ETH deposited, 500 ETH represents a ~ -99.99% drop
    uint256 public constant THRESHOLD_BALANCE = 500 * 1e18; //500 ETH

    /// @param _depositContractAddr ETH2 deposit address (0x00000000219ab540356cBB839Cbe05303d7705Fa on mainnet)
    constructor(address _depositContractAddr) {
        protocolName = "ETH2";
        depositContractAddr = _depositContractAddr;
        testedContracts = [_depositContractAddr];
    }

    /// @notice test to check balance of eth2 deposit address
    /// @return true if deposit address balance is over 500 ETH
    function checkTestPasses() external view override returns (bool) {
        return (depositContractAddr.balance >= THRESHOLD_BALANCE);
    }
}
