pragma solidity ^0.8.0;

import "./interfaces/IKeyManager.sol";
import "./abstract/SchnorrSECP256K1.sol";
import "./abstract/Shared.sol";

/**
 * @title    KeyManager contract
 * @notice   Holds the aggregate and governance keys, functions to update them,
 *           and consumeKeyNonce so other contracts can verify signatures and updates _lastValidateTime
 */
contract KeyManager is SchnorrSECP256K1, Shared, IKeyManager {
    uint256 private constant _AGG_KEY_TIMEOUT = 2 days;

    /// @dev    The current (schnorr) aggregate key.
    Key private _aggKey;
    /// @dev    The current governance key.
    address private _govKey;
    /// @dev    The current community key.
    address private _commKey;
    /// @dev    The last time that a sig was verified (used for a dead man's switch)
    uint256 private _lastValidateTime;
    mapping(uint256 => bool) private _isNonceUsedByAggKey;
    /// @dev    Whitelist for who can call canConsumeNonce
    mapping(address => bool) private _canConsumeKeyNonce;
    bool private _canConsumeKeyNonceSet;
    uint256 private _numberWhitelistedAddresses;

    constructor(
        Key memory initialAggKey,
        address initialGovKey,
        address initialCommKey
    ) nzAddr(initialGovKey) nzAddr(initialCommKey) nzKey(initialAggKey) validAggKey(initialAggKey) {
        _aggKey = initialAggKey;
        _govKey = initialGovKey;
        _commKey = initialCommKey;
        _lastValidateTime = block.timestamp;
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                  State-changing functions                //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Sets the specific addresses that can call consumeKeyNonce.
     *          Deployed via Deploy.sol so it can't be frontrun. The FLIP
     *          address can only be set once.
     * @param addrs   The addresses to whitelist
     */
    function setCanConsumeKeyNonce(address[] calldata addrs) external override {
        require(!_canConsumeKeyNonceSet, "KeyManager: already set");
        _canConsumeKeyNonceSet = true;

        for (uint256 i = 0; i < addrs.length; i++) {
            // Avoid duplicated newAddrs. Otherwise we could brick the updateCanConsumeKeyNonce
            // since it relies on the _numberWhitelistedAddresses and it has this check
            require(!_canConsumeKeyNonce[addrs[i]], "KeyManager: address already whitelisted");
            _canConsumeKeyNonce[addrs[i]] = true;
        }

        _numberWhitelistedAddresses = addrs.length;

        emit AggKeyNonceConsumersSet(addrs);
    }

    /**
     * @notice  Replaces all the addresses that can call consumeKeyNonce. Must delist all addresses and then
                add an arbitrary number of new addresses. To be used if any other contracts is updated.
     * @param currentAddrs   List of current whitelisted addresses
     * @param newAddrs   List of new addresses to whitelist
     */
    function updateCanConsumeKeyNonce(
        SigData calldata sigData,
        address[] calldata currentAddrs,
        address[] calldata newAddrs
    )
        external
        override
        consumesKeyNonce(
            sigData,
            keccak256(
                abi.encodeWithSelector(
                    this.updateCanConsumeKeyNonce.selector,
                    SigData(sigData.keyManAddr, sigData.chainID, 0, 0, sigData.nonce, address(0)),
                    currentAddrs,
                    newAddrs
                )
            )
        )
    {
        require(currentAddrs.length == _numberWhitelistedAddresses, "KeyManager: array incorrect length");

        // Remove current whitelisted addresses
        for (uint256 i = 0; i < currentAddrs.length; i++) {
            require(_canConsumeKeyNonce[currentAddrs[i]], "KeyManager: cannot dewhitelist");
            _canConsumeKeyNonce[currentAddrs[i]] = false;
        }

        //  Whitelist any number of new addresses
        for (uint256 i = 0; i < newAddrs.length; i++) {
            // Avoid duplicated newAddrs
            require(!_canConsumeKeyNonce[newAddrs[i]], "KeyManager: address already whitelisted");
            _canConsumeKeyNonce[newAddrs[i]] = true;
        }

        _numberWhitelistedAddresses = newAddrs.length;

        emit AggKeyNonceConsumersUpdated(currentAddrs, newAddrs);
    }

    /**
     * @notice  Checks the validity of a signature and msgHash, then updates _lastValidateTime
     * @dev     It would be nice to split this up, but these checks
     *          need to be made atomicly always. This needs to be available
     *          in this contract and in the Vault etc
     * @param sigData   The keccak256 hash over the msg (uint256) (here that's normally
     *                  a hash over the calldata to the function with an empty sigData)
     *                  from the current aggregate key (uint256)
     * @param contractMsgHash   The hash of the thing being signed but generated by the contract
     *                  to check it against the hash in sigData (bytes32) (here that's normally
     *                  a hash over the calldata to the function with an empty sigData)
     */
    function _consumeKeyNonce(SigData calldata sigData, bytes32 contractMsgHash) internal {
        Key memory key = _aggKey;
        // We require the msgHash param in the sigData is equal to the contract
        // message hash (the rules coded into the contract)
        require(sigData.msgHash == uint256(contractMsgHash), "KeyManager: invalid msgHash");
        require(
            verifySignature(sigData.msgHash, sigData.sig, key.pubKeyX, key.pubKeyYParity, sigData.kTimesGAddress),
            "KeyManager: Sig invalid"
        );
        require(!_isNonceUsedByAggKey[sigData.nonce], "KeyManager: nonce already used");
        require(sigData.keyManAddr == address(this), "KeyManager: wrong keyManAddr");
        require(sigData.chainID == block.chainid, "KeyManager: wrong chainID");

        _lastValidateTime = block.timestamp;
        _isNonceUsedByAggKey[sigData.nonce] = true;

        // Disable because tx.origin is not being used in the logic
        // solhint-disable-next-line avoid-tx-origin
        emit SignatureAccepted(sigData, tx.origin);
    }

    /**
     * @notice  Checks that the msg.sender is whitelisted before verifying the signature.
     * @dev     Split this function from consumeKeyNonceWhitelisted so the functions in this contract
     *          can skip the whitelisting check.
     */
    function consumeKeyNonce(SigData calldata sigData, bytes32 contractMsgHash) external override {
        require(_canConsumeKeyNonce[msg.sender], "KeyManager: not whitelisted");
        _consumeKeyNonce(sigData, contractMsgHash);
    }

    /**
     * @notice  Set a new aggregate key. Requires a signature from the current aggregate key
     * @param sigData   The keccak256 hash over the msg (uint256) (which is the calldata
     *                  for this function with empty msgHash and sig) and sig over that hash
     *                  from the current aggregate key (uint256)
     * @param newAggKey The new aggregate key to be set. The x component of the pubkey (uint256),
     *                  the parity of the y component (uint8)
     */
    function setAggKeyWithAggKey(
        SigData calldata sigData,
        Key calldata newAggKey
    )
        external
        override
        nzKey(newAggKey)
        validAggKey(newAggKey)
        consumesKeyNonce(
            sigData,
            keccak256(
                abi.encodeWithSelector(
                    this.setAggKeyWithAggKey.selector,
                    SigData(sigData.keyManAddr, sigData.chainID, 0, 0, sigData.nonce, address(0)),
                    newAggKey
                )
            )
        )
    {
        emit AggKeySetByAggKey(_aggKey, newAggKey);
        _aggKey = newAggKey;
    }

    /**
     * @notice  Set a new aggregate key. Can only be called by the current governance key
     * @param newAggKey The new aggregate key to be set. The x component of the pubkey (uint256),
     *                  the parity of the y component (uint8)
     */
    function setAggKeyWithGovKey(
        Key calldata newAggKey
    ) external override nzKey(newAggKey) validAggKey(newAggKey) timeoutEmergency onlyGovernor {
        emit AggKeySetByGovKey(_aggKey, newAggKey);
        _aggKey = newAggKey;
    }

    /**
     * @notice  Set a new aggregate key. Requires a signature from the current aggregate key
     * @param sigData   The keccak256 hash over the msg (uint256) (which is the calldata
     *                  for this function with empty msgHash and sig) and sig over that hash
     *                  from the current aggregate key (uint256)
     * @param newGovKey The new governance key to be set.

     */
    function setGovKeyWithAggKey(
        SigData calldata sigData,
        address newGovKey
    )
        external
        override
        nzAddr(newGovKey)
        consumesKeyNonce(
            sigData,
            keccak256(
                abi.encodeWithSelector(
                    this.setGovKeyWithAggKey.selector,
                    SigData(sigData.keyManAddr, sigData.chainID, 0, 0, sigData.nonce, address(0)),
                    newGovKey
                )
            )
        )
    {
        emit GovKeySetByAggKey(_govKey, newGovKey);
        _govKey = newGovKey;
    }

    /**
     * @notice  Set a new governance key. Can only be called by current governance key
     * @param newGovKey    The new governance key to be set.
     */
    function setGovKeyWithGovKey(address newGovKey) external override nzAddr(newGovKey) onlyGovernor {
        emit GovKeySetByGovKey(_govKey, newGovKey);
        _govKey = newGovKey;
    }

    /**
     * @notice  Set a new community key. Requires a signature from the current aggregate key
     * @param sigData   The keccak256 hash over the msg (uint256) (which is the calldata
     *                  for this function with empty msgHash and sig) and sig over that hash
     *                  from the current aggregate key (uint256)
     * @param newCommKey The new community key to be set.

     */
    function setCommKeyWithAggKey(
        SigData calldata sigData,
        address newCommKey
    )
        external
        override
        nzAddr(newCommKey)
        consumesKeyNonce(
            sigData,
            keccak256(
                abi.encodeWithSelector(
                    this.setCommKeyWithAggKey.selector,
                    SigData(sigData.keyManAddr, sigData.chainID, 0, 0, sigData.nonce, address(0)),
                    newCommKey
                )
            )
        )
    {
        emit CommKeySetByAggKey(_commKey, newCommKey);
        _commKey = newCommKey;
    }

    /**
     * @notice  Update the Community Key. Can only be called by the current Community Key.
     * @param newCommKey   New Community key address.
     */
    function setCommKeyWithCommKey(address newCommKey) external override onlyCommunityKey nzAddr(newCommKey) {
        emit CommKeySetByCommKey(_commKey, newCommKey);
        _commKey = newCommKey;
    }

    /**
     * @notice Withdraw any native tokens on this contract. The intended execution of this contract doesn't
     * require any native tokens. This function is just to recover any tokens that might have been sent to
     * this contract by accident (or any other reason).
     */
    function govWithdrawNative() external override onlyGovernor {
        uint256 amount = address(this).balance;

        // Could use msg.sender but hardcoding the get call just for extra safety
        address recipient = _getGovernanceKey();
        payable(recipient).transfer(amount);
    }

    /**
     * @notice Emit an event containing an action message. Can only be called by the governor.
     */
    function govAction(bytes32 message) external override onlyGovernor {
        emit GovernanceAction(message);
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                  Non-state-changing functions            //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Get the current aggregate key
     * @return  The Key struct for the aggregate key
     */
    function getAggregateKey() external view override returns (Key memory) {
        return _aggKey;
    }

    /**
     * @notice  Get the current governance key
     * @return  The Key struct for the governance key
     */
    function getGovernanceKey() external view override returns (address) {
        return _getGovernanceKey();
    }

    /**
     * @notice  Get the current community key
     * @return  The Key struct for the community key
     */
    function getCommunityKey() external view override returns (address) {
        return _getCommunityKey();
    }

    /**
     * @notice  Get the last time that a function was called which
     *          required a signature from _aggregateKeyData or _governanceKeyData
     * @return  The last time consumeKeyNonce was called, in unix time (uint256)
     */
    function getLastValidateTime() external view override returns (uint256) {
        return _lastValidateTime;
    }

    /**
     * @notice  Get whether or not the specific keyID has used this nonce before
     *          since it cannot be used again
     * @return  Whether the nonce has already been used (bool)
     */
    function isNonceUsedByAggKey(uint256 nonce) external view override returns (bool) {
        return _isNonceUsedByAggKey[nonce];
    }

    /**
     * @notice  Get whether addr is whitelisted for validating a sig
     * @param addr  The address to check
     * @return  Whether or not addr is whitelisted or not
     */
    function canConsumeKeyNonce(address addr) external view override returns (bool) {
        return _canConsumeKeyNonce[addr];
    }

    /**
     * @notice  Get whether or not _canConsumeKeyNonce has already been set, which
     *          prevents it from being set again
     * @return  The value of _canConsumeKeyNonceSet
     */
    function canConsumeKeyNonceSet() external view override returns (bool) {
        return _canConsumeKeyNonceSet;
    }

    /**
     * @notice  Get number of whitelisted addresses
     * @return  The value of _numberWhitelistedAddresses
     */
    function getNumberWhitelistedAddresses() external view override returns (uint256) {
        return _numberWhitelistedAddresses;
    }

    /**
     *  @notice Allows this contract to receive native
     */
    receive() external payable {}

    /**
     * @notice  Get the current governance key
     * @return  The Key struct for the governance key
     */
    function _getGovernanceKey() internal view returns (address) {
        return _govKey;
    }

    /**
     * @notice  Get the current community key
     * @return  The Key struct for the community key
     */
    function _getCommunityKey() internal view returns (address) {
        return _commKey;
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                          Modifiers                       //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /// @dev    Check that enough time has passed for setAggKeyWithGovKey. Needs
    ///         to be done as a modifier so that it can happen before consumeKeyNonce
    modifier timeoutEmergency() {
        require(block.timestamp - _lastValidateTime >= _AGG_KEY_TIMEOUT, "KeyManager: not enough time");
        _;
    }

    /// @dev    Check that an aggregate key is capable of having its signatures
    ///         verified by the schnorr lib.
    modifier validAggKey(Key memory key) {
        verifySigningKeyX(key.pubKeyX);
        _;
    }

    /// @dev    Check that the sender is the governance address
    modifier onlyGovernor() {
        require(msg.sender == _getGovernanceKey(), "KeyManager: not governor");
        _;
    }

    /// @dev    Check that the caller is the Community Key address.
    modifier onlyCommunityKey() {
        require(msg.sender == _getCommunityKey(), "KeyManager: not Community Key");
        _;
    }

    /// @dev    Call consumeKeyNonceWhitelisted
    modifier consumesKeyNonce(SigData calldata sigData, bytes32 contractMsgHash) {
        _consumeKeyNonce(sigData, contractMsgHash);
        _;
    }
}
