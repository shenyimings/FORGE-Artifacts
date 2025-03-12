// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.13;

import "openzeppelin-contracts/contracts/security/Pausable.sol";

import "./interfaces/IKeeper3r.sol";
import "./external/interfaces/IKeep3r.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IHarvestingJob.sol";
import "./interfaces/IFRPHarvester.sol";

/// @title Phuture job
/// @notice Contains harvesting execution logic through keeper network
contract PhutureJob is IKeeper3r, IHarvestingJob, Pausable, Ownable {
    /// @inheritdoc IKeeper3r
    address public immutable override keep3r;

    /// @notice Pays keeper for work
    modifier payKeeper(address _keeper) {
        require(IKeep3r(keep3r).isKeeper(_keeper), "PhutureJob: !KEEP3R");
        _;
        IKeep3r(keep3r).worked(_keeper);
    }

    constructor(address _keep3r) {
        keep3r = _keep3r;
        _pause();
    }

    /// @inheritdoc IHarvestingJob
    function pause() external override onlyOwner {
        _pause();
    }

    /// @inheritdoc IHarvestingJob
    function unpause() external override onlyOwner {
        _unpause();
    }

    /// @inheritdoc IHarvestingJob
    function harvest(uint _maxDepositedAmount, IFRPHarvester _vault)
        external
        override
        whenNotPaused
        payKeeper(msg.sender)
    {
        _vault.harvest(_maxDepositedAmount);
    }
}
