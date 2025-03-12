// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

library Errors {
    string public constant INITIALIZED = "Already initialized";
    string public constant NOT_ACTIVE = "SmockFacet: Not active";
    string public constant ACTIVE = "SmockFacet: Active";
}

struct SmockState {
    bool initialized;
    bool isActive;
    address operator;
    mapping(address => bool) callers;
    string message;
    uint256 lastMessageBlock;
}
// This is not how it has to be done in reality
// We can just extend the original
struct SmockState2 {
    bool initialized;
    bool isActive;
    address operator;
    mapping(address => bool) callers;
    string message;
    uint256 lastMessageBlock;
    bool extended;
}

library SmockStorage {
    event Call(address indexed caller);

    bytes32 public constant SMOCK_STORAGE_POSITION = keccak256("kresko.smock.storage");

    function initialize(address _operator) internal {
        SmockState storage ss = state();
        require(!ss.initialized, Errors.INITIALIZED);
        ss.initialized = true;
        ss.operator = _operator;
        emit Call(msg.sender);
    }

    function state() internal pure returns (SmockState storage ss) {
        bytes32 position = SMOCK_STORAGE_POSITION;
        assembly {
            ss.slot := position
        }
    }

    // This is not how it has to be done in reality
    function stateExtended() internal pure returns (SmockState2 storage ss) {
        bytes32 position = SMOCK_STORAGE_POSITION;
        assembly {
            ss.slot := position
        }
    }

    function activate() internal {
        state().isActive = true;
        state().callers[msg.sender] = true;
        emit Call(msg.sender);
    }

    function disable() internal {
        state().isActive = false;
        state().callers[msg.sender] = true;
        emit Call(msg.sender);
    }
}
