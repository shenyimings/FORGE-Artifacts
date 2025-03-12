// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/IGauge.sol";
import "../interfaces/IVotingEscrow.sol";

/**
 * @dev A utility contract that helps to claims from multiple liquidity gauges.
 */
contract Claimer {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IVotingEscrow public votingEscrow;
    IERC20Upgradeable public reward;

    constructor(address _votingEscrow, address _reward) {
        votingEscrow = IVotingEscrow(_votingEscrow);
        reward = IERC20Upgradeable(_reward);

        reward.safeApprove(_votingEscrow, uint256(int256(-1)));
    }

    /**
     * @dev Updates voting power in multiple gauges.
     * kick works only when there is a new voting event since last checkpoint.
     */
    function kick(address[] memory _gauges) public {
        for (uint256 i = 0; i < _gauges.length; i++) {
            IGauge(_gauges[i]).kick(msg.sender);
        }
    }

    /**
     * @dev Returns the sum of claimable AC from multiple gauges.
     */
    function claimable(address _account, address[] memory _gauges) external view returns (uint256) {
        uint256 _total = 0;
        for (uint256 i = 0; i < _gauges.length; i++) {
            _total = _total.add(IGauge(_gauges[i]).claimable(_account));
        }

        return _total;
    }

    /**
     * @dev Claims the AC and then locks in voting escrow.
     * Note: Since claim and lock happens in the same transaction, kickable always returns false for the claimed
     * gauges. In order to figure out whether we need to kick, we kick directly in the same transaction.
     * @param _gaugesToClaim The list of gauges to claim.
     * @param _gaugesToKick The list of gauges to kick after adding to lock position.
     */
    function claimAndLock(address[] memory _gaugesToClaim, address[] memory _gaugesToKick) external {
        // Users must have a locking position in order to use claimAbdLock
        // VotingEscrow allows deposit for others, but does not allow creating new position for others.
        require(votingEscrow.balanceOf(msg.sender) > 0, "no lock");

        for (uint256 i = 0; i < _gaugesToClaim.length; i++) {
            IGauge(_gaugesToClaim[i]).claim(msg.sender, address(this), false);
        }

        uint256 _reward = reward.balanceOf(address(this));
        votingEscrow.deposit_for(msg.sender, _reward);

        // Kick after lock
        kick(_gaugesToKick);
    }
}