// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { BaseBridgeableToken } from "src/tokens/base/BaseBridgeableToken.sol";

contract LZBridgeReceiver is Ownable {
  address public immutable lzEndpoint;
  BaseBridgeableToken public token;
  mapping(uint16 => bytes) public trustedRemoteLookup;
  mapping(uint16 => mapping(bytes => mapping(uint64 => bytes32)))
    public failedMessages;

  event MessageFailed(
    uint16 _srcChainId,
    bytes _srcAddress,
    uint64 _nonce,
    bytes _payload
  );
  event SetTrustedRemote(uint16[] _srcChainId, bytes[] _srcAddress);

  error LZBridgeReceiver_BadLength();
  error LZBridgeReceiver_InvalidEndpointCaller();
  error LZBridgeReceiver_InvalidSource();
  error LZBridgeReceiver_CallerMustBeSelf();
  error LZBridgeReceiver_NoStoredMessage();
  error LZBridgeReceiver_InvalidPayload();

  constructor(address _endpoint, address token_) {
    lzEndpoint = _endpoint;
    token = BaseBridgeableToken(token_);
  }

  function setTrustedRemotes(
    uint16[] calldata srcChainIds,
    bytes[] calldata remoteAddresses
  ) external onlyOwner {
    if (srcChainIds.length != remoteAddresses.length)
      revert LZBridgeReceiver_BadLength();
    for (uint256 i = 0; i < srcChainIds.length; ) {
      trustedRemoteLookup[srcChainIds[i]] = remoteAddresses[i];

      unchecked {
        i++;
      }
    }

    emit SetTrustedRemote(srcChainIds, remoteAddresses);
  }

  function lzReceive(
    uint16 _srcChainId,
    bytes memory _srcAddress,
    uint64 _nonce,
    bytes calldata _payload
  ) external {
    // lzReceive must be called by the endpoint for security
    if (_msgSender() != address(lzEndpoint))
      revert LZBridgeReceiver_InvalidEndpointCaller();

    bytes memory trustedRemote = trustedRemoteLookup[_srcChainId];
    // if will still block the message pathway from (srcChainId, srcAddress). should not receive message from untrusted remote.
    if (
      _srcAddress.length != trustedRemote.length ||
      keccak256(_srcAddress) != keccak256(trustedRemote)
    ) revert LZBridgeReceiver_InvalidSource();

    try this.nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload) {
      // do nothing
    } catch {
      // error / exception
      failedMessages[_srcChainId][_srcAddress][_nonce] = keccak256(_payload);
      emit MessageFailed(_srcChainId, _srcAddress, _nonce, _payload);
    }
  }

  function nonblockingLzReceive(
    uint16 _srcChainId,
    bytes memory _srcAddress,
    uint64 _nonce,
    bytes memory _payload
  ) public {
    // only internal transaction
    if (_msgSender() != address(this))
      revert LZBridgeReceiver_CallerMustBeSelf();
    _nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
  }

  function _nonblockingLzReceive(
    uint16,
    bytes memory,
    uint64,
    bytes memory _payload
  ) internal {
    (address tokenRecipient, uint256 amount) = abi.decode(
      _payload,
      (address, uint256)
    );

    token.bridgeMint(tokenRecipient, amount);
  }

  function retryMessage(
    uint16 _srcChainId,
    bytes memory _srcAddress,
    uint64 _nonce,
    bytes memory _payload
  ) external payable onlyOwner {
    // assert there is message to retry
    bytes32 payloadHash = failedMessages[_srcChainId][_srcAddress][_nonce];
    if (payloadHash == bytes32(0)) revert LZBridgeReceiver_NoStoredMessage();
    if (keccak256(_payload) != payloadHash)
      revert LZBridgeReceiver_InvalidPayload();

    // clear the stored message
    failedMessages[_srcChainId][_srcAddress][_nonce] = bytes32(0);
    // execute the message. revert if it fails again
    _nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
  }
}
