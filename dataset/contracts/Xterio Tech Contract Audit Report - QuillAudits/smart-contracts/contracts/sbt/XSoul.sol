//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./SBTUnique.sol";
import "./interfaces/IRedeemChecker.sol";

/// @title XSoul contract 
/// @dev This contract is the implementation of the XSoul SBT
contract XSoul is SBTUnique, AccessControl {
    using Counters for Counters.Counter;

    // Role definitions
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Base URI
    string private __baseURI;
    // Token ID counter
    Counters.Counter private _tokenIds;
    // RedeemChecker contract address, set to 0x0 to disable redemption
    address public redeemCheckerAddress;
    // Mapping from recipient to the timestamp of the last issued XSoul
    mapping(address => uint256) issuedTimestamp;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI,
        address _redeemCheckerAddress,
        address _admin
    ) SBTUnique(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _admin);
        redeemCheckerAddress = _redeemCheckerAddress;
        __baseURI = baseURI;
    }

    /********** Operator-only Functions **********/
    /**
     * Set the RedeemChecker contract address
     */
    function setRedeemChecker(address _redeemCheckerAddress)
        public
        onlyRole(OPERATOR_ROLE)
    {
        redeemCheckerAddress = _redeemCheckerAddress;
    }

    /**
     * Set the base URI of the token metadata 
     * @param newURI The new base URI
     */
    function setBaseURI(string memory newURI) public onlyRole(OPERATOR_ROLE) {
        __baseURI = newURI;
    }

    /**
     * Issue a new XSoul to `recipient`. Since XSoul inherits from SBTUnique, 
     * this function will revert if the recipient already has an XSoul
     * @param recipient The address to issue the XSoul to
     */
    function issueXSoul(address recipient) public onlyRole(OPERATOR_ROLE) {
        _issueXSoul(recipient);
    }

    /**
     * Revoke the XSoul with `tokenId`
     * @param tokenId The token ID to revoke
     */
    function revokeXSoul(uint256 tokenId) public onlyRole(OPERATOR_ROLE) {
        _burn(tokenId);
    }

    /********** Delegated Functions **********/
    /**
     * 
     * @param recipient The address to issue the XSoul to
     * @param signature The signature of the signer
     */
    function claimXSoul(address recipient, bytes calldata signature, uint256 expire) external {
        // 1. Check not expired
        require(expire > block.timestamp, "XSoul: signature expired");
        // 2. Check the validity of the signature
        bytes32 inputHash = _getInputHash(recipient, expire);
        address signer = _recoverSigner(inputHash, signature);
        require(
            hasRole(OPERATOR_ROLE, signer),
            "XSoul: signer does not have operator role"
        );
        // 3. issue Xsoul
        _issueXSoul(recipient);
    }

    /**
     * Check if `recipient` is qualified to redeem, if so, issue a new XSoul to `recipient`
     * @param recipient The address to issue the XSoul to
     */
    function redeemXSoul(address recipient) external {
        require(
            isRedeemable(recipient),
            "XSoul: recipient is not eligible for redemption"
        );

        _issueXSoul(recipient);
    }

    /********** Internal Functions **********/
    function _baseURI() internal view override returns (string memory) {
        return __baseURI;
    }

    /**
     * Issue a new XSoul to `recipient`. Notice that XSoul inherits from SBTUnique,
     * so this function will revert if the recipient already has an XSoul
     * @param recipient The address to issue the XSoul to
     */
    function _issueXSoul(address recipient) internal {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _safeMint(recipient, newItemId);

        issuedTimestamp[recipient] = block.timestamp;
    }

    /********** Helper functions for signature verification **********/
    function _getInputHash(address recipient, uint256 expire) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(expire, recipient, block.chainid, address(this))
            );
    }

    function _recoverSigner(bytes32 hash, bytes memory sig)
        internal
        pure
        returns (address)
    {
        return ECDSA.recover(_getEthSignedMessageHash(hash), sig);
    }

    function _getEthSignedMessageHash(bytes32 criteriaMessageHash)
        internal
        pure
        returns (bytes32)
    {
        return ECDSA.toEthSignedMessageHash(criteriaMessageHash);
    }

    /********** Query Functions **********/
    function isRedeemable(address _recipient) public view returns (bool) {
        require(
            redeemCheckerAddress != address(0),
            "XSoul: Redemption has ended"
        );
        return IRedeemChecker(redeemCheckerAddress).qualified(_recipient);
    }

    /**
     * Get the timestamp of the issued XSoul to `_recipient`
     * @param _recipient The address to query
     */
    function getIssuedTime(address _recipient) public view returns (uint256) {
        return issuedTimestamp[_recipient];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(SBTUnique, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
