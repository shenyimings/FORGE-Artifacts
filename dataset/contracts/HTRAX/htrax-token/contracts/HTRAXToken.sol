// contracts/HTRAXToken.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./access/Ownable.sol";
import "./security/Pausable.sol";
import "./access/AccessControl.sol";
import "./token/ERC20/ERC20.sol";
import "./token/ERC20/extensions/ERC20Snapshot.sol";
import "./HTRAXTokenSale.sol";

contract HTRAXToken is ERC20, ERC20Snapshot, Ownable, Pausable, AccessControl, HTRAXTokenSale {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");

    uint256 private immutable _cap = 375000000 * (10 ** uint256(decimals()));
    uint256 private immutable _release = 93750000 * (10 ** uint256(decimals()));
    string private _symbol = "HTRAX";
    string private _name = "HTRAX Token";

    mapping(address => bool) private isBlackListed;
   
    constructor() 
    ERC20(_name, _symbol)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        // token release for phase-1
        _mint(_msgSender(), _release);
    }

    /**
     * @dev Emits an {AddedBlackList} event indicating wallet details with is added to the blacklist.
     */
     event AddedBlackList(address _address);

    /**
     * @dev Emits an {RemovedBlackList} event indicating wallet details with is removed from the blacklist.
     */     
     event RemovedBlackList(address _address);   

    /**
     * @dev caller with minter role can mint the token
     */
    function mint(address account, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(amount <= _release, "Token for mint can't be more then allocated for each release");
        require((totalSupply() + totalBurned() + amount) <= _cap, "cap exceeded");
        super._mint(account, amount);
    }

    /**
     * @dev Returns total cap of the token
     */
    function cap() public view virtual returns (uint256) {
        return _cap;
    } 

    /**
     * @dev See {ERC20-_burn}.    
     * caller with burner role can burn the token
     */
    function burn(uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev See {ERC20-burnFrom}.    
     */
    function burnFrom(address account, uint256 amount) public onlyRole(BURNER_ROLE) {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
    }

    /**
     * @dev caller with risk manager role can create a snapshot
     */
    function snapshot() public onlyRole(RISK_MANAGER_ROLE) {
        _snapshot();
    }

    /**
     * @dev Caller with risk manager role can pause the contract
     */
    function pause() public onlyRole(RISK_MANAGER_ROLE) {
        _pause();
    }

    /**
     * @dev Caller with risk manager role can unpause the contract
     */
    function unpause() public onlyRole(RISK_MANAGER_ROLE) {
        _unpause();
    } 

    /**
     * @dev See {ERC20-transferFrom}.
     * @param _value of token need to be in format: amount *10^18
     */
    function transfer(address _to, uint256 _value) override public returns (bool success) {      
        uint256 senderAvailableBalance = balanceOf(_msgSender()) - getTotalLockedBalance(_msgSender());
        require(_value <= senderAvailableBalance, "Transfer amount exceeds available balance");

        return super.transfer(_to, _value);
    }     

    /**
     * @dev See {ERC20-transferFrom}.
     * @param _value of token need to be in format: _value *10^18   
     */
    function transferFrom(address _from, address _to, uint256 _value) override public returns (bool success) {
        uint256 senderAvailableBalance = balanceOf(_from) - getTotalLockedBalance(_msgSender());
        require(_value <= senderAvailableBalance, "Transfer amount exceeds available balance");

        return super.transferFrom(_from, _to, _value);
    }

    /**
     * @dev Caller with risk manager role can add wallet to blacklist
     * Wallets added to blacklist are no longer be able to make transactions.
     */
    function addBlackList(address[] memory _address) public onlyRole(RISK_MANAGER_ROLE) {
        for (uint256 i = 0; i < _address.length; i++) {
            require(_address[i] != address(0), 'The address is address 0');
            require(_address[i] != owner(), 'The address is the owner');
            if (!isBlackListed[_address[i]]) {
                isBlackListed[_address[i]] = true;
                emit AddedBlackList(_address[i]);
            }
        }
    }    

    /**
     * @dev Caller with risk manager role can remove wallet from blacklist
     */
    function removeBlackList(address[] memory _address) public onlyRole(RISK_MANAGER_ROLE) {
        for (uint256 i = 0; i < _address.length; i++) {
            if (isBlackListed[_address[i]]) {
                isBlackListed[_address[i]] = false;
                emit RemovedBlackList(_address[i]);
            }
        }
    }    

    /**
     * @dev Caller with executor role can transfer discounted and locked tokens.
     * @param recipient: wallet address of the user where tokens needs to transfer
     * @param totalAmount: amount of token that need to be TRANSFER in format: amount *10^18
     */
    function transferDiscountedTokens(address recipient, uint totalAmount) public onlyRole(EXECUTOR_ROLE) {
        uint256 discountedAmount = getDiscountDetails(totalAmount);
        require(discountedAmount <= balanceOf(_msgSender()), "Transfer amount exceeds available balance");
        addDiscountTokenLockDetails(recipient, discountedAmount);
        transfer(recipient, discountedAmount);
    }

    /**
     * @dev Caller with executor role can withdraw token from smart contract to own address
     * @param _tokenContract is address of the token
     * @param _value of token need to be in format: _value *10^18
     */
    function withdrawBalance(address _tokenContract, uint256 _value) public onlyRole(EXECUTOR_ROLE) {
        IERC20 tokenContract = IERC20(_tokenContract);
        require(_value <= tokenContract.balanceOf(address(this)), "Transfer amount exceeds available balance");
        
        tokenContract.transfer(msg.sender, _value);
    }         

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override(ERC20, ERC20Snapshot)
    {
        require(!isBlackListed[from], 'Transfer not allowed');
        require(!isBlackListed[to], 'Transfer not allowed');

        super._beforeTokenTransfer(from, to, amount);       
    }            
}