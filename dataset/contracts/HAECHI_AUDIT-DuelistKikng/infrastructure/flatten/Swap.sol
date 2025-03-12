// Dependency file: contracts/interfaces/INFT.sol

// SPDX-License-Identifier: MIT
// pragma solidity >=0.8.4 <0.9.0;

interface INFT {
  function init(
    address registry_,
    bytes32 domain_,
    string memory name_,
    string memory symbol_,
    string memory uri_
  ) external returns (bool);

  function safeTransfer(
    address from,
    address to,
    uint256 tokenId
  ) external returns (bool);

  function batchMint(address to, uint256[] memory tokenIds) external returns (bool);

  function batchBurn(address to, uint256[] memory tokenIds) external returns (bool);

  function ownerOf(uint256 tokenId) external view returns (address);

  function mint(address to, uint256 tokenId) external returns (bool);

  function burn(uint256 tokenId) external returns (bool);

  function changeBaseURI(string memory uri_) external returns (bool);
}


// Dependency file: contracts/libraries/Bytes.sol

// pragma solidity >=0.8.4 <0.9.0;

library Bytes {
  // Convert bytes to bytes32[]
  function toBytes32Array(bytes memory input) public pure returns (bytes32[] memory) {
    require(input.length % 32 == 0, 'Bytes: invalid data length should divied by 32');
    bytes32[] memory result = new bytes32[](input.length / 32);
    assembly {
      // Read length of data from offset
      let length := mload(input)

      // Seek offset to the beginning
      let offset := add(input, 0x20)

      // Next is size of chunk
      let resultOffset := add(result, 0x20)

      for {
        let i := 0
      } lt(i, length) {
        i := add(i, 0x20)
      } {
        mstore(resultOffset, mload(add(offset, i)))
        resultOffset := add(resultOffset, 0x20)
      }
    }
    return result;
  }

  // Read address from input bytes buffer
  function readAddress(bytes memory input, uint256 offset) public pure returns (address result) {
    require(offset + 20 <= input.length, 'Bytes: Out of range, can not read address from bytes');
    assembly {
      result := shr(96, mload(add(add(input, 0x20), offset)))
    }
  }

  // Read uint256 from input bytes buffer
  function readUint256(bytes memory input, uint256 offset) public pure returns (uint256 result) {
    require(offset + 32 <= input.length, 'Bytes: Out of range, can not read uint256 from bytes');
    assembly {
      result := mload(add(add(input, 0x20), offset))
    }
  }

  // Read bytes from input bytes buffer
  function readBytes(
    bytes memory input,
    uint256 offset,
    uint256 length
  ) public pure returns (bytes memory) {
    require(offset + length <= input.length, 'Bytes: Out of range, can not read bytes from bytes');
    bytes memory result = new bytes(length);
    assembly {
      // Seek offset to the beginning
      let seek := add(add(input, 0x20), offset)

      // Next is size of data
      let resultOffset := add(result, 0x20)

      for {
        let i := 0
      } lt(i, length) {
        i := add(i, 0x20)
      } {
        mstore(add(resultOffset, i), mload(add(seek, i)))
      }
    }
    return result;
  }
}


// Dependency file: contracts/libraries/Verifier.sol

// pragma solidity >=0.8.4 <0.9.0;

library Verifier {
  function verifySerialized(bytes memory message, bytes memory signature) public pure returns (address) {
    bytes32 r;
    bytes32 s;
    uint8 v;
    assembly {
      // Singature need to be 65 in length
      // if (signature.length !== 65) revert();
      if iszero(eq(mload(signature), 65)) {
        revert(0, 0)
      }
      // r = signature[:32]
      // s = signature[32:64]
      // v = signature[64]
      r := mload(add(signature, 0x20))
      s := mload(add(signature, 0x40))
      v := byte(0, mload(add(signature, 0x60)))
    }
    return verify(message, r, s, v);
  }

  function verify(
    bytes memory message,
    bytes32 r,
    bytes32 s,
    uint8 v
  ) public pure returns (address) {
    if (v < 27) {
      v += 27;
    }
    // V must be 27 or 28
    require(v == 27 || v == 28, 'Invalid v value');
    // Get hashes of message with Ethereum proof prefix
    bytes32 hashes = keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n', uintToStr(message.length), message));

    return ecrecover(hashes, v, r, s);
  }

  function uintToStr(uint256 value) public pure returns (string memory result) {
    // Inspired by OraclizeAPI's implementation - MIT licence
    // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

    if (value == 0) {
      return '0';
    }
    uint256 temp = value;
    uint256 digits;
    while (temp != 0) {
      digits++;
      temp /= 10;
    }
    bytes memory buffer = new bytes(digits);
    while (value != 0) {
      digits -= 1;
      buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
      value /= 10;
    }
    return string(buffer);
  }
}


// Dependency file: contracts/interfaces/IRegistry.sol

// pragma solidity >=0.8.4 <0.9.0;

interface IRegistry {
  event Registered(bytes32 domain, bytes32 indexed name, address indexed addr);

  function isExistRecord(bytes32 domain, bytes32 name) external view returns (bool);

  function set(
    bytes32 domain,
    bytes32 name,
    address addr
  ) external returns (bool);

  function batchSet(
    bytes32[] calldata domains,
    bytes32[] calldata names,
    address[] calldata addrs
  ) external returns (bool);

  function getAddress(bytes32 domain, bytes32 name) external view returns (address);

  function getDomainAndName(address addr) external view returns (bytes32, bytes32);
}


// Dependency file: contracts/libraries/RegistryUser.sol

// pragma solidity >=0.8.4 <0.9.0;

// import 'contracts/interfaces/IRegistry.sol';

abstract contract RegistryUser {
  // Registry contract
  IRegistry internal _registry;

  // Active domain
  bytes32 internal _domain;

  // Initialized
  bool private _initialized = false;

  // Allow same domain calls
  modifier onlyAllowSameDomain(bytes32 name) {
    require(msg.sender == _registry.getAddress(_domain, name), 'UserRegistry: Only allow call from same domain');
    _;
  }

  // Allow cross domain call
  modifier onlyAllowCrossDomain(bytes32 fromDomain, bytes32 name) {
    require(
      msg.sender == _registry.getAddress(fromDomain, name),
      'UserRegistry: Only allow call from allowed cross domain'
    );
    _;
  }

  /*******************************************************
   * Internal section
   ********************************************************/

  // Constructing with registry address and its active domain
  function _registryUserInit(address registry_, bytes32 domain_) internal returns (bool) {
    require(!_initialized, "UserRegistry: It's only able to initialize once");
    _registry = IRegistry(registry_);
    _domain = domain_;
    _initialized = true;
    return true;
  }

  // Get address in the same domain
  function _getAddressSameDomain(bytes32 name) internal view returns (address) {
    return _registry.getAddress(_domain, name);
  }

  /*******************************************************
   * View section
   ********************************************************/

  // Return active domain
  function getDomain() external view returns (bytes32) {
    return _domain;
  }

  // Return registry address
  function getRegistry() external view returns (address) {
    return address(_registry);
  }
}


// Root file: contracts/dao/Swap.sol

pragma solidity >=0.8.4 <0.9.0;

// import 'contracts/interfaces/INFT.sol';
// import 'contracts/libraries/Bytes.sol';
// import 'contracts/libraries/Verifier.sol';
// import 'contracts/libraries/RegistryUser.sol';

/**
 * Swap can transfer NFT by consume cryptography proof
 * Name: Swap
 * Domain: Infrastructure
 */
contract Swap is RegistryUser {
  // Verify signature
  using Verifier for bytes;

  // Decode bytes array
  using Bytes for bytes;

  // Partner of duelistking
  mapping(address => bool) private _partners;

  // Nonce
  mapping(address => uint256) private _nonceStorage;

  // List partner
  event ListPartner(address indexed partnerAddress);

  // Delist partner
  event DelistPartner(address indexed partnerAddress);

  // Only allow partner to execute
  modifier onlyPartner() {
    require(_partners[msg.sender] == true, 'Swap: Sender was not partner');
    _;
  }

  // Pass constructor parameter to User
  constructor(address registry_, bytes32 domain_) {
    _registryUserInit(registry_, domain_);
  }

  /*******************************************************
   * Partner section
   ********************************************************/

  // Partners can trigger delegate transfer right with a cyrptography proof from owner
  function delegateTransfer(bytes memory proof) external onlyPartner returns (bool) {
    // Check for size of the proof
    require(proof.length >= 169, 'Swap: Wrong size of the proof, it must be greater than 169 bytes');
    bytes memory signature = proof.readBytes(0, 65);
    bytes memory message = proof.readBytes(65, proof.length - 65);
    address from = message.verifySerialized(signature);
    address to = message.readAddress(0);
    address nft = message.readAddress(20);
    uint256 nonce = message.readUint256(40);
    bytes memory nftTokenIds = message.readBytes(72, proof.length - 72);
    require(nftTokenIds.length % 32 == 0, 'Swap: Invalid token ID length');
    // Transfer one by one
    for (uint256 i = 0; i < nftTokenIds.length; i += 32) {
      INFT(nft).safeTransfer(from, to, nftTokenIds.readUint256(i));
    }
    // Each nonce is only able to be use once
    require(nonce - _nonceStorage[from] == 1, 'Swap: Incorrect nonce of signer');
    _nonceStorage[from] += 1;
    return true;
  }

  /*******************************************************
   * Operator section
   ********************************************************/

  // List a new partner
  function listPartner(address partnerAddress) external onlyAllowSameDomain('Operator') returns (bool) {
    _partners[partnerAddress] = true;
    emit ListPartner(partnerAddress);
    return true;
  }

  // Delist a partner
  function delistPartner(address partnerAddress) external onlyAllowSameDomain('Operator') returns (bool) {
    _partners[partnerAddress] = false;
    emit DelistPartner(partnerAddress);
    return true;
  }

  /*******************************************************
   * View section
   ********************************************************/

  // Get nonce of an address
  function getValidNonce(address owner) external view returns (uint256) {
    return _nonceStorage[owner] + 1;
  }

  // Check an address is partner or not
  function isPartner(address partner) external view returns (bool) {
    return _partners[partner];
  }
}
