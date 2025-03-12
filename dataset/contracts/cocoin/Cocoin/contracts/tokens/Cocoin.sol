// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Cocoin
 * @dev A contract representing the Cocoin token with fee functionalities.
 */
contract Cocoin is Context, ERC20, ERC20Burnable, Ownable {
    address public feeReceiver1; // Address #1 to receive the fees
    address public feeReceiver2; // Address #2 to receive the fees
    uint16 constant public SELL_FEE = 400; // Sell fee ratio (Default: 4%)
    mapping(address => bool) public excludedFromFees; // Fee-excluded accounts
    mapping(address => bool) public marketPairs; // Market pairs
    uint8 private _decimals = 8; // Token decimals

    event AccountFeeExcludeUpdate(address indexed account, bool state);
    event FeeReceiverAddress1Update(address indexed receiver);
    event FeeReceiverAddress2Update(address indexed receiver);
    event MarketPairUpdated(address indexed pairAddress, bool state);

    constructor(string memory name_, string memory symbol_, uint initialSupply_) ERC20(name_, symbol_) {
        feeReceiver1 = _msgSender();
        feeReceiver2 = _msgSender();
        excludedFromFees[_msgSender()] = true;
        _mint(_msgSender(), (initialSupply_ * (10 ** _decimals)));
    }

    /**
     * @dev Update the fee receiver address.
     * @param receiver The new fee receiver address.
     */
    function setFeeReceiver1(address receiver) public onlyOwner {
        require(receiver != address(0), "Receiver can't be address zero");
        if (feeReceiver1 != receiver) {
            feeReceiver1 = receiver;
            emit FeeReceiverAddress1Update(receiver);
        }
    }

    /**
     * @dev Update the reward fee receiver address.
     * @param receiver The new reward fee receiver address.
     */
    function setFeeReceiver2(address receiver) public onlyOwner {
        require(receiver != address(0), "Receiver can't be address zero");
        if (feeReceiver2 != receiver) {
            feeReceiver2 = receiver;
            emit FeeReceiverAddress2Update(receiver);
        }
    }

    /**
     * @dev Update a market pair's state.
     * @param pair The address of the market pair.
     * @param state The new state of the market pair.
     */
    function setMarketPair(address pair, bool state) public onlyOwner {
        require(pair != address(0), "Pair can't be address zero");
        if (marketPairs[pair] != state) {
            marketPairs[pair] = state;
            emit MarketPairUpdated(pair, state);
        }
    }

    /**
     * @dev Exclude or include an account from fees.
     * @param account The account to be excluded or included.
     * @param state The state of the account's fee exclusion.
     */
    function excludeFromFees(address account, bool state) public onlyOwner {
        if (excludedFromFees[account] != state) {
            excludedFromFees[account] = state;
            emit AccountFeeExcludeUpdate(account, state);
        }
    }

    /**
     * @dev Returns the number of decimals used by the token.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {ERC20-_mint}.
     */
    function _mint(address account, uint256 amount) internal virtual override {
        super._mint(account, amount);
    }

    /**
     * @dev Hook that is called before any token transfer.
     * @param from The address from which the tokens are transferred.
     * @param to The address to which the tokens are transferred.
     * @param amount The amount of tokens transferred.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Transfer tokens from one address to another with a fee deduction.
     * @param from The address from which the tokens are transferred.
     * @param to The address to which the tokens are transferred.
     * @param amount The amount of tokens to transfer.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual override(ERC20) {
        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = balanceOf(from);
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");

        bool isExcludedFromFees = excludedFromFees[from];
        uint256 taxAmount = 0;

        if (!isExcludedFromFees) {
            // If to == marketPairs::true state, then it is a sell transfer
            if (marketPairs[to]) {
                taxAmount = (amount * SELL_FEE / 10_000);
            }
        }

        if (taxAmount > 0) {
            _distributeFees(from, taxAmount);
        }

        super._transfer(from, to, (amount - taxAmount));

        _afterTokenTransfer(from, to, amount);
    }

    /**
     * @dev Distributes fees to the fee receiver wallets.
     * @param from The address from which the fees are collected.
     * @param amount The total fee amount to be distributed.
     */
    function _distributeFees(address from, uint256 amount) internal {
        // Calculate the fee receiver #1 amount (50%)
        uint256 fee1 = amount * 5 / 10;

        // Calculate the fee receiver #2 amount (50%)
        uint256 fee2 = amount - fee1;

        // Transfer the marketing fee to the fee receiver #1 wallet
        super._transfer(from, feeReceiver1, fee1);

        // Transfer the airdrop amount to the fee receiver #2 wallet
        super._transfer(from, feeReceiver2, fee2);
    }

}
