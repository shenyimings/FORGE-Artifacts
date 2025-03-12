// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ILight.sol";

/**
 * @title AirSwap Light: Atomic Swap between Tokens
 * Ported from Airswap to add support for sending ERC1155 tokens and removing fee logic.
 * @notice https://www.airswap.io/
 */
contract Light is ILight, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            abi.encodePacked(
                "EIP712Domain(",
                "string name,",
                "string version,",
                "uint256 chainId,",
                "address verifyingContract",
                ")"
            )
        );

    bytes32 public constant LIGHT_ORDER_TYPEHASH =
        keccak256(
            abi.encodePacked(
                "LightOrder(",
                "uint256 nonce,",
                "uint256 expiry,",
                "address signerWallet,",
                "address signerToken,",
                "uint256 signerAmount,",
                "address senderWallet,",
                "address senderToken,",
                "uint256 senderTokenId,",
                "uint256 senderAmount",
                ")"
            )
        );

    bytes32 public constant DOMAIN_NAME = keccak256("SWAP_LIGHT_1155");
    bytes32 public constant DOMAIN_VERSION = keccak256("1");
    uint256 public immutable DOMAIN_CHAIN_ID;
    bytes32 public immutable DOMAIN_SEPARATOR;

    /**
     * @dev Double mapping of signers to nonce groups to nonce states
     * @dev The nonce group is computed as nonce / 256, so each group of 256 sequential nonces uses the same key
     * @dev The nonce states are encoded as 256 bits, for each nonce in the group 0 means available and 1 means used
     */
    mapping(address => mapping(uint256 => uint256)) internal _nonceGroups;

    mapping(address => address) public override authorized;

    constructor() {
        uint256 currentChainId = getChainId();
        DOMAIN_CHAIN_ID = currentChainId;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                DOMAIN_NAME,
                DOMAIN_VERSION,
                currentChainId,
                this
            )
        );
    }

    /**
     * @notice Atomic ERC20/IERC1155 Swap
     * @param nonce uint256 Unique and should be sequential
     * @param expiry uint256 Expiry in seconds since 1 January 1970
     * @param signerWallet address Wallet of the signer
     * @param signerToken address ERC20 token transferred from the signer
     * @param signerAmount uint256 Amount transferred from the signer
     * @param senderToken address ERC1155 token transferred from the sender
     * @param senderAmount uint256 Amount transferred from the sender
     * @param v uint8 "v" value of the ECDSA signature
     * @param r bytes32 "r" value of the ECDSA signature
     * @param s bytes32 "s" value of the ECDSA signature
     */
    function swap(
        uint256 nonce,
        uint256 expiry,
        address signerWallet,
        address signerToken,
        uint256 signerAmount,
        address senderToken,
        uint256 senderTokenId,
        uint256 senderAmount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        swapWithRecipient(
            msg.sender,
            nonce,
            expiry,
            signerWallet,
            signerToken,
            signerAmount,
            senderToken,
            senderTokenId,
            senderAmount,
            v,
            r,
            s
        );
    }

    /**
     * @notice Authorize a signer
     * @param signer address Wallet of the signer to authorize
     * @dev Emits an Authorize event
     */
    function authorize(address signer) external override {
        authorized[msg.sender] = signer;
        emit Authorize(signer, msg.sender);
    }

    /**
     * @notice Revoke authorization of a signer
     * @dev Emits a Revoke event
     */
    function revoke() external override {
        address tmp = authorized[msg.sender];
        delete authorized[msg.sender];
        emit Revoke(tmp, msg.sender);
    }

    /**
     * @notice Cancel one or more nonces
     * @dev Cancelled nonces are marked as used
     * @dev Emits a Cancel event
     * @dev Out of gas may occur in arrays of length > 400
     * @param nonces uint256[] List of nonces to cancel
     */
    function cancel(uint256[] calldata nonces) external override {
        for (uint256 i = 0; i < nonces.length; i++) {
            uint256 nonce = nonces[i];
            if (_markNonceAsUsed(msg.sender, nonce)) {
                emit Cancel(nonce, msg.sender);
            }
        }
    }

    /**
     * @notice Atomic ERC20/IERC1155 Swap with Recipient
     * @param recipient Wallet of the recipient
     * @param nonce uint256 Unique and should be sequential
     * @param expiry uint256 Expiry in seconds since 1 January 1970
     * @param signerWallet address Wallet of the signer
     * @param signerToken address ERC20 token transferred from the signer
     * @param signerAmount uint256 Amount transferred from the signer
     * @param senderToken address IERC1155 token transferred from the sender
     * @param senderAmount uint256 Amount transferred from the sender
     * @param v uint8 "v" value of the ECDSA signature
     * @param r bytes32 "r" value of the ECDSA signature
     * @param s bytes32 "s" value of the ECDSA signature
     */
    function swapWithRecipient(
        address recipient,
        uint256 nonce,
        uint256 expiry,
        address signerWallet,
        address signerToken,
        uint256 signerAmount,
        address senderToken,
        uint256 senderTokenId,
        uint256 senderAmount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override nonReentrant {
        require(DOMAIN_CHAIN_ID == getChainId(), "CHAIN_ID_CHANGED");

        // Ensure the expiry is not passed
        require(expiry > block.timestamp, "EXPIRY_PASSED");

        bytes32 hashed = _getOrderHash(
            nonce,
            expiry,
            signerWallet,
            signerToken,
            signerAmount,
            msg.sender,
            senderToken,
            senderTokenId,
            senderAmount
        );

        // Recover the signatory from the hash and signature
        address signatory = _getSignatory(hashed, v, r, s);

        // Ensure the nonce is not yet used and if not mark it used
        require(_markNonceAsUsed(signatory, nonce), "NONCE_ALREADY_USED");

        // Ensure the signatory is authorized by the signer wallet
        if (signerWallet != signatory) {
            require(authorized[signerWallet] == signatory, "UNAUTHORIZED");
        }

        // Transfer token from sender to signer
        IERC1155(senderToken).safeTransferFrom(
            msg.sender,
            signerWallet,
            senderTokenId,
            senderAmount,
            bytes("")
        );

        // Transfer token from signer to recipient
        IERC20(signerToken).safeTransferFrom(
            signerWallet,
            recipient,
            signerAmount
        );

        // Emit a Swap event
        emit Swap(
            nonce,
            block.timestamp,
            signerWallet,
            signerToken,
            signerAmount,
            msg.sender,
            senderToken,
            senderTokenId,
            senderAmount
        );
    }

    /**
     * @notice Returns true if the nonce has been used
     * @param signer address Address of the signer
     * @param nonce uint256 Nonce being checked
     */
    function nonceUsed(address signer, uint256 nonce)
        public
        view
        override
        returns (bool)
    {
        uint256 groupKey = nonce / 256;
        uint256 indexInGroup = nonce % 256;
        return (_nonceGroups[signer][groupKey] >> indexInGroup) & 1 == 1;
    }

    /**
     * @notice Returns the current chainId using the chainid opcode
     * @return id uint256 The chain id
     */
    function getChainId() public view returns (uint256 id) {
        // no-inline-assembly
        assembly {
            id := chainid()
        }
    }

    /**
     * @notice Marks a nonce as used for the given signer
     * @param signer address Address of the signer for which to mark the nonce as used
     * @param nonce uint256 Nonce to be marked as used
     * @return bool True if the nonce was not marked as used already
     */
    function _markNonceAsUsed(address signer, uint256 nonce)
        internal
        returns (bool)
    {
        uint256 groupKey = nonce / 256;
        uint256 indexInGroup = nonce % 256;
        uint256 group = _nonceGroups[signer][groupKey];

        // If it is already used, return false
        if ((group >> indexInGroup) & 1 == 1) {
            return false;
        }

        _nonceGroups[signer][groupKey] = group | (uint256(1) << indexInGroup);

        return true;
    }

    /**
     * @notice Recover the signatory from a signature
     * @param hash bytes32
     * @param v uint8
     * @param r bytes32
     * @param s bytes32
     */
    function _getSignatory(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hash)
        );
        address signatory = ecrecover(digest, v, r, s);
        // Ensure the signatory is not null
        require(signatory != address(0), "INVALID_SIG");
        return signatory;
    }

    /**
     * @notice Hash order parameters
     * @param nonce uint256
     * @param expiry uint256
     * @param signerWallet address
     * @param signerToken address
     * @param signerAmount uint256
     * @param senderToken address
     * @param senderAmount uint256
     * @return bytes32
     */
    function _getOrderHash(
        uint256 nonce,
        uint256 expiry,
        address signerWallet,
        address signerToken,
        uint256 signerAmount,
        address senderWallet,
        address senderToken,
        uint256 senderTokenId,
        uint256 senderAmount
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    LIGHT_ORDER_TYPEHASH,
                    nonce,
                    expiry,
                    signerWallet,
                    signerToken,
                    signerAmount,
                    senderWallet,
                    senderToken,
                    senderTokenId,
                    senderAmount
                )
            );
    }
}
