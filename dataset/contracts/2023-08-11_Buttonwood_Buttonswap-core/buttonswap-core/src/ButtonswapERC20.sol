// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {IButtonswapERC20} from "./interfaces/IButtonswapERC20/IButtonswapERC20.sol";

contract ButtonswapERC20 is IButtonswapERC20 {
    /**
     * @inheritdoc IButtonswapERC20
     */
    string public constant name = "Buttonswap";

    /**
     * @inheritdoc IButtonswapERC20
     */
    string public constant symbol = "BTNSWP";

    /**
     * @inheritdoc IButtonswapERC20
     */
    uint8 public constant decimals = 18;

    /**
     * @inheritdoc IButtonswapERC20
     */
    uint256 public totalSupply;

    /**
     * @inheritdoc IButtonswapERC20
     */
    mapping(address => uint256) public balanceOf;

    /**
     * @inheritdoc IButtonswapERC20
     */
    mapping(address => mapping(address => uint256)) public allowance;

    /**
     * @inheritdoc IButtonswapERC20
     */
    bytes32 public immutable DOMAIN_SEPARATOR;

    /**
     * @inheritdoc IButtonswapERC20
     * @dev Value should equal `0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9` but it
     *   is recommended to verify this by checking the public method on-chain.
     */
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /**
     * @inheritdoc IButtonswapERC20
     */
    mapping(address => uint256) public nonces;

    constructor() {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    /**
     * @dev Mints `value` tokens to `to`.
     *
     * Emits a {IButtonswapERC20Events-Transfer} event.
     * @param to The account that is receiving the tokens
     * @param value The amount of tokens being created
     */
    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply + value;
        balanceOf[to] = balanceOf[to] + value;
        emit Transfer(address(0), to, value);
    }

    /**
     * @dev Burns `value` tokens from `from`.
     *
     * Emits a {IButtonswapERC20Events-Transfer} event.
     * @param from The account that is sending the tokens
     * @param value The amount of tokens being destroyed
     */
    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from] - value;
        totalSupply = totalSupply - value;
        emit Transfer(from, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the caller's tokens.
     *
     * Emits a {IButtonswapERC20Events-Approval} event.
     * @param owner The account whose tokens are being approved
     * @param spender The account that is granted permission to spend the tokens
     * @param value The amount of tokens that can be spent
     */
    function _approve(address owner, address spender, uint256 value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Moves `value` tokens from `from` to `to`.
     *
     * Emits a {IButtonswapERC20Events-Transfer} event.
     * @param from The account that is sending the tokens
     * @param to The account that is receiving the tokens
     * @param value The amount of tokens being sent
     */
    function _transfer(address from, address to, uint256 value) internal {
        balanceOf[from] = balanceOf[from] - value;
        balanceOf[to] = balanceOf[to] + value;
        emit Transfer(from, to, value);
    }

    /**
     * @inheritdoc IButtonswapERC20
     */
    function approve(address spender, uint256 value) external returns (bool success) {
        _approve(msg.sender, spender, value);
        success = true;
    }

    /**
     * @inheritdoc IButtonswapERC20
     */
    function transfer(address to, uint256 value) external returns (bool success) {
        _transfer(msg.sender, to, value);
        success = true;
    }

    /**
     * @inheritdoc IButtonswapERC20
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool success) {
        uint256 allowanceFromSender = allowance[from][msg.sender];
        if (allowanceFromSender != type(uint256).max) {
            allowance[from][msg.sender] = allowanceFromSender - value;
            emit Approval(from, msg.sender, allowanceFromSender - value);
        }
        _transfer(from, to, value);
        success = true;
    }

    /**
     * @inheritdoc IButtonswapERC20
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        if (block.timestamp > deadline) {
            revert PermitExpired();
        }
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != owner) {
            revert PermitInvalidSignature();
        }
        _approve(owner, spender, value);
    }
}
