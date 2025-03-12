// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
import "../utilities/Initializable.sol";
import "../utilities/Context.sol";
import "../access/Ownable.sol";
import "../security/Pausable.sol";
import "../interfaces/IBEP20.sol";
import "../libraries/Address.sol";



// Implementation of the IBEP20 Interface, using Context, Pausable, Ownable, and Snapshot Extenstions.
contract BEP20 is Initializable, Context, IBEP20, Pausable, Ownable {
    
    // Dev-Note: Solidity 0.8.0 added built-in support for checked math, therefore the "SafeMath" library is no longer needed.
    using Address for address;

    // Creates mapping for the collections of balances and allowances.
    mapping(address => uint256) public _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // Initializes variables for the name, symbol, decimals, and the total Supply of the BEP20 token.
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;

    
    // Sets the values for {name}, {symbol}, {decimals}, and {totalSupply}.
    function __BEP20_init(string memory name_, string memory symbol_, uint8 decimals_, uint256 totalSupply_) internal initializer {
        __Context_init_unchained();
        __Ownable_init();
        __Pausable_init();
        __BEP20_init_unchained(name_, symbol_, decimals_, totalSupply_);
    }


    // Internal function to set the values for {name}, {symbol}, {decimals}, and {totalSupply}.
    function __BEP20_init_unchained(string memory name_, string memory symbol_, uint8 decimals_, uint256 totalSupply_) internal initializer {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _totalSupply = totalSupply_;
        _balances[msg.sender] = _totalSupply;

        emit Transfer(address(0), msg.sender, _totalSupply);
    }
    
    
    // Allows "owner" to Pause the token transactions, used during maintenance periods or when upgrading token to new version. 
    function pause() public onlyOwner {
        _pause();
    }

    
    // Allows "owner" to Un-Pause the token transactions, used after maintenance periods are finished or once upgrade is complete.
    function unpause() public onlyOwner {
        _unpause();
    }
    

    // Returns the token name.
    function name() public override view returns (string memory) {
        return _name;
    }
    
    
    // Returns the token symbol.
    function symbol() public override view returns (string memory) {
        return _symbol;
    }

 
    // Returns the token decimals.
    function decimals() public override view returns (uint8) {
        return _decimals;
    }


    // Returns the total supply of token.
    function totalSupply() public override view returns (uint256) {
        return _totalSupply;
    }


    // Returns balance of the referenced 'account' address.
    function balanceOf(address account) public override view returns (uint256) {
        return _balances[account];
    }

    
    // Returns the remaining tokens that the 'spender' address can spend on behalf of the 'owner' address through the {transferFrom} function.
    function allowance(address owner, address spender) public override view returns (uint256) {
        return _allowances[owner][spender];
    }
    
    
    // Atomically increases the allowance granted to `spender` by the caller.
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, (_allowances[_msgSender()][spender] + addedValue));
        return true;
    }
    
    
    // Atomically decreases the allowance granted to `spender` by the caller.
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        require((_allowances[_msgSender()][spender] - subtractedValue) >= 0, "BEP20: decreased allowance below zero");
        
        unchecked {
            _approve(_msgSender(), spender, (_allowances[_msgSender()][spender] - subtractedValue));
        }
        
        return true;
    }


    // Sets 'amount' as the allowance of 'spender' then returns a boolean indicating result of operation. Emits an {Approval} event.
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    
    
    // Sets 'amount' as the allowance of 'spender' then returns a boolean indicating result of operation. Emits an {Approval} event.
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), 'BEP20: approve from the zero address');
        require(spender != address(0), 'BEP20: approve to the zero address');

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    
    // Transfers an 'amount' of tokens from the callers account to the referenced 'recipient' address. Emits a {Transfer} event.
    function transfer(address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }


    // Transfers an 'amount' of tokens from the 'sender' address to the 'recipient' address. Emits a {Transfer} event.
    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        _transfer(sender, recipient, amount);
        
        require(amount <= _allowances[sender][_msgSender()], "BEP20: transfer amount exceeds allowance");
        
        unchecked {
            _approve(sender, _msgSender(), (_allowances[sender][_msgSender()] - amount));
        }
        
        return true;
    }
    
    
    // Internal function that moves tokens `amount` from `sender` to `recipient`.
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), 'BEP20: transfer from the zero address');
        require(recipient != address(0), 'BEP20: transfer to the zero address');
        
        _beforeTokenTransfer(sender, recipient, amount);
        
        require(amount <= _balances[sender], "BEP20: transfer amount exceeds balance");
        
        unchecked {
            _balances[sender] = _balances[sender] - amount;
        }
        
        _balances[recipient] = _balances[recipient] + amount;
        
        emit Transfer(sender, recipient, amount);
    }
    
    
    /*  Hook that is called before any transfer of tokens. This includes minting and burning. (Though mint and burn functions are not used in the GaussGANG token)
     
        Calling conditions:
            - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens will be transferred to `to`.
            - when `from` is zero, `amount` tokens will be minted for `to`.
            - when `to` is zero, `amount` of ``from``'s tokens will be burned.
            - `from` and `to` are never both zero.
    */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}


    /*  Hook that is called after any transfer of tokens. This includes minting and burning.(Though mint and burn functions are not used in the GaussGANG token)
     
        Calling conditions:
            - when `from` and `to` are both non-zero, `amount` of ``from``'s tokenshas been transferred to `to`.
            - when `from` is zero, `amount` tokens have been minted for `to`.
            - when `to` is zero, `amount` of ``from``'s tokens have been burned.
            - `from` and `to` are never both zero.
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
    
    uint256[45] private __gap;
}