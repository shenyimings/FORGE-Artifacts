// SPDX-License-Identifier: MIT
// Copyright (C) 2021-2022 Autonomous Worlds Ltd

pragma solidity ^0.8.4;

import "./INftMetadata.sol";
import "./IXayaPolicy.sol";
import "./Utf8.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Implementation of the validation and fee policy that we use.
 *
 * Namespaces must be non-empty and consist only of lower-case letters a-z.
 * Names must be valid UTF-8 not including codepoints below 0x20.
 * Name + namespace must be shorter than 256 bytes, in UTF-8 encoded form.
 *
 * Move data must contain only ASCII characters between 0x20 and 0x7E,
 * i.e. the printable set, but no JSON validation is performed.
 *
 * There is a configurable flat fee for registrations, and no fee
 * for moves.
 *
 * This contract has an owner, who is able to modify the fee receiver
 * address and the registration fee (with a time lock).
 */
contract XayaPolicy is Ownable, IXayaPolicy
{

  /* ************************************************************************ */

  /** @dev The metadata construction contract.  */
  INftMetadata public metadataContract;

  /** @dev The address receiving fee payments in WCHI.  */
  address public override feeReceiver;

  /** @dev Time lock for fee changes.  */
  uint public constant feeTimelock = 1 weeks;

  /** @dev The flat fee for registrations.  */
  uint256 public registrationFee;

  /** @dev If the fee is being changed, the next fee.  */
  uint256 public nextFee;

  /**
   * @dev If the fee is being changed, the earliest timestamp when the
   * change can be enacted.  Zero when there is no current change.
   */
  uint public nextFeeAfter;

  /** @dev Emitted when the metadata contract is updated.  */
  event MetadataContractChanged (INftMetadata oldContract,
                                 INftMetadata newContract);

  /** @dev Emitted when the fee receiver changes.  */
  event FeeReceiverChanged (address oldReceiver, address newReceiver);

  /** @dev Emitted when a fee change is scheduled.  */
  event FeeChangeScheduled (uint256 newRegistrationFee, uint validAfter);

  /** @dev Emitted when the fee is changed.  */
  event FeeChanged (uint256 oldRegistrationFee, uint256 newRegistrationFee);

  /* ************************************************************************ */

  constructor (INftMetadata metadata, uint256 initialFee)
  {
    require (metadata != INftMetadata (address (0)),
             "invalid metadata contract");
    metadataContract = metadata;
    emit MetadataContractChanged (INftMetadata (address (0)), metadataContract);

    feeReceiver = msg.sender;
    emit FeeReceiverChanged (address (0), feeReceiver);

    registrationFee = initialFee;
    emit FeeChanged (0, registrationFee);

    /* nextFee starts off as zero, which means that
       there is no fee change scheduled.  */
  }

  /**
   * @dev Updates the contract that is used for generating metadata.
   */
  function setMetadataContract (INftMetadata newContract) public onlyOwner
  {
    require (newContract != INftMetadata (address (0)),
             "invalid metadata contract");

    emit MetadataContractChanged (metadataContract, newContract);
    metadataContract = newContract;
  }

  /**
   * @dev Updates the fee receiver.  This takes effect immediately (without
   * a time lock).
   */
  function setFeeReceiver (address newReceiver) public onlyOwner
  {
    require (newReceiver != address (0), "invalid fee receiver");

    emit FeeReceiverChanged (feeReceiver, newReceiver);
    feeReceiver = newReceiver;
  }

  /**
   * @dev Schedules a fee change to take place after the time lock.
   */
  function scheduleFeeChange (uint256 newRegistrationFee) public onlyOwner
  {
    nextFee = newRegistrationFee;
    nextFeeAfter = block.timestamp + feeTimelock;
    emit FeeChangeScheduled (nextFee, nextFeeAfter);
  }

  /**
   * @dev Executes a scheduled fee change when the timelock is expired.
   * This can be done by anyone, not only the owner.
   */
  function enactFeeChange () public
  {
    require (nextFeeAfter != 0, "no fee change is scheduled");
    require (block.timestamp >= nextFeeAfter,
             "fee timelock is not expired yet");

    emit FeeChanged (registrationFee, nextFee);
    registrationFee = nextFee;
    nextFee = 0;
    nextFeeAfter = 0;
  }

  /* ************************************************************************ */

  function checkRegistration (string memory ns, string memory name)
      public override view returns (uint256)
  {
    bytes memory nsBytes = bytes (ns);
    bytes memory nameBytes = bytes (name);

    require (nsBytes.length > 0, "namespace must not be empty");
    require (nsBytes.length + nameBytes.length < 256, "name is too long");

    for (uint i = 0; i < nsBytes.length; ++i)
      require (nsBytes[i] >= 0x61 && nsBytes[i] <= 0x7A, "invalid namespace");

    uint cp;
    uint offset = 0;
    while (offset < nameBytes.length)
      {
        (cp, offset) = Utf8.decodeCodepoint (nameBytes, offset);
        require (cp >= 0x20, "invalid codepoint in name");
      }

    return registrationFee;
  }

  function checkMove (string memory, string memory mv)
      public override pure returns (uint256)
  {
    bytes memory mvBytes = bytes (mv);
    for (uint i = 0; i < mvBytes.length; ++i)
      require (mvBytes[i] >= 0x20 && mvBytes[i] <= 0x7E, "invalid move data");

    return 0;
  }

  function tokenUriForName (string memory ns, string memory name)
      public override view returns (string memory)
  {
    return metadataContract.tokenUriForName (ns, name);
  }

  function contractUri () public override view returns (string memory)
  {
    return metadataContract.contractUri ();
  }

  /* ************************************************************************ */

}
