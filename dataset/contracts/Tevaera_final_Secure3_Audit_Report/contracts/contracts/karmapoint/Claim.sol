// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import "../citizenid/CitizenIDV1.sol";
import "./KarmaPointV1.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title Airdrop claim contract for Citizen ID & Karma Points
/// @author Tevaera Labs
/// @notice Claims airdropped Citizen ID & Karma Points
/// @dev Uses CitizenID and KarmaPoint contracts for minting
contract Claim is Ownable, Pausable {
    CitizenIDV1 internal citizenIdContract;
    KarmaPointV1 internal kpContract;

    modifier isNotBlacklisted() {
        require(
            !citizenIdContract.blacklisted(msg.sender),
            "Tevan Blacklisted!"
        );
        _;
    }

    constructor(CitizenIDV1 _citizenIdContract, KarmaPointV1 _kpContract) {
        citizenIdContract = _citizenIdContract;
        kpContract = _kpContract;
    }

    /// @notice Users gets citizen id and karma points if eligible
    /// @dev Mints citizen id and karma poins
    function claim() external payable isNotBlacklisted whenNotPaused {
        if (citizenIdContract.balanceOf(msg.sender) == 0) {
            citizenIdContract.claim{value: msg.value}(msg.sender);
        }

        if (kpContract.toBeClaimedKP(msg.sender) > 0) {
            kpContract.claim(msg.sender);
        }
    }

    /// @dev Owner can pasue the claim
    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    /// @dev Owner can activate the claim
    function unpause() external onlyOwner whenPaused {
        _unpause();
    }
}
