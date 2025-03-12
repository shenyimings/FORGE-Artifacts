pragma solidity ^0.8.0;

import "../../interfaces/IShared.sol";
import "../../interfaces/IFLIP.sol";

contract FLIPEchidna is IShared {
    IFLIP public f;

    // Expose FLIP functions to Echidna  - making them virtual to override them in tests when needed

    function updateFlipSupply(
        SigData calldata sigData,
        uint256 newTotalSupply,
        uint256 stateChainBlockNumber,
        address staker
    ) external virtual {
        f.updateFlipSupply(sigData, newTotalSupply, stateChainBlockNumber, staker);
    }

    // Expose AggKeyNonceConsumer functions to Echidna

    function updateKeyManagerFLIP(SigData calldata sigData, IKeyManager keyManager) external virtual {
        f.updateKeyManager(sigData, keyManager);
    }
}
