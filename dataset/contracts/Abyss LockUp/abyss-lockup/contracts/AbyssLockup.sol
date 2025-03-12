/*
░█████╗░██████╗░██╗░░░██╗░██████╗░██████╗  ███████╗██╗███╗░░██╗░█████╗░███╗░░██╗░█████╗░███████╗
██╔══██╗██╔══██╗╚██╗░██╔╝██╔════╝██╔════╝  ██╔════╝██║████╗░██║██╔══██╗████╗░██║██╔══██╗██╔════╝
███████║██████╦╝░╚████╔╝░╚█████╗░╚█████╗░  █████╗░░██║██╔██╗██║███████║██╔██╗██║██║░░╚═╝█████╗░░
██╔══██║██╔══██╗░░╚██╔╝░░░╚═══██╗░╚═══██╗  ██╔══╝░░██║██║╚████║██╔══██║██║╚████║██║░░██╗██╔══╝░░
██║░░██║██████╦╝░░░██║░░░██████╔╝██████╔╝  ██║░░░░░██║██║░╚███║██║░░██║██║░╚███║╚█████╔╝███████╗
╚═╝░░╚═╝╚═════╝░░░░╚═╝░░░╚═════╝░╚═════╝░  ╚═╝░░░░░╚═╝╚═╝░░╚══╝╚═╝░░╚═╝╚═╝░░╚══╝░╚════╝░╚══════╝
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Abyss Finance's AbyssLockup Contract
 * A smart contract that stores tokens requested for withdrawal, as well as through which tokens are transferred from/to user and between contracts.
 */
contract AbyssLockup is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public safeContract1;
    address public safeContract3;
    address public safeContract6;
    address public safeContract12;
    uint256 private _freeDeposits;

    struct Token {
        uint256 deposited;
        uint256 divFactor;
    }

    mapping (address => Token) private _tokens;

    constructor(uint256 freeDeposits) public {
        _freeDeposits = freeDeposits;
    }

    // VIEW FUNCTIONS

    /**
     * @dev See {IAbyssLockup-deposited}.
     */
    function deposited(address token) external view returns (uint256) {
        return _tokens[token].deposited;
    }

    /**
     * @dev See {IAbyssLockup-divFactor}.
     */
    function divFactor(address token) external view returns (uint256) {
        return _tokens[token].divFactor;
    }

    /**
     * @dev See {IAbyssLockup-freeDeposits}.
     */
    function freeDeposits() public view returns (uint256) {
        return _freeDeposits;
    }

    // ACTION FUNCTIONS

    /**
     * @dev See {IAbyssLockup-externalTransfer}.
     */
    function externalTransfer(address token, address sender, address recipient, uint256 amount, uint256 abyssRequired, uint256 balance, uint256 divFactor_) external onlyContract(msg.sender) returns (bool) {
        if (sender == address(this)) {
            _tokens[token].deposited = balance;
            IERC20(address(token)).safeTransfer(recipient, amount);
        } else {
            if (recipient == address(this)) {
                _tokens[token].deposited = balance;
            } else if (abyssRequired > 0) {
                _freeDeposits = SafeMath.sub(_freeDeposits, 1);
            }
            IERC20(address(token)).safeTransferFrom(sender, recipient, amount);
        }

        if (divFactor_ == 1) {
            delete _tokens[token].divFactor;
        } else if (divFactor_ > 0) {
            _tokens[token].divFactor = divFactor_;
        }

        return true;
    }

    // ADMIN FUNCTIONS

    /**
     * @dev Configurates smart contract allowing modification in the amount of
     * free deposits.
     */
    function setup(uint256 freeDeposits_) external onlyOwner returns (bool) {
        _freeDeposits = freeDeposits_;
        return true;
    }

    /**
     * @dev Initializes configuration of a given smart contract, with a specified
     * addresses for the `safeContract` smart contracts.
     *
     * All three of these values are immutable: they can only be set once.
     */
    function initialize(address safe1, address safe3, address safe6, address safe12) external onlyOwner returns (bool) {
        require(address(safeContract1) == address(0), "AbyssLockup: already initialized");
        safeContract1 = safe1;
        safeContract3 = safe3;
        safeContract6 = safe6;
        safeContract12 = safe12;
        return true;
    }

    /**
     * @dev A function that allows the `owner` to withdraw any locked and lost tokens
     * from the smart contract if such `token` is not yet deposited.
     *
     * NOTE: Embedded in the function is verification that allows for token withdrawal
     * only if the token balance is greater than the token balance requested to
     * withdrawals on all `safeContract` smart contracts.
     */
    function withdrawLostTokens(address token) external onlyOwner returns (bool) {
        uint256 _tempBalance = IERC20(address(token)).balanceOf(address(this));

        if (_tokens[token].deposited == 0 && _tempBalance > 0) {
            SafeERC20.safeTransfer(IERC20(address(token)), msg.sender, _tempBalance);
        }
        return true;
    }

    /**
     * @dev Modifier that allows usage only for `safeContract` smart contracts
    */
    modifier onlyContract(address account)  {
        require(account == address(safeContract1) || account == address(safeContract3) || account == address(safeContract6) || account == address(safeContract12), "AbyssLockup: restricted area");
        _;
    }
}
