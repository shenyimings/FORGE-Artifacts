//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract StableRebaseFake {

    uint8 private numDecimals;
    uint256 public liquidityIndex;

    mapping(address => uint256) private _balances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */


    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        uint8 _numDecimals
    ) {
        _name = name_;
        _symbol = symbol_;
        mint(msg.sender, initialSupply);
        numDecimals = _numDecimals;
        liquidityIndex = 1e6;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }


    function decimals() public view virtual returns (uint8) {
        return numDecimals;
    }

    function mint(address receiver, uint amount) public {
        _totalSupply += amount;
        _balances[receiver] += amount;
    }

    function setRebaseFactor(uint256 _liquidityIndex) external {
        liquidityIndex = _liquidityIndex;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account] * liquidityIndex / 1e6;
    }

    function transfer(address to,uint256 amount) public returns (bool) {
        address from = msg.sender;
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = balanceOf(from);
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = _balances[from] - amount * 1e6 / liquidityIndex;
        }
        _balances[to] += amount * 1e6 / liquidityIndex;

        return true;
    }
}
