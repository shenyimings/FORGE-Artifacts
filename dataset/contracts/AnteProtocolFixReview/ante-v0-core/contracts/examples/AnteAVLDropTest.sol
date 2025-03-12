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

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../AnteTest.sol";

// Ante Test to check if AVL in Ante-created tests drops by 99%
contract AnteAVLDropTest is AnteTest("Ante Doesnt Lose 99% of its AVL") {
    using SafeMath for uint256;

    uint256 public totalAVL;
    uint256 public avlThreshold;

    // Array of contract addresses to test should be passed in when creating
    constructor(address[] memory _testedContracts) {
        protocolName = "Ante Finance";
        testedContracts = _testedContracts;

        // Loop over address array and sum up total AVL
        for (uint256 i = 0; i < testedContracts.length; i++) {
            totalAVL = totalAVL.add(testedContracts[i].balance);
        }

        // Calculate test failure threshold using 99% drop in total AVL
        avlThreshold = totalAVL.div(100);
    }

    function checkTestPasses() public view override returns (bool) {
        uint256 currentAVL;

        // Sum up current AVL across tested contracts
        // TODO: to exclude failed tests or no?
        for (uint256 i = 0; i < testedContracts.length; i++) {
            currentAVL = currentAVL.add(testedContracts[i].balance);
        }

        // Check current AVL against test failure threshold
        return currentAVL >= avlThreshold;
    }
}
