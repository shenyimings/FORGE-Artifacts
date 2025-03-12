pragma solidity ^0.8.0;

import "../../interfaces/IShared.sol";
import "../../interfaces/IKeyManager.sol";

contract KeyManagerEchidna is IShared {
    IKeyManager public km;

    // Expose KeyManager functions to Echidna - making them virtual to override them in tests when needed

    function setCanConsumeKeyNonce(address[] calldata addrs) external virtual {
        km.setCanConsumeKeyNonce(addrs);
    }

    function updateCanConsumeKeyNonce(
        SigData calldata sigData,
        address[] calldata currentAddrs,
        address[] calldata newAddrs
    ) external virtual {
        km.updateCanConsumeKeyNonce(sigData, currentAddrs, newAddrs);
    }

    function consumeKeyNonce(SigData calldata sigData, bytes32 contractMsgHash) external virtual {
        km.consumeKeyNonce(sigData, contractMsgHash);
    }

    function setAggKeyWithAggKey(SigData calldata sigData, Key calldata newAggKey) external virtual {
        km.setAggKeyWithAggKey(sigData, newAggKey);
    }

    function setGovKeyWithAggKey(SigData calldata sigData, address newGovKey) external virtual {
        km.setGovKeyWithAggKey(sigData, newGovKey);
    }

    function setGovKeyWithGovKey(address newGovKey) external virtual {
        km.setGovKeyWithGovKey(newGovKey);
    }

    function setCommKeyWithAggKey(SigData calldata sigData, address newCommKey) external virtual {
        km.setCommKeyWithAggKey(sigData, newCommKey);
    }

    function setCommKeyWithCommKey(address newCommKey) external virtual {
        km.setCommKeyWithCommKey(newCommKey);
    }

    function govAction(bytes32 message) external virtual {
        km.govAction(message);
    }
}
