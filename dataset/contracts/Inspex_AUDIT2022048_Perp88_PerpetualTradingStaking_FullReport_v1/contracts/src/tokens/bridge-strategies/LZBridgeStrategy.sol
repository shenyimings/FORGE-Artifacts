// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IBridgeStrategy } from "../../interfaces/IBridgeStrategy.sol";
import { ILayerZeroEndpoint } from "../../interfaces/ILayerZeroEndpoint.sol";

contract LZBridgeStrategy is IBridgeStrategy, Ownable {
  event SetDestinationTokenContracts(
    uint256[] destChainIds,
    address[] tokenContracts
  );
  event Execute(
    address caller,
    uint256 destinationChainId,
    address tokenRecipient,
    uint256 amount,
    bytes _payload
  );

  error LZBridgeStrategy_UnknownChainId();
  error LZBridgeStrategy_LengthMismatch();

  ILayerZeroEndpoint public immutable lzEndpoint;
  mapping(uint256 => address) destinationTokenContracts;

  constructor(address lzEndpoint_) {
    lzEndpoint = ILayerZeroEndpoint(lzEndpoint_);
  }

  function setDestinationTokenContracts(
    uint256[] calldata destChainIds,
    address[] calldata destContracts
  ) external onlyOwner {
    if (destChainIds.length != destContracts.length)
      revert LZBridgeStrategy_LengthMismatch();

    for (uint256 i = 0; i < destChainIds.length; ) {
      destinationTokenContracts[destChainIds[i]] = destContracts[i];
      unchecked {
        i++;
      }
    }
    emit SetDestinationTokenContracts(destChainIds, destContracts);
  }

  function execute(
    address caller,
    uint256 destinationChainId,
    address tokenRecipient,
    uint256 amount,
    bytes memory _payload
  ) external payable {
    address destinationTokenContract = destinationTokenContracts[
      destinationChainId
    ];
    if (destinationTokenContract == address(0))
      revert LZBridgeStrategy_UnknownChainId();

    bytes memory payload = abi.encode(tokenRecipient, amount);

    lzEndpoint.send{ value: msg.value }(
      uint16(destinationChainId),
      abi.encode(destinationTokenContract),
      payload,
      payable(caller),
      address(0),
      abi.encode(0)
    );

    emit Execute(caller, destinationChainId, tokenRecipient, amount, _payload);
  }
}
