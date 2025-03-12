// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@account-abstraction/contracts/core/BaseAccount.sol";
import "@account-abstraction/contracts/samples/callback/TokenCallbackHandler.sol";
import "../../interfaces/ISecp256r1.sol";
import "../../interfaces/IDkimVerifier.sol";

/**
 * minimal p256 account.
 *  this is sample minimal p256 account.
 *  has execute, eth handling methods
 *  has a single signer that can send requests through the entryPoint.
 */
contract P256Account is BaseAccount, TokenCallbackHandler, UUPSUpgradeable, Initializable {
    uint256[50] private __gap;

    using ECDSA for bytes32;

    bytes32 public email;
    bytes public publicKey;
    mapping(bytes32 => bool) public nullifierHashes;

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    IEntryPoint private immutable _entryPoint;
    ISecp256r1 private immutable _validator;
    IDkimVerifier private immutable _dkimVerifier;

    event P256AccountInitialized(
        IEntryPoint indexed entryPoint,
        ISecp256r1 validator,
        IDkimVerifier verifier,
        bytes publicKey
    );
    event EmailGuardianAdded(bytes32 email);
    event AccountRecovered(bytes publicKey);

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    modifier onlyEntryPoint() {
        _onlyEntryPoint();
        _;
    }

    function _onlyEntryPoint() internal view {
        require(msg.sender == address(entryPoint()), "account: not EntryPoint");
    }

    constructor(
        IEntryPoint anEntryPoint,
        ISecp256r1 aSecp256r1,
        IDkimVerifier aDkimVerifier
    ) {
        _entryPoint = anEntryPoint;
        _validator = aSecp256r1;
        _dkimVerifier = aDkimVerifier;
    }

    /**
     * execute a transaction
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external onlyEntryPoint {
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transaction
     */
    function executeBatch(
        address[] calldata dest,
        uint256[] calldata values,
        bytes[] calldata func
    ) external onlyEntryPoint {
        require(dest.length == values.length && dest.length == func.length, "wrong array lengths");
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], values[i], func[i]);
        }
    }

    function initialize(bytes calldata _publicKey) public virtual initializer {
        _initialize(_publicKey);
    }

    function _initialize(bytes calldata _publicKey) internal virtual {
        publicKey = _publicKey;

        emit P256AccountInitialized(_entryPoint, _validator, _dkimVerifier, _publicKey);
    }

    /// implement template method of BaseAccount
    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        override
        returns (uint256 sigTimeRange)
    {
        if (
            !_validator.validateSignature(
                sha256(abi.encode(userOpHash)),
                userOp.signature,
                publicKey
            )
        ) {
            return SIG_VALIDATION_FAILED;
        }
        return 0;
    }

    function _call(
        address target,
        uint256 value,
        bytes memory data
    ) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * check current account deposit in the entryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * deposit more funds for this account in the entryPoint
     */
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(address payable withdrawAddress, uint256 amount) public {
        require(address(this) == msg.sender, "only owner");
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    function addEmailGuardian(bytes32 _email) external {
        require(address(this) == msg.sender, "only owner");
        email = _email;
        emit EmailGuardianAdded(_email);
    }

    function recovery(
        bytes32 server,
        bytes calldata data,
        bytes calldata signature,
        bytes calldata pubkey
    ) external {
        bytes32 hash = keccak256(data);
        require(!nullifierHashes[hash], "used email data");
        bytes memory from = _dkimVerifier.from(data);
        require(email == keccak256(from), "error email owner");
        require(_dkimVerifier.verify(server, data, signature), "error dkim signature");
        bytes memory subject = _dkimVerifier.subject(data);
        require(
            keccak256(subject) == keccak256(subjectHex("01", pubkey)),
            "error email type or pubkey"
        );

        publicKey = pubkey;
        nullifierHashes[hash] = true;
        emit AccountRecovered(publicKey);
    }

    function _authorizeUpgrade(
        address /*newImplementation*/
    ) internal virtual override {
        _onlyEntryPoint();
    }

    // format: type + chainid + account_address + pubkey
    function subjectHex(string memory typ, bytes memory pubkey) public view returns (bytes memory) {
        bytes memory converted = new bytes(pubkey.length * 2);
        bytes memory _base = "0123456789abcdef";

        for (uint256 i = 0; i < pubkey.length; i++) {
            converted[i * 2] = _base[uint8(pubkey[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(pubkey[i]) % _base.length];
        }

        return
            abi.encodePacked(
                typ,
                Strings.toString(block.chainid),
                Strings.toHexString(address(this)),
                converted
            );
    }
}
