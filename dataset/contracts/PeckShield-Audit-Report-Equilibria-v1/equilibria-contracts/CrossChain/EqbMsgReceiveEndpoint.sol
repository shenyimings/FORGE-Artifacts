// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../Interfaces/IEqbMsgReceiver.sol";
import "../Interfaces/LayerZero/ILayerZeroEndpoint.sol";
import "../Interfaces/LayerZero/ILayerZeroReceiver.sol";
import "../Dependencies/Errors.sol";
import "./LayerZeroHelper.sol";
import "./ExcessivelySafeCall.sol";

/**
 * @dev Initially, currently we will use layer zero's default send and receive version (which is most updated)
 * So we can leave the configuration unset.
 */
contract EqbMsgReceiveEndpoint is ILayerZeroReceiver, OwnableUpgradeable {
    using ExcessivelySafeCall for address;

    address public lzEndpoint;

    event Received(
        uint16 _srcChainId,
        bytes _path,
        uint64 _nonce,
        bytes _payload
    );

    event MessageFailed(
        uint16 _srcChainId,
        bytes _path,
        uint64 _nonce,
        bytes _payload,
        bytes _reason
    );

    modifier onlyLzEndpoint() {
        if (msg.sender != address(lzEndpoint)) {
            revert Errors.OnlyLayerZeroEndpoint();
        }
        _;
    }

    // by default we will use LZ's default version (most updated version). Hence, it's not necessary
    // to call setLzReceiveVersion
    function initialize(address _lzEndpoint) external initializer {
        __Ownable_init();

        lzEndpoint = _lzEndpoint;
    }

    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _path,
        uint64 _nonce,
        bytes calldata _payload
    ) external onlyLzEndpoint {
        (address receiver, address sender, bytes memory message) = abi.decode(
            _payload,
            (address, address, bytes)
        );

        (bool success, bytes memory reason) = address(receiver)
            .excessivelySafeCall(
                gasleft(),
                150,
                abi.encodeWithSelector(
                    IEqbMsgReceiver.executeMessage.selector,
                    LayerZeroHelper.getOriginalChainId(_srcChainId),
                    sender,
                    message
                )
            );

        if (!success) {

            emit MessageFailed(_srcChainId, _path, _nonce, _payload, reason);
        }

        emit Received(_srcChainId, _path, _nonce, _payload);
    }

    function setLzReceiveVersion(uint16 _newVersion) external onlyOwner {
        ILayerZeroEndpoint(lzEndpoint).setReceiveVersion(_newVersion);
    }
}
