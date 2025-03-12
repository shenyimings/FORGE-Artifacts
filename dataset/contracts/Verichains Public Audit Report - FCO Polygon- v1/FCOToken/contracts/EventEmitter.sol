// SPDX-License-Identifier: none
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControl } from "./AccessControl.sol";

interface IEventEmitter {
	function emitEvent(bytes32 action, bytes memory data) external;	
}

abstract contract EventEmitter is Initializable {
	IEventEmitter public eventEmitter;

	function __EventEmitter_init(address _eventEmitter) internal onlyInitializing {
        eventEmitter = IEventEmitter(_eventEmitter);
	}
			
	function emitEvent(bytes32 action, bytes memory data) internal virtual {
		eventEmitter.emitEvent(action, data);
	}	
}

contract EventEmitterHub is IEventEmitter, AccessControl {		
	mapping (address => bool) public emitters;

	function initialize(address authority) public virtual initializer {
        __AccessControl_init(authority);
	}
    
	function setEmitter(address emitter, bool state) public onlyAdmin {	
		require(emitters[emitter] != state, "Already set");	
		emitters[emitter] = state;
        emit EmitterSet(emitter, state);
	}

	function emitEvent(bytes32 action, bytes memory data) public onlyEmitter {
		emit Event(action, data, block.timestamp, tx.origin);
	}
		
	modifier onlyEmitter() {
        require(emitters[msg.sender], "Not allowed");
        _;
    }
	
	event EmitterSet(address emitter, bool state);	
    event Event(bytes32 action, bytes data, uint256 timestamp, address origin);		

	uint256[50] private __gap;
}
