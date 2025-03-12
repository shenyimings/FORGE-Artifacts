pragma solidity ^0.8.0;

import "../../interfaces/IShared.sol";
import "../../interfaces/IStakeManager.sol";

contract StakeManagerEchidna is IShared {
    IStakeManager public sm;

    // Expose StakeManager functions to Echidna - making them virtual to override them in tests when needed

    function setFlip(IFLIP flip) external virtual {
        sm.setFlip(flip);
    }

    function stake(bytes32 nodeID, uint256 amount, address returnAddr) external virtual {
        sm.getFLIP().approve(address(sm), amount);
        sm.stake(nodeID, amount, returnAddr);
    }

    function registerClaim(
        SigData calldata sigData,
        bytes32 nodeID,
        uint256 amount,
        address staker,
        uint48 expiryTime
    ) external virtual {
        sm.registerClaim(sigData, nodeID, amount, staker, expiryTime);
    }

    function executeClaim(bytes32 nodeID) external virtual {
        sm.executeClaim(nodeID);
    }

    function setMinStake(uint256 newMinStake) external virtual {
        sm.setMinStake(newMinStake);
    }

    function govWithdraw() external virtual {
        sm.govWithdraw();
    }

    function govWithdrawNative() external virtual {
        sm.govWithdrawNative();
    }

    // Expose AggKeyNonceConsumer functions to Echidna

    function updateKeyManagerStakeManager(SigData calldata sigData, IKeyManager keyManager) external virtual {
        sm.updateKeyManager(sigData, keyManager);
    }

    // Expose GovernanceCommunityGuarded functions to Echidna

    function enableCommunityGuardStakeManager() external virtual {
        sm.enableCommunityGuard();
    }

    function disableCommunityGuardStakeManager() external virtual {
        sm.disableCommunityGuard();
    }

    function suspendStakeManager() external virtual {
        sm.suspend();
    }

    function resumeStakeManager() external virtual {
        sm.resume();
    }
}
