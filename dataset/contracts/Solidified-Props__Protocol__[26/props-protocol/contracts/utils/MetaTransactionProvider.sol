// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

/**
 * @title  MetaTransactionProvider
 * @author Forked from: Biconomy
 *         Changes by: Props
 * @dev    Provides native meta-transactions support to inheriting contracts.
 *         It supports two different domain separators, one for the root chain
 *         and the other for the child chain. The root chain domain separator
 *         acts as a workaround for users having to switch networks when
 *         interacting with an L2 instance of the contracts.
 */
abstract contract MetaTransactionProvider is Initializable {
    using SafeMathUpgradeable for uint256;

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    struct MetaTransaction {
        uint256 nonce;
        address from;
        bytes callData;
        uint256 deadline;
    }

    /**************************************
                     FIELDS
    ***************************************/

    // solhint-disable-next-line var-name-mixedcase
    uint256 public ROOT_CHAIN_ID;
    // solhint-disable-next-line var-name-mixedcase
    bytes32 public DOMAIN_SEPARATOR_L1;
    // solhint-disable-next-line var-name-mixedcase
    bytes32 public DOMAIN_SEPARATOR_L2;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 public META_TRANSACTION_TYPEHASH;

    mapping(address => uint256) public nonces;

    /**************************************
                     EVENTS
    ***************************************/

    event MetaTransactionExecuted(address from, address relayer, bytes callData);

    /***************************************
                   INITIALIZER
    ****************************************/

    // solhint-disable-next-line func-name-mixedcase
    function __MetaTransactionProvider_init(string memory _name, string memory _version)
        internal
        initializer
    {
        // The root chain id must correspond to the chain id of the underlying root Ethereum network (either mainnet or testnet)
        // This way, users won't have to change networks in order to be able to sign transactions
        ROOT_CHAIN_ID = 1;

        DOMAIN_SEPARATOR_L1 = keccak256(
            abi.encode(
                // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                keccak256(bytes(_name)),
                keccak256(bytes(_version)),
                ROOT_CHAIN_ID,
                address(this)
            )
        );

        DOMAIN_SEPARATOR_L2 = keccak256(
            abi.encode(
                // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                keccak256(bytes(_name)),
                keccak256(bytes(_version)),
                _getChainId(),
                address(this)
            )
        );

        // keccak256("MetaTransaction(uint256 nonce,address from,bytes callData,uint256 deadline)")
        META_TRANSACTION_TYPEHASH = 0x7711d7a2f53160a6cdce3fa7984799eba474a9075435604e9cc927b3c4ce0b0f;
    }

    /**
     * @dev Execute a meta-transaction.
     * @param _from The actual transaction sender
     * @param _callData The ABI-encoded calldata
     * @param _deadline The deadline for the sender's signature
     * @param _v Part of the signature
     * @param _r Part of the signature
     * @param _s Part of the signature
     */
    function executeMetaTransaction(
        address _from,
        bytes memory _callData,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public payable returns (bytes memory) {
        require(_deadline >= block.timestamp, "Signature expired");

        bytes4 destinationFunctionSignature = _convertBytesToBytes4(_callData);
        require(destinationFunctionSignature != msg.sig, "Invalid function signature");

        MetaTransaction memory metaTransaction =
            MetaTransaction({
                nonce: nonces[_from],
                from: _from,
                callData: _callData,
                deadline: _deadline
            });

        // We allow either L1 or L2 signatures
        require(
            _verify(DOMAIN_SEPARATOR_L1, _from, metaTransaction, _v, _r, _s) ||
                _verify(DOMAIN_SEPARATOR_L2, _from, metaTransaction, _v, _r, _s),
            "Invalid signature"
        );
        nonces[_from]++;

        // Append `_from` at the end to extract it from calling context
        (bool success, bytes memory returnData) =
            // solhint-disable-next-line avoid-low-level-calls
            address(this).call(abi.encodePacked(_callData, _from));
        require(success, "Unsuccessfull call");

        emit MetaTransactionExecuted(_from, msg.sender, _callData);
        return returnData;
    }

    /***************************************
                     HELPERS
    ****************************************/

    function _msgSender() internal view virtual returns (address payable sender) {
        if (msg.sender == address(this)) {
            return _extractMsgSender();
        }
        return msg.sender;
    }

    function _extractMsgSender() internal pure returns (address payable sender) {
        bytes memory array = msg.data;
        uint256 index = msg.data.length;

        assembly {
            // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those
            sender := and(mload(add(array, index)), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }

    function _toEIP712Digest(bytes32 _domainSeparator, bytes32 _messageDigest)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator, _messageDigest));
    }

    function _convertBytesToBytes4(bytes memory _inBytes) internal pure returns (bytes4 outBytes) {
        if (_inBytes.length == 0) {
            return 0x0;
        }

        assembly {
            outBytes := mload(add(_inBytes, 32))
        }
    }

    function _verify(
        bytes32 _domainSeparator,
        address _from,
        MetaTransaction memory _metaTransaction,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal view returns (bool) {
        address signer =
            ecrecover(
                _toEIP712Digest(_domainSeparator, _hashMetaTransaction(_metaTransaction)),
                _v,
                _r,
                _s
            );
        return signer != address(0) && signer == _from;
    }

    function _hashMetaTransaction(MetaTransaction memory _metaTransaction)
        internal
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    META_TRANSACTION_TYPEHASH,
                    _metaTransaction.nonce,
                    _metaTransaction.from,
                    keccak256(_metaTransaction.callData),
                    _metaTransaction.deadline
                )
            );
    }

    function _getChainId() internal pure returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }
}
