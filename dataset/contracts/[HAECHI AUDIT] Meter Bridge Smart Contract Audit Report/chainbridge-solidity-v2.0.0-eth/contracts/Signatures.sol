// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.11;
import "./interfaces/IBridge.sol";
import "./utils/AccessControl.sol";
import "./utils/SafeCast.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Signatures is AccessControl {
    using SafeCast for *;
    // 0xc4cb5d35714699d6e85b9562b644e60393b418d974a5c1dd8efaadac37a142c5
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            "PermitBridge(uint8 domainID,uint64 depositNonce,bytes32 resourceID,bytes data)"
        );
    // 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f
    bytes32 public constant _TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    // 0x058443738ec3641a3233a9f285e16671e4ad9755445580d761017e695f75052b
    bytes32 private _HASHED_NAME = keccak256(bytes("PermitBridge"));
    // 0xe6bbd6277e1bf288eed5e8d1780f9a50b239e86b153736bceebccf4ea79d90b3
    bytes32 private _HASHED_VERSION = keccak256(bytes("1.0"));

    mapping(uint8 => uint8) public _relayerThreshold;
    mapping(uint8 => uint256) public destChainId;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    modifier onlyRelayers() {
        require(
            hasRole(RELAYER_ROLE, _msgSender()),
            "sender doesn't have relayer role"
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "sender doesn't have admin role"
        );
        _;
    }

    function _buildDomainSeparator(
        bytes32 typeHash,
        bytes32 nameHash,
        bytes32 versionHash,
        uint256 chainId,
        address signatureContract
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    typeHash,
                    nameHash,
                    versionHash,
                    chainId,
                    signatureContract
                )
            );
    }

    function _hashTypedDataV4(
        bytes32 structHash,
        uint256 chainId,
        address signatureContract
    ) internal view virtual returns (bytes32) {
        return
            ECDSA.toTypedDataHash(
                _buildDomainSeparator(
                    _TYPE_HASH,
                    _HASHED_NAME,
                    _HASHED_VERSION,
                    chainId,
                    signatureContract
                ),
                structHash
            );
    }

    function checkSignature(
        uint8 domainID,
        uint8 destinationDomainID,
        address destinationBridge,
        uint64 depositNonce,
        bytes32 resourceID,
        bytes calldata data,
        bytes calldata signature
    ) public view returns (address) {
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                domainID,
                depositNonce,
                resourceID,
                keccak256(data)
            )
        );
        bytes32 hash = _hashTypedDataV4(
            structHash,
            destChainId[destinationDomainID] == 0
                ? uint256(destinationDomainID)
                : destChainId[destinationDomainID],
            destinationBridge
        );
        return ECDSA.recover(hash, signature);
    }

    /// @notice depositHash = keccak256(abi.encode(originDomainID,depositNonce,resourceID,keccak256(data)));
    /// @notice depositHash => signature[]
    mapping(bytes32 => bytes[]) public signatures;
    /// @notice signature => bool
    mapping(bytes => bool) public hasVote;

    event SubmitSignature(
        uint8 indexed originDomainID,
        uint8 indexed destinationDomainID,
        uint64 depositNonce,
        bytes32 indexed resourceID,
        bytes data,
        bytes signature
    );

    event SignturePass(
        uint8 indexed originDomainID,
        uint8 indexed destinationDomainID,
        uint64 depositNonce,
        bytes32 indexed resourceID,
        bytes data,
        bytes signature
    );

    function adminChangeRelayerThreshold(
        uint8 destinationDomainID,
        uint256 newThreshold
    ) external onlyAdmin {
        _relayerThreshold[destinationDomainID] = newThreshold.toUint8();
    }

    function adminSetDestChainId(uint8 destinationDomainID, uint8 chainId)
        external
        onlyAdmin
    {
        destChainId[destinationDomainID] = chainId;
    }

    function submitSignature(
        uint8 originDomainID,
        uint8 destinationDomainID,
        address destinationBridge,
        uint64 depositNonce,
        bytes32 resourceID,
        bytes calldata data,
        bytes calldata signature
    ) external {
        require(
            hasRole(
                RELAYER_ROLE,
                checkSignature(
                    originDomainID,
                    destinationDomainID,
                    destinationBridge,
                    depositNonce,
                    resourceID,
                    data,
                    signature
                )
            ),
            "invalid signature"
        );
        require(!hasVote[signature], "signature aleardy submit");
        bytes32 depositHash = keccak256(
            abi.encode(
                originDomainID,
                depositNonce,
                resourceID,
                keccak256(data)
            )
        );
        require(
            signatures[depositHash].length <
                _relayerThreshold[destinationDomainID],
            "Signture aleardy pass"
        );
        signatures[depositHash].push(signature);
        hasVote[signature] = true;
        emit SubmitSignature(
            originDomainID,
            destinationDomainID,
            depositNonce,
            resourceID,
            data,
            signature
        );
        if (
            signatures[depositHash].length >=
            _relayerThreshold[destinationDomainID]
        ) {
            emit SignturePass(
                originDomainID,
                destinationDomainID,
                depositNonce,
                resourceID,
                data,
                signature
            );
        }
    }

    function getSignatures(
        uint8 domainID,
        uint64 depositNonce,
        bytes32 resourceID,
        bytes calldata data
    ) external view returns (bytes[] memory) {
        return
            signatures[
                keccak256(
                    abi.encode(
                        domainID,
                        depositNonce,
                        resourceID,
                        keccak256(data)
                    )
                )
            ];
    }
}
