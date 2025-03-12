// SPDX-License-Identifier: MIT

pragma solidity >=0.6.5 <0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/drafts/EIP712.sol";

import "./interfaces/IERC721Permit.sol";

/**
 * @dev Implementation of the ERC721 Permit extension allowing approvals to be made via signatures
 */
abstract contract ERC721Permit is ERC721, IERC721Permit, EIP712 {
    using Counters for Counters.Counter;

    mapping (address => Counters.Counter) private _nonces;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private immutable _PERMIT_TYPEHASH = keccak256("Permit(address signer,address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");

    /**
     * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
     *
     * It's a good idea to use the same `name` that is defined as the ERC20 token name.
     */
    constructor(string memory name) EIP712(name, "1") {
    }

    /**
     * @dev See {IERC20Permit-permit}.
     */
    function permit(address signer, address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public virtual override {
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                signer,
                spender,
                tokenId,
                _nonces[signer].current(),
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        require(ECDSA.recover(hash, v, r, s) == signer, "ERC20Permit: invalid signature");

        _nonces[signer].increment();
        
        address owner = ERC721.ownerOf(tokenId);
        require(spender != signer, "ERC721: approval to current owner");

        require(owner == signer || ERC721.isApprovedForAll(signer, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(spender, tokenId);
    }

    /**
     * @dev See {IERC20Permit-nonces}.
     */
    function nonces(address owner) public view override returns (uint256) {
        return _nonces[owner].current();
    }

    /**
     * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }
}
