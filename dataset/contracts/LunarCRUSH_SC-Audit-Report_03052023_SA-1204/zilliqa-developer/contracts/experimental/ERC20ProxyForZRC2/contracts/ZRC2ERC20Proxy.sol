// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ScillaConnector} from "./ScillaConnector.sol";

contract ZRC2ERC20Proxy is IERC20 {
    using ScillaConnector for address;
    using SafeCast for uint256;

    address immutable public zrc2_proxy;

    // Additional variables useful for wallets
    uint8 immutable public decimals;
    string public symbol;
    string public name;

    /**
     * @notice Constructs a new ZRC2Proxy contract
     * @param zrc2_address The address of the underlying ZRC2 contract
     */
    constructor(address zrc2_address) {
        zrc2_proxy = zrc2_address;

        symbol = zrc2_proxy.readString("symbol");
        decimals = uint256(zrc2_proxy.readUint32("decimals")).toUint8();
        name = zrc2_proxy.readString("name");
    }

    /**
     * @notice Get the total supply of tokens
     * @return The total supply of tokens
     */
    function totalSupply() external view returns (uint256) {
        return zrc2_proxy.readUint128("total_supply");
    }

    /**
     * @notice Get the token balance for a specific account
     * @param tokenOwner The address of the account
     * @return The balance of the account
     */
    function balanceOf(address tokenOwner) external view returns (uint256) {
        return zrc2_proxy.readMapUint128("balances", tokenOwner);
    }

    /**
     * @notice Transfer tokens to a specified address
     * @param to The address to transfer to
     * @param tokens The amount of tokens to transfer
     * @return true if transfer was successful
     */
    function transfer(address to, uint256 tokens) external returns (bool) {
        zrc2_proxy.call("Transfer", to, tokens.toUint128());
        return true;
    }

    function _transferFrom(
        address from,
        address to,
        uint256 tokens
    ) internal returns (bool) {
        zrc2_proxy.call("TransferFrom", from, to, tokens.toUint128());
        return true;
    }

    /**
     * @notice Transfer tokens from one address to another
     * @param from The address to transfer from
     * @param to The address to transfer to
     * @param tokens The amount of tokens to transfer
     * @return true if transfer was successful
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokens
    ) external returns (bool) {
        _transferFrom(from, to, tokens);
        return true;
    }

    /**
     * @notice Check the amount of tokens that an owner has allowed a spender to use
     * @param tokenOwner The address of the token owner
     * @param spender The address of the spender
     * @return The amount of tokens remaining for the spender
     */
    function allowance(
        address tokenOwner,
        address spender
    ) external view returns (uint256) {
        return
            zrc2_proxy.readNestedMapUint128("allowances", tokenOwner, spender);
    }

    /**
     * @notice Approve a spender to spend a certain amount of tokens
     * @param spender The address of the spender
     * @param new_allowance The new allowance for the spender
     * @return true if approval was successful
     */
    function approve(
        address spender,
        uint256 new_allowance
    ) external returns (bool) {
        uint256 current_allowance = this.allowance(msg.sender, spender);

        if (current_allowance >= new_allowance) {
            zrc2_proxy.call(
                "DecreaseAllowance",
                spender,
                (current_allowance - new_allowance).toUint128()
            );
        } else {
            zrc2_proxy.call(
                "IncreaseAllowance",
                spender,
                (new_allowance - current_allowance).toUint128()
            );
        }
        return true;
    }
}
