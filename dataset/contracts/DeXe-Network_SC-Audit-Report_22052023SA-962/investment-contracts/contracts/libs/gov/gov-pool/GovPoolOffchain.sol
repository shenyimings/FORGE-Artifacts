// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../../../interfaces/gov/IGovPool.sol";

import "./GovPoolCommission.sol";

import "../../../gov/GovPool.sol";

library GovPoolOffchain {
    using ECDSA for bytes32;
    using GovPoolCommission for address;

    event OffchainResultsSaved(string resultsHash, address sender);

    function saveOffchainResults(
        IGovPool.OffChain storage offChain,
        string calldata resultsHash,
        bytes calldata signature
    ) external {
        bytes32 signHash_ = getSignHash(resultsHash, msg.sender);

        require(!offChain.usedHashes[signHash_], "Gov: already used");
        require(
            signHash_.toEthSignedMessageHash().recover(signature) == offChain.verifier,
            "Gov: invalid signer"
        );

        offChain.resultsHash = resultsHash;
        offChain.usedHashes[signHash_] = true;

        _payCommission();

        emit OffchainResultsSaved(resultsHash, msg.sender);
    }

    function getSignHash(string calldata resultsHash, address user) public view returns (bytes32) {
        return keccak256(abi.encodePacked(resultsHash, user, block.chainid, address(this)));
    }

    function _payCommission() internal {
        (address settingsAddress, , , , ) = GovPool(payable(address(this))).getHelperContracts();

        IGovSettings.ProposalSettings memory internalSettings = IGovSettings(settingsAddress)
            .getInternalSettings();

        internalSettings.rewardsInfo.rewardToken.payCommission(
            internalSettings.rewardsInfo.executionReward
        );
    }
}
