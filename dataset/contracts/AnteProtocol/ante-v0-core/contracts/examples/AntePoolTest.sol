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

import "../AntePool.sol";
import "../AnteTest.sol";

// Ante Test to check if Ante pol contract state matches eth balance
contract AntePoolTest is AnteTest("Ante Pool contract state matches eth balance") {
    constructor() {
        // NB: this points to ante pools deployed on rinkeby, will need to change for mainnet deploy
        testedContracts = [
            0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512,
            0x5FC8d32690cc91D4c39d9d3abcBD16989F875707,
            0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6
        ];
        protocolName = "Ante";
    }

    function checkTestPasses() public view override returns (bool) {
        for (uint256 i = 0; i < testedContracts.length; i++) {
            AntePool antePool = AntePool(testedContracts[i]);
            // totalPaidOut should be 0 before test fails
            if (
                testedContracts[i].balance <
                (antePool.getTotalChallengerStaked() +
                    antePool.getTotalStaked() +
                    antePool.getTotalPendingWithdraw() -
                    antePool.totalPaidOut())
            ) {
                return false;
            }
        }
        return true;
    }
}
