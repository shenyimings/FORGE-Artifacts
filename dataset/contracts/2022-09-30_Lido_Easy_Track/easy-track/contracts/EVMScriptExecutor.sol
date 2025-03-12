// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/utils/StorageSlot.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/utils/Address.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/access/Ownable.sol";

interface ICallsScript {
    function execScript(
        bytes memory _script,
        bytes memory,
        address[] memory _blacklist
    ) external returns (bytes memory);
}

/// @author psirex
/// @notice Contains method to execute EVMScripts
/// @dev EVMScripts use format of Aragon's https://github.com/aragon/aragonOS/blob/v4.0.0/contracts/evmscript/executors/CallsScript.sol executor
contract EVMScriptExecutor is Ownable {
    // -------------
    // EVENTS
    // -------------
    event ScriptExecuted(address indexed _caller, bytes _evmScript);
    event EasyTrackChanged(address indexed _previousEasyTrack, address indexed _newEasyTrack);

    // -------------
    // ERRORS
    // -------------
    string private constant ERROR_CALLER_IS_FORBIDDEN = "CALLER_IS_FORBIDDEN";
    string private constant ERROR_EASY_TRACK_IS_NOT_CONTRACT = "EASY_TRACK_IS_NOT_CONTRACT";
    string private constant ERROR_CALLS_SCRIPT_IS_NOT_CONTRACT = "CALLS_SCRIPT_IS_NOT_CONTRACT";

    // ------------
    // CONSTANTS
    // ------------

    // This variable required to use deployed CallsScript.sol contract because
    // CalssScript.sol makes check that caller contract is not petrified (https://hack.aragon.org/docs/common_Petrifiable)
    // Contains value: keccak256("aragonOS.initializable.initializationBlock")
    bytes32 internal constant INITIALIZATION_BLOCK_POSITION =
        0xebb05b386a8d34882b8711d156f463690983dc47815980fb82aeeff1aa43579e;

    // ------------
    // VARIABLES
    // ------------

    /// @notice Address of deployed CallsScript.sol contract
    address public immutable callsScript;

    /// @notice Address of depoyed easyTrack.sol contract
    address public easyTrack;

    // -------------
    // CONSTRUCTOR
    // -------------
    constructor(address _callsScript, address _easyTrack) {
        require(Address.isContract(_callsScript), ERROR_CALLS_SCRIPT_IS_NOT_CONTRACT);
        callsScript = _callsScript;
        _setEasyTrack(_easyTrack);
        StorageSlot.getUint256Slot(INITIALIZATION_BLOCK_POSITION).value = block.number;
    }

    // -------------
    // EXTERNAL METHODS
    // -------------

    /// @notice Executes EVMScript
    /// @dev Uses deployed Aragon's CallsScript.sol contract to execute EVMScript.
    /// @return Empty bytes
    function executeEVMScript(bytes memory _evmScript) external returns (bytes memory) {
        require(msg.sender == easyTrack, ERROR_CALLER_IS_FORBIDDEN);

        bytes memory execScriptCallData =
            abi.encodeWithSelector(
                ICallsScript.execScript.selector,
                _evmScript,
                new bytes(0),
                new address[](0)
            );
        (bool success, bytes memory output) = callsScript.delegatecall(execScriptCallData);
        if (!success) {
            assembly {
                let ptr := mload(0x40)
                let size := returndatasize()
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }
        emit ScriptExecuted(msg.sender, _evmScript);
        return abi.decode(output, (bytes));
    }

    function setEasyTrack(address _easyTrack) external onlyOwner {
        _setEasyTrack(_easyTrack);
    }

    function _setEasyTrack(address _easyTrack) internal {
        require(Address.isContract(_easyTrack), ERROR_EASY_TRACK_IS_NOT_CONTRACT);
        address oldEasyTrack = easyTrack;
        easyTrack = _easyTrack;
        emit EasyTrackChanged(oldEasyTrack, _easyTrack);
    }
}
