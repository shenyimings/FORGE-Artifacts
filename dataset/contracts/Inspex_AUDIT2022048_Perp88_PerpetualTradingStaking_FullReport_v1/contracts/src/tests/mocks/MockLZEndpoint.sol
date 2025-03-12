// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { ILZReceiver } from "src/interfaces/ILZReceiver.sol";

contract MockLZEndpoint {
  uint16 private srcChainId;
  bytes private srcAddress;
  uint64 public nonce = 1;

  function setSource(uint16 chainId_, bytes calldata srcAddress_) external {
    srcChainId = chainId_;
    srcAddress = srcAddress_;
  }

  function send(
    uint16,
    bytes calldata _destination,
    bytes calldata _payload,
    address payable,
    address,
    bytes calldata
  ) external payable {
    address destinationAddress = abi.decode(_destination, (address));
    ILZReceiver(destinationAddress).lzReceive(
      srcChainId,
      srcAddress,
      nonce,
      _payload
    );

    nonce++;
  }
}
