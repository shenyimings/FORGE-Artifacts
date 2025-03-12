pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";
import "./LMerkleLeafRules.sol";
import "./LMerkleRoots.sol";
import "./LEvents.sol";
import "./LEnums.sol";
import "./zeppelin/LECRecovery.sol";
import "./zokrates/LSigmaProofVerifier.sol";

library LMerkleLeafChecks {

  struct LeafData {
    LEnums.TransactionType transactionType;
    bytes immutableData;
    bytes mutableData;
    bytes provenance;
  }

  struct ImmutableTicketData {
    uint eventId;
    string vendorTicketRef;
    address vendor;
    bytes immutableRulesData;
  }

  struct MutableTicketData {
    bytes sigmaData;
    bytes mutableRulesData;
    bytes32 prevLeafHash;
    bytes32[] prevLeafMerklePath;
    string properties;
  }

  struct SigmaData {
    bytes merchantSignedInput;
    bytes ticketOwnerSignedInput;
    bytes sigmaProof;
  }

  struct ExtractedSigmaData {
    address merchantAddress;
    address ticketOwnerAddress;
    uint[2] generatorPoint1;
    uint[2] generatorPoint2;
    uint[2] publicInput1;
    uint[2] publicInput2;
    uint[2] commitment1;
    uint[2] commitment2;
    uint[2] proof;
  }

  function checkLeafRules(IAventusStorage _storage, bytes calldata _leafData, uint _rootRegistrationTime)
    external
    view
    returns (string memory checkFailedReason_)
  {
    LeafData memory leafData = decodeLeafData(_leafData);

    ImmutableTicketData memory immutableData = decodeImmutableTicketData(leafData.immutableData);

    bytes memory rules =  LEvents.getTransactionRules(_storage, immutableData.eventId, uint(leafData.transactionType));

    require(rules.length != 0, "Challenge failed - there are no rules for this transaction type");

    MutableTicketData memory mutableData = decodeMutableTicketData(leafData.mutableData);

    ExtractedSigmaData memory extractedSigmaData = decodeSigmaData(mutableData.sigmaData);
    checkFailedReason_ = LMerkleLeafRules.runRules(rules, _rootRegistrationTime, immutableData.immutableRulesData,
        mutableData.mutableRulesData, extractedSigmaData.ticketOwnerAddress);
    if (bytes(checkFailedReason_).length != 0)
      checkFailedReason_ = string(abi.encodePacked("All rules failed: ", checkFailedReason_));
  }

  // NOTE: Cannot be view: see isValidSigmaData.
  function checkLeafConsistency(IAventusStorage _storage, bytes calldata _leafData)
    external
    returns (string memory checkFailureReason_)
  {
    LeafData memory leafData = decodeLeafData(_leafData);
    MutableTicketData memory mutableData = decodeMutableTicketData(leafData.mutableData);
    ImmutableTicketData memory immutableData = decodeImmutableTicketData(leafData.immutableData);

    checkFailureReason_ = isValidSigmaData(leafData.transactionType, mutableData.sigmaData);
    if (bytes(checkFailureReason_).length != 0) {
      return checkFailureReason_;
    }

    checkFailureReason_ = isValidPrevMerkleProof(_storage, leafData.transactionType, mutableData);
    if (bytes(checkFailureReason_).length != 0) {
      return checkFailureReason_;
    }

    if (leafData.transactionType == LEnums.TransactionType.Sell) {
      return checkLeafConsistencySell(_storage, immutableData, mutableData, leafData.provenance);
    }

    if (leafData.transactionType == LEnums.TransactionType.Resell) {
      return checkLeafConsistencyResell(_storage, immutableData, leafData.provenance, mutableData.sigmaData);
    }

    if (leafData.transactionType == LEnums.TransactionType.Transfer) {
      return ""; // No further checks for transfer
    }

    if (leafData.transactionType == LEnums.TransactionType.Update) {
      return checkLeafConsistencyUpdate(_storage, immutableData, mutableData, leafData.provenance);
    }

    if (leafData.transactionType == LEnums.TransactionType.Cancel) {
      return checkLeafConsistencyCancel(_storage, immutableData, mutableData, leafData.provenance);
    }

    // ONLY_IF_ASSERTS_ON:
    bool validTxType = (leafData.transactionType == LEnums.TransactionType.Redeem);
    // :ONLY_IF_ASSERTS_ON
    assert(validTxType);

    checkFailureReason_ = checkLeafConsistencyRedeem(_storage, immutableData, mutableData, leafData.provenance);
  }

  function checkLeafDuplication(bytes calldata _duplicateLeafData, bytes calldata _existingLeafData)
    external
    pure
    returns (bool isDuplicate_)
  {
    if (decodeLeafData(_duplicateLeafData).transactionType == LEnums.TransactionType.Sell)
      isDuplicate_ = getLeafIdentity(_duplicateLeafData) == getLeafIdentity(_existingLeafData);
    else
      isDuplicate_ = getPrevLeafHash(_duplicateLeafData) == getPrevLeafHash(_existingLeafData);
  }

  function checkLeafLifecycle(bytes calldata _leafData, bytes calldata _previousLeafData)
    external
    pure
    returns (string memory checkFailureReason_)
  {
    LeafData memory leafData = decodeLeafData(_leafData);
    MutableTicketData memory mutableData = decodeMutableTicketData(leafData.mutableData);

    bytes32 previousLeafHash = keccak256(abi.encodePacked(_previousLeafData));
    require(mutableData.prevLeafHash == previousLeafHash, "Challenged failed - previous leaf must match previous leaf hash");
    LeafData memory previousLeafData = decodeLeafData(_previousLeafData);

    if (keccak256(abi.encodePacked(leafData.immutableData)) != keccak256(abi.encodePacked(previousLeafData.immutableData))) {
      return "Immutable data must not be modified";
    }

    if (previousLeafData.transactionType == LEnums.TransactionType.Cancel
        || previousLeafData.transactionType == LEnums.TransactionType.Redeem) {
      return "Cancelled and redeemed tickets cannot be further modified";
    }

    MutableTicketData memory previousLeafMutableData = decodeMutableTicketData(previousLeafData.mutableData);

    checkFailureReason_ = LMerkleLeafRules.checkLeafLifecycle(leafData.transactionType, mutableData.mutableRulesData,
        previousLeafMutableData.mutableRulesData);
    if (bytes(checkFailureReason_).length != 0) {
      return checkFailureReason_;
    }

    if (leafData.transactionType == LEnums.TransactionType.Update) {
      return checkLeafLifecycleUpdate(mutableData, previousLeafMutableData);
    }

    if (leafData.transactionType == LEnums.TransactionType.Resell) {
      return checkLeafLifecycleResell(leafData.provenance, mutableData, previousLeafMutableData);
    }

    if (leafData.transactionType == LEnums.TransactionType.Transfer) {
      return checkLeafLifecycleTransfer(leafData.provenance, mutableData, previousLeafMutableData);
    }

    // ONLY_IF_ASSERTS_ON:
    bool validTxType = leafData.transactionType == LEnums.TransactionType.Sell
        || leafData.transactionType == LEnums.TransactionType.Cancel
        || leafData.transactionType == LEnums.TransactionType.Redeem;
    // :ONLY_IF_ASSERTS_ON
    assert(validTxType);
  }

  // NOTE: This method MUST NOT contain asserts. Reverts will be caught in LMerkleLeafChallenges.callCheckLeafFormat but
  // asserts cannot be caught.
  function checkLeafFormat(bytes calldata _leafData)
    external
    pure
  {
    // NOTE: These decode methods call abi.decode which will revert if the leaf data is badly formatted.
    LeafData memory leafData = decodeLeafData(_leafData);
    ImmutableTicketData memory immutableData = decodeImmutableTicketData(leafData.immutableData);
    MutableTicketData memory mutableData = decodeMutableTicketData(leafData.mutableData);

    if (leafData.transactionType != LEnums.TransactionType.Cancel)
      decodeSigmaData(mutableData.sigmaData);
    decodeProvenance(leafData.transactionType, leafData.provenance);
    LMerkleLeafRules.checkRulesDataFormat(immutableData.immutableRulesData, mutableData.mutableRulesData);
  }

  // NOTE: This MUST NOT assert. Reverts are fine. See checkLeafFormat.
  function decodeLeafData(bytes memory _encodedLeafData)
    private
    pure
    returns (LeafData memory leafData_)
  {
    (uint transactionTypeAsUint, bytes memory immutableData, bytes memory mutableData, bytes memory provenance) = abi.decode(
        _encodedLeafData, (uint, bytes, bytes, bytes));
    leafData_.transactionType = LEnums.validateTransactionType(transactionTypeAsUint);
    leafData_.immutableData = immutableData;
    leafData_.mutableData = mutableData;
    leafData_.provenance = provenance;
  }

  // NOTE: This MUST NOT assert. Reverts are fine. See checkLeafFormat.
  function decodeImmutableTicketData(bytes memory _encodedImmutableData)
    private
    pure
    returns (ImmutableTicketData memory immutableTicketData_)
  {
    (uint eventId, string memory vendorTicketRef, address vendor, bytes memory immutableRulesData) =
        abi.decode(_encodedImmutableData, (uint, string, address, bytes));

    immutableTicketData_.eventId = eventId;
    immutableTicketData_.vendorTicketRef = vendorTicketRef;
    immutableTicketData_.vendor = vendor;
    immutableTicketData_.immutableRulesData = immutableRulesData;
  }

  // NOTE: This MUST NOT assert. Reverts are fine. See checkLeafFormat.
  function decodeMutableTicketData(bytes memory _encodedMutableData)
    private
    pure
    returns (MutableTicketData memory mutableTicketData_)
  {
    (bytes memory sigmaData, bytes memory mutableRulesData, bytes32 prevLeafHash, bytes32[] memory prevLeafMerklePath,
      string memory properties) = abi.decode(_encodedMutableData, (bytes, bytes, bytes32, bytes32[], string));

    mutableTicketData_.sigmaData = sigmaData;
    mutableTicketData_.mutableRulesData = mutableRulesData;
    mutableTicketData_.prevLeafHash = prevLeafHash;
    mutableTicketData_.prevLeafMerklePath = prevLeafMerklePath;
    mutableTicketData_.properties = properties;
  }

  // NOTE: This MUST NOT assert. Reverts are fine but strings will not be output. See checkLeafFormat.
  function decodeSigmaData(bytes memory _sigmaData)
    private
    pure
    returns (ExtractedSigmaData memory extractedSigmaData_)
  {
    SigmaData memory sigmaData;
    (sigmaData.merchantSignedInput, sigmaData.ticketOwnerSignedInput, sigmaData.sigmaProof) = abi.decode(_sigmaData,
        (bytes, bytes, bytes));

    (extractedSigmaData_.generatorPoint1, extractedSigmaData_.generatorPoint2, extractedSigmaData_.publicInput1,
        extractedSigmaData_.publicInput2, extractedSigmaData_.commitment1, extractedSigmaData_.commitment2,
        extractedSigmaData_.proof) = abi.decode(sigmaData.sigmaProof, (uint[2], uint[2], uint[2], uint[2], uint[2], uint[2],
        uint[2]));

    extractedSigmaData_.merchantAddress = LECRecovery.recover(keccak256(abi.encodePacked(extractedSigmaData_.publicInput1)),
        sigmaData.merchantSignedInput);
    extractedSigmaData_.ticketOwnerAddress = LECRecovery.recover(keccak256(abi.encodePacked(extractedSigmaData_.publicInput2)),
        sigmaData.ticketOwnerSignedInput);
  }

  // NOTE: This MUST NOT assert. Reverts are fine. See checkLeafFormat.
  function decodeProvenance(LEnums.TransactionType _transactionType, bytes memory _provenance)
    private
    pure
    returns (bytes memory proof1_, bytes memory proof2_)
  {
    if (_transactionType == LEnums.TransactionType.Sell
        || _transactionType == LEnums.TransactionType.Resell)
      (proof1_, proof2_) = abi.decode(_provenance, (bytes, bytes));
    // else: all other types use a single proof provenance, they can just use the provenance directly.
  }

  function decodeResellerProvenance(bytes memory _provenance)
    private
    pure
    returns (address reseller_, bytes memory ticketOwnerProof_)
  {
    bytes memory resellerProof;
    (resellerProof, ticketOwnerProof_) = decodeProvenance(LEnums.TransactionType.Resell, _provenance);
    reseller_ = LECRecovery.recover(keccak256(abi.encodePacked(uint(LEnums.TransactionType.Resell),
        ticketOwnerProof_)), resellerProof);
  }

  function checkLeafConsistencySell(IAventusStorage _storage, ImmutableTicketData memory _immutableData,
      MutableTicketData memory _mutableData, bytes memory _provenance)
    private
    view
    returns (string memory inconsistentLeafReason_)
  {
    if (LEvents.getEventOwner(_storage, _immutableData.eventId) == address(0)) {
      return "Sell for non-existent event";
    }

    if (!LEvents.isEventOwnerOrRole(_storage, _immutableData.eventId, _immutableData.vendor, "Primary")) {
      return "Vendor must be valid Primary or event owner";
    }

    (bytes memory identityVendorProof, bytes memory propertiesVendorProof) =
        decodeProvenance(LEnums.TransactionType.Sell, _provenance);
    bytes32 identityHash = keccak256(abi.encodePacked(uint(LEnums.TransactionType.Sell), _immutableData.eventId,
        _immutableData.vendorTicketRef));
    address identitySigner = LECRecovery.recover(identityHash, identityVendorProof);
    if (identitySigner != _immutableData.vendor) {
      return "Ticket identity must be signed by vendor";
    }

    address propertiesSigner = LECRecovery.recover(keccak256(abi.encodePacked(uint(LEnums.TransactionType.Sell),
        _mutableData.properties)), propertiesVendorProof);
    if (propertiesSigner != _immutableData.vendor) {
      return "Ticket property must be signed by vendor";
    }

    ExtractedSigmaData memory extractedSigmaData = decodeSigmaData(_mutableData.sigmaData);
    if (extractedSigmaData.merchantAddress != _immutableData.vendor) {
      return "Sigma merchant signed hash must be signed by vendor";
    }

    return LMerkleLeafRules.checkRulesConsistencySell(_mutableData.mutableRulesData);
  }

  function checkLeafConsistencyResell(IAventusStorage _storage, ImmutableTicketData memory _immutableData,
      bytes memory _provenance, bytes memory _sigmaData)
    private
    view
    returns (string memory inconsistentLeafReason_)
  {
    (address reseller, /* ticketOwnerProof */) = decodeResellerProvenance(_provenance);
    if (!LEvents.isEventOwnerOrRole(_storage, _immutableData.eventId, reseller, "Secondary")) {
      return "Reseller proof must contain correct data and be signed by valid reseller";
    }

    ExtractedSigmaData memory extractedSigmaData = decodeSigmaData(_sigmaData);
    if (extractedSigmaData.merchantAddress != reseller) {
      return "Sigma merchant signed hash must be signed by reseller";
    }
  }

  function checkLeafConsistencyUpdate(IAventusStorage _storage, ImmutableTicketData memory _immutableData,
      MutableTicketData memory _mutableData, bytes memory _provenance)
    private
    view
    returns (string memory inconsistentLeafReason_)
  {
    bytes32 updateProofHash = keccak256(abi.encodePacked(uint(LEnums.TransactionType.Update),
        _mutableData.prevLeafHash, _mutableData.properties));
    address updateProofSigner = LECRecovery.recover(updateProofHash, _provenance);
    if (updateProofSigner != _immutableData.vendor &&
        updateProofSigner != LEvents.getEventOwner(_storage, _immutableData.eventId))
      inconsistentLeafReason_ = "Update proof must contain correct data and be signed by original vendor or event owner";
  }

  function checkLeafConsistencyCancel(IAventusStorage _storage, ImmutableTicketData memory _immutableData,
      MutableTicketData memory _mutableData, bytes memory _provenance)
    private
    view
    returns (string memory inconsistentLeafReason_)
  {
    address cancelProofSigner = LECRecovery.recover(keccak256(abi.encodePacked(uint(LEnums.TransactionType.Cancel),
        _mutableData.prevLeafHash)), _provenance);
    if (cancelProofSigner != _immutableData.vendor &&
        cancelProofSigner != LEvents.getEventOwner(_storage, _immutableData.eventId))
      inconsistentLeafReason_ = "Proof must contain correct data and be signed by original vendor or event owner";
  }

  function checkLeafConsistencyRedeem(IAventusStorage _storage, ImmutableTicketData memory _immutableData,
      MutableTicketData memory _mutableData, bytes memory _provenance)
    private
    view
    returns (string memory inconsistentLeafReason_)
  {
    address redeemProofSigner = LECRecovery.recover(keccak256(abi.encodePacked(uint(LEnums.TransactionType.Redeem),
        _mutableData.prevLeafHash)), _provenance);
    if (redeemProofSigner != _immutableData.vendor &&
        redeemProofSigner != LEvents.getEventOwner(_storage, _immutableData.eventId))
      inconsistentLeafReason_ = "Proof must contain correct data and be signed by original vendor or event owner";
  }

  function checkLeafLifecycleUpdate(MutableTicketData memory _mutableData,
      MutableTicketData memory _previousLeafMutableData)
    private
    pure
    returns (string memory inconsistentUpdateReason_)
  {
    bytes32 sigmaDataHash = keccak256(abi.encodePacked(_mutableData.sigmaData));
    bytes32 previousSigmaDataHash = keccak256(abi.encodePacked(_previousLeafMutableData.sigmaData));
    if (sigmaDataHash != previousSigmaDataHash) {
      return "Ticket updates must not change the sigma data";
    }
  }

  function checkLeafLifecycleResell(bytes memory _provenance, MutableTicketData memory _mutableData,
      MutableTicketData memory _previousLeafMutableData)
    private
    pure
    returns (string memory inconsistentResellReason_)
  {
    (address reseller, bytes memory ticketOwnerProof) = decodeResellerProvenance(_provenance);
    address expectedPreviousTicketOwner =
        LECRecovery.recover(keccak256(abi.encodePacked(uint(LEnums.TransactionType.Resell),
        _mutableData.prevLeafHash, reseller)), ticketOwnerProof);
    ExtractedSigmaData memory previousExtractedSigmaData = decodeSigmaData(_previousLeafMutableData.sigmaData);
    return checkPreviousTicketOwnerPermission(expectedPreviousTicketOwner, previousExtractedSigmaData);
  }

  function checkLeafLifecycleTransfer(bytes memory _provenance, MutableTicketData memory _mutableData,
      MutableTicketData memory _previousLeafMutableData)
    private
    pure
    returns (string memory inconsistentTransferReason_)
  {
    ExtractedSigmaData memory previousSigmaData = decodeSigmaData(_previousLeafMutableData.sigmaData);
    ExtractedSigmaData memory newSigmaData = decodeSigmaData(_mutableData.sigmaData);
    if (keccak256(abi.encodePacked(newSigmaData.publicInput1)) != keccak256(abi.encodePacked(previousSigmaData.publicInput1))) {
      return "Sigma merchant signed hash must not change on transfer";
    }

    address expectedPreviousTicketOwner =
        LECRecovery.recover(keccak256(abi.encodePacked(uint(LEnums.TransactionType.Transfer),
        _mutableData.prevLeafHash)), _provenance);
    return checkPreviousTicketOwnerPermission(expectedPreviousTicketOwner, previousSigmaData);
  }

  function checkPreviousTicketOwnerPermission(address _expectedPreviousTicketOwner,
      ExtractedSigmaData memory _previousExtractedSigmaData)
    private
    pure
    returns (string memory invalidTicketOwnerReason_)
  {
    if (_expectedPreviousTicketOwner != _previousExtractedSigmaData.ticketOwnerAddress)
      invalidTicketOwnerReason_ = "Previous ticket owner proof must be signed by previous ticket owner";
  }

  // NOTE: Cannot be pure due to inline assembly through verifySigmaProof.
  function isValidSigmaData(LEnums.TransactionType _transactionType, bytes memory _sigmaData)
    private
    returns (string memory invalidReason_)
  {
    if (_transactionType == LEnums.TransactionType.Cancel) {
      if (_sigmaData.length != 0) {
        return "Cancel leaf must have no sigma data";
      }
      return "";
    }

    if (_transactionType == LEnums.TransactionType.Sell
        || _transactionType == LEnums.TransactionType.Resell
        || _transactionType == LEnums.TransactionType.Transfer
        || _transactionType == LEnums.TransactionType.Redeem)
    {
      ExtractedSigmaData memory sigmaData = decodeSigmaData(_sigmaData);

      bool sigmaProofIsValid = LSigmaProofVerifier.verifySigmaProof(sigmaData.generatorPoint1, sigmaData.generatorPoint2,
          sigmaData.publicInput1, sigmaData.publicInput2, sigmaData.commitment1, sigmaData.commitment2, sigmaData.proof);

      if (!sigmaProofIsValid)
        invalidReason_ = "Sigma proof is invalid";
      return invalidReason_;
    }

    assert(_transactionType == LEnums.TransactionType.Update);
  }

  function isValidPrevMerkleProof(IAventusStorage _storage, LEnums.TransactionType _transactionType,
      MutableTicketData memory _mutableData)
    private
    view
    returns (string memory invalidReason_)
  {
    if (_transactionType == LEnums.TransactionType.Sell) {
      if (_mutableData.prevLeafHash != 0 || _mutableData.prevLeafMerklePath.length != 0)
        invalidReason_ = "Sell must have no previous leaf data";
    } else {
      bytes32 prevMerkleRoot = LMerkleRoots.generateMerkleRoot(_storage, _mutableData.prevLeafMerklePath,
            _mutableData.prevLeafHash);
      if (!LMerkleRoots.merkleRootIsRegistered(_storage, prevMerkleRoot))
        invalidReason_ = "Previous Merkle root must be registered";
    }
  }

  function getLeafIdentity(bytes memory _leafData)
    private
    pure
    returns (bytes32 leafIdentity_)
  {
    LeafData memory leafData = decodeLeafData(_leafData);
    ImmutableTicketData memory immutableData = decodeImmutableTicketData(leafData.immutableData);
    leafIdentity_ = keccak256(abi.encodePacked(immutableData.eventId, immutableData.vendorTicketRef, immutableData.vendor));
  }

  function getPrevLeafHash(bytes memory _leafData)
    private
    pure
    returns (bytes32 prevLeafHash_)
  {
    LeafData memory leafData = decodeLeafData(_leafData);
    MutableTicketData memory mutableData = decodeMutableTicketData(leafData.mutableData);
    prevLeafHash_ = mutableData.prevLeafHash;
  }
}