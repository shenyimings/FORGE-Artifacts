// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "openzeppelin-contracts/contracts/utils/Pausable.sol";


error InvalidSigner();
error InvalidProof();
error InvalidApproval();
error ExpiredTimestamp();

contract ChangeName is Ownable, Pausable {
  address public storeReceiver;
  address public paymentTokenAddress;

  IERC721 public nftContract;
  uint8 public maxLength;
  uint8 public minLength;
  bytes public allowedCharacters;

  event TransactionProcessed(address indexed buyer, uint256 amount, string name, uint256 tokenId);

  struct ValidationData {
    string expiringTime;
    bytes32[] expiringProof;
    string offer;
    bytes32[] offerProof;
    bytes32 merkleRoot;
  }

  struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  constructor(
    address _nftContract,
    uint8 _minLength,
    uint8 _maxLength,
    bytes memory _allowedCharacters,
    address _storeReceiver,
    address _paymentTokenAddress,
    address _owner
  ) Ownable(_owner) {
    require(_minLength <= _maxLength, "Min length should be less than or equal to max length");

    nftContract = IERC721(_nftContract);
    minLength = _minLength;
    maxLength = _maxLength;
    allowedCharacters = _allowedCharacters;
    storeReceiver = _storeReceiver;
    paymentTokenAddress = _paymentTokenAddress;
    _transferOwnership(_owner);
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  function setStoreReceiver(address _storeReceiver) external onlyOwner {
    storeReceiver = _storeReceiver;
  }

  function setPaymentTokenAddress(address _paymentTokenAddress) external onlyOwner {
    paymentTokenAddress = _paymentTokenAddress;
  }

  function setNFTContractAddress(address _nftContract) external onlyOwner {
    nftContract = IERC721(_nftContract);
  }

  function setNameLengths(uint8 _minLength, uint8 _maxLength) external onlyOwner {
    require(_minLength <= _maxLength, "Min length should be less than or equal to max length");
    minLength = _minLength;
    maxLength = _maxLength;
  }

  function setAllowedCharacters(bytes memory _characters) external onlyOwner {
    allowedCharacters = _characters;
  }

  function _stringToUint(string memory s) internal pure returns (uint256) {
    bytes memory b = bytes(s);
    uint256 result = 0;
    for (uint i = 0; i < b.length; i++) {
      uint8 temp = uint8(b[i]) - 48; // convert char to uint
      result = result * 10 + temp;
    }
    return result;
  }

  function checkSig(
    address signer,
    bytes32 hash,
    Signature calldata sig
  ) public pure returns (bool isValid) {
    address recover = ecrecover(hash, sig.v, sig.r, sig.s);
    isValid = recover == signer;
  }

  function verifyMerkle(
    string calldata offer,
    bytes32[] calldata proof,
    bytes32 merkleRoot
  ) public pure returns (bool) {
    bytes32 leaf = keccak256(abi.encodePacked(offer));
    return MerkleProof.verify(proof, merkleRoot, leaf);
  }

  // Only used for testing !
  function checkExpiringTime(
    string calldata expiringTime,
    bytes32[] calldata expiringProof,
    bytes32 merkleRoot
  ) public view returns (bool) {
    if (!verifyMerkle(expiringTime, expiringProof, merkleRoot)) {
      revert InvalidProof();
    }
    bytes memory timeBytes = bytes(expiringTime);
    uint256 startIndex = 7; // 'expire:' has 7 characters
    uint256 endIndex = timeBytes.length;
    uint256 expiryTimestamp = 0;
    for (uint256 i = startIndex; i < endIndex; i++) {
      expiryTimestamp =
        expiryTimestamp *
        10 +
        uint256(uint8(timeBytes[i])) -
        48;
    }
    if (block.timestamp >= expiryTimestamp) {
      revert ExpiredTimestamp();
    }

    return true;
  }

  function validateMerkleValues(
    ValidationData calldata data
  ) public view returns (bool) {
    if (!verifyMerkle(data.expiringTime, data.expiringProof, data.merkleRoot)) {
      revert InvalidProof();
    }
    if (!verifyMerkle(data.offer, data.offerProof, data.merkleRoot)) {
      revert InvalidProof();
    }
    bytes memory timeBytes = bytes(data.expiringTime);
    uint256 startIndex = 7; // 'expire:' has 7 characters
    uint256 endIndex = timeBytes.length;
    uint256 expiryTimestamp = 0;
    for (uint256 i = startIndex; i < endIndex; i++) {
      expiryTimestamp =
        expiryTimestamp *
        10 +
        uint256(uint8(timeBytes[i])) -
        48;
    }
    if (block.timestamp >= expiryTimestamp) {
      revert ExpiredTimestamp();
    }
    return true;
  }

  function _isValidCharacter(bytes1 char) internal view returns (bool) {
    for (uint256 i = 0; i < allowedCharacters.length; i++) {
      if (allowedCharacters[i] == char) {
        return true;
      }
    }
    return false;
  }

  function _isValidName(string memory name, uint256 tokenId) internal view {
    require(bytes(name).length >= minLength && bytes(name).length <= maxLength, "Invalid name length");

    for (uint256 i = 0; i < bytes(name).length; i++) {
      require(_isValidCharacter(bytes(name)[i]), "Invalid character in name");
    }

    require(nftContract.ownerOf(tokenId) == msg.sender, "Caller is not the owner of the NFT");
  }

  function proceedToBuy(
    string calldata name,
    uint32 tokenId,
    ValidationData calldata data,
    Signature calldata sig
  ) public whenNotPaused {
    _isValidName(name, tokenId);

    IERC20 paymentToken = IERC20(paymentTokenAddress);
    uint256 offerAmount = _stringToUint(data.offer);

    require(paymentToken.allowance(msg.sender, address(this)) >= offerAmount, "Invalid approval");
    require(checkSig(owner(), data.merkleRoot, sig), "Invalid signer");

    validateMerkleValues(data);

    paymentToken.transferFrom(
      msg.sender,
      address(storeReceiver),
      offerAmount
    );

    emit TransactionProcessed(msg.sender, offerAmount, name, tokenId);
  }
}
