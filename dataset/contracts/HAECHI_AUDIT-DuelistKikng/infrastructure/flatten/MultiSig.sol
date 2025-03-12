// Dependency file: @openzeppelin/contracts/utils/Address.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Address.sol)

// pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
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


// Dependency file: contracts/operators/MultiOwner.sol

// pragma solidity >=0.8.4 <0.9.0;

contract MultiOwner {
  // Multi owner data
  mapping(address => bool) private _owners;

  // Multi owner data
  mapping(address => uint256) private _activeTime;

  // Total number of owners
  uint256 private _totalOwner;

  // Only allow listed address to trigger smart contract
  modifier onlyListedOwner() {
    require(
      _owners[msg.sender] && block.timestamp > _activeTime[msg.sender],
      'MultiOwner: We are only allow owner to trigger this contract'
    );
    _;
  }

  // Transfer ownership event
  event TransferOwnership(address indexed preOwner, address indexed newOwner);

  constructor(address[] memory owners_) {
    for (uint256 i = 0; i < owners_.length; i += 1) {
      _owners[owners_[i]] = true;
      emit TransferOwnership(address(0), owners_[i]);
    }
    _totalOwner = owners_.length;
  }

  /*******************************************************
   * Internal section
   ********************************************************/

  function _transferOwnership(address newOwner, uint256 lockDuration) internal returns (bool) {
    require(newOwner != address(0), 'MultiOwner: Can not transfer ownership to zero address');
    _owners[msg.sender] = false;
    _owners[newOwner] = true;
    _activeTime[newOwner] = block.timestamp + lockDuration;
    emit TransferOwnership(msg.sender, newOwner);
    return _owners[newOwner];
  }

  /*******************************************************
   * View section
   ********************************************************/

  function isOwner(address checkAddress) public view returns (bool) {
    return _owners[checkAddress] && block.timestamp > _activeTime[checkAddress];
  }

  function totalOwner() public view returns (uint256) {
    return _totalOwner;
  }
}


// Root file: contracts/operators/MultiSig.sol

pragma solidity >=0.8.4 <0.9.0;

// import '/Users/chiro/GitHub/infrastructure/node_modules/@openzeppelin/contracts/utils/Address.sol';
// import 'contracts/libraries/Verifier.sol';
// import 'contracts/libraries/Bytes.sol';
// import 'contracts/operators/MultiOwner.sol';

/**
 * Multi Signature Wallet
 * Name: N/A
 * Domain: N/A
 */
contract MultiSig is MultiOwner {
  // Address lib providing safe {call} and {delegatecall}
  using Address for address;

  // Byte manipulation
  using Bytes for bytes;

  // Verifiy digital signature
  using Verifier for bytes;

  // Structure of proposal
  struct Proposal {
    int256 vote;
    uint64 expired;
    bool executed;
    bool delegate;
    uint256 value;
    address target;
    bytes data;
  }

  // Proposal index, begin from 1
  uint256 private _proposalIndex;

  // Proposal storage
  mapping(uint256 => Proposal) private _proposalStorage;

  // Voted storage
  mapping(uint256 => mapping(address => bool)) private _votedStorage;

  // Quick transaction nonce
  uint256 private _nonce;

  // Create a new proposal
  event CreateProposal(uint256 indexed proposalId, uint256 indexed expired);

  // Execute proposal
  event ExecuteProposal(uint256 indexed proposalId, address indexed trigger, int256 indexed vote);

  // Positive vote
  event PositiveVote(uint256 indexed proposalId, address indexed owner);

  // Negative vote
  event NegativeVote(uint256 indexed proposalId, address indexed owner);

  // This contract able to receive fund
  receive() external payable {}

  // Pass parameters to parent contract
  constructor(address[] memory owners_) MultiOwner(owners_) {}

  /*******************************************************
   * Owner section
   ********************************************************/
  // Transfer ownership to new owner
  function transferOwnership(address newOwner) external onlyListedOwner {
    // New owner will be activated after 3 days
    _transferOwnership(newOwner, 3 days);
  }

  // Transfer with signed proofs instead of onchain voting
  function quickTransfer(bytes[] memory signatures, bytes memory txData) external onlyListedOwner returns (bool) {
    uint256 totalSigned = 0;
    address[] memory signedAddresses = new address[](signatures.length);
    for (uint256 i = 0; i < signatures.length; i += 1) {
      address signer = txData.verifySerialized(signatures[i]);
      // Each signer only able to be counted once
      if (isOwner(signer) && _isNotInclude(signedAddresses, signer)) {
        signedAddresses[totalSigned] = signer;
        totalSigned += 1;
      }
    }
    require(_calculatePercent(int256(totalSigned)) >= 70, 'MultiSig: Total signed was not greater than 70%');
    uint256 nonce = txData.readUint256(0);
    address target = txData.readAddress(32);
    bytes memory data = txData.readBytes(52, txData.length - 52);
    require(nonce - _nonce == 1, 'MultiSign: Invalid nonce value');
    _nonce = nonce;
    target.functionCallWithValue(data, 0);
    return true;
  }

  // Create a new proposal
  function createProposal(Proposal memory newProposal) external onlyListedOwner returns (uint256) {
    _proposalIndex += 1;
    newProposal.expired = uint64(block.timestamp + 1 days);
    newProposal.vote = 0;
    _proposalStorage[_proposalIndex] = newProposal;
    emit CreateProposal(_proposalIndex, newProposal.expired);
    return _proposalIndex;
  }

  // Positive vote
  function votePositive(uint256 proposalId) external onlyListedOwner returns (bool) {
    return _voteProposal(proposalId, true);
  }

  // Negative vote
  function voteNegative(uint256 proposalId) external onlyListedOwner returns (bool) {
    return _voteProposal(proposalId, false);
  }

  // Execute a voted proposal
  function execute(uint256 proposalId) external onlyListedOwner returns (bool) {
    Proposal memory currentProposal = _proposalStorage[proposalId];
    int256 positiveVoted = _calculatePercent(currentProposal.vote);
    // If positiveVoted < 70%, It need to pass 50% and expired
    if (positiveVoted < 70) {
      require(block.timestamp > _proposalStorage[proposalId].expired, "MultiSig: Voting period wasn't over");
      require(positiveVoted >= 50, 'MultiSig: Vote was not pass 50%');
    }
    require(currentProposal.executed == false, 'MultiSig: Proposal was executed');
    if (currentProposal.delegate) {
      currentProposal.target.functionDelegateCall(currentProposal.data);
    } else {
      if (currentProposal.target.isContract()) {
        currentProposal.target.functionCallWithValue(currentProposal.data, currentProposal.value);
      } else {
        payable(address(currentProposal.target)).transfer(currentProposal.value);
      }
    }
    currentProposal.executed = true;
    _proposalStorage[proposalId] = currentProposal;
    emit ExecuteProposal(proposalId, msg.sender, currentProposal.vote);
    return true;
  }

  /*******************************************************
   * Private section
   ********************************************************/
  // Vote a proposal
  function _voteProposal(uint256 proposalId, bool positive) private returns (bool) {
    require(block.timestamp < _proposalStorage[proposalId].expired, 'MultiSig: Voting period was over');
    require(_votedStorage[proposalId][msg.sender] == false, 'MultiSig: You had voted this proposal');
    if (positive) {
      _proposalStorage[proposalId].vote += 1;
      emit PositiveVote(proposalId, msg.sender);
    } else {
      _proposalStorage[proposalId].vote -= 1;
      emit NegativeVote(proposalId, msg.sender);
    }
    _votedStorage[proposalId][msg.sender] = true;
    return true;
  }

  /*******************************************************
   * Pure section
   ********************************************************/

  function _isNotInclude(address[] memory addressList, address checkAddress) private pure returns (bool) {
    for (uint256 i = 0; i < addressList.length; i += 1) {
      if (addressList[i] == checkAddress) {
        return false;
      }
    }
    return true;
  }

  function _calculatePercent(int256 votedOwner) private view returns (int256) {
    return (votedOwner * 10000) / int256(totalOwner() * 100);
  }

  /*******************************************************
   * View section
   ********************************************************/

  function proposalIndex() external view returns (uint256) {
    return _proposalIndex;
  }

  function proposalDetail(uint256 index) external view returns (Proposal memory) {
    return _proposalStorage[index];
  }

  function isVoted(uint256 proposalId, address owner) external view returns (bool) {
    return _votedStorage[proposalId][owner];
  }

  function getNextValidNonce() external view returns (uint256) {
    return _nonce + 1;
  }
}
