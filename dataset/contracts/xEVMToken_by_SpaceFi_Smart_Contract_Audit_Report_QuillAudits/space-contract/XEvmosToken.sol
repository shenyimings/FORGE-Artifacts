// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract XEvmosToken is Initializable, ContextUpgradeable, OwnableUpgradeable, ReentrancyGuard {
    using SafeMathUpgradeable for uint256;
    struct RedeemInfo {
        uint256 EvmosAmount; // Evmos amount to receive when vesting has ended
        uint256 xEvmosAmount; // XEvmos amount to redeem
        uint256 beginTime; // XEvmos  redeem begin time
        uint256 endTime; // XEvmos  redeem end time
    }
    uint256 public burnNumber;
    uint256 public minRedeemRatio;   // 1:0.5
    uint256 public maxRedeemRatio;  // 1:1
    uint256 public minRedeemDuration; // 0s      0days
    uint256 public maxRedeemDuration; // 1209600s      15days
    uint256 private _totalSupply;
    string private tokenName;
    string private tokenSymbol;
    mapping (address => bool) public _transferWhitelist;  // addresses allowed to send/receive XEvmos
    mapping(address => RedeemInfo[]) public userRedeems; // User's redeeming instances
    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _unbondingBalances;
    mapping(address => mapping(address => uint256)) private _allowances;
    event Transfer(address indexed _sender, address indexed _recipient, uint256 _amount);
    event Approval(address indexed _sender, address indexed _recipient, uint256 _amount);
    event SetTransferWhitelist(address _account, bool _add);
    event UpdateRedeemSettings(uint256 _minRedeemRatio, uint256 _maxRedeemRatio, uint256 _minRedeemDuration,uint256 _maxRedeemDuration);
    event Convert(address indexed _from, address _to, uint256 _amount);
    event Redeem(address indexed _userAddress, uint256 _xEvmosAmount, uint256 _EvmosAmount, uint256 _duration);
    event FinalizeRedeem(address indexed _userAddress, uint256 _xEvmosAmount, uint256 _EvmosAmount);
    event CancelRedeem(address indexed _userAddress, uint256 _xEvmosAmount);

    /**
     * @notice Contract parameter initialization.
     * @dev Sets the values for {name} and {symbol} and {minRedeemRatio} and {maxRedeemRatio} and {minRedeemDuration} and {maxRedeemDuration}.
     * @param _name the token Name.
     * @param _symbol the token symbol.
     * @param _minRedeemRatio the Minimum redemption ratio of XEvmos to Evmos.
     * @param _maxRedeemRatio the Maximum redemption ratio of XEvmos to Evmos.
     * @param _minRedeemDuration the Minimum Exchange Duration of XEvmos to Evmos.
     * @param _maxRedeemDuration the Maximum Exchange Duration of XEvmos to Evmos.
     */
    function initialize(string memory _name, string memory _symbol,uint256 _minRedeemRatio,uint256 _maxRedeemRatio,uint256 _minRedeemDuration,uint256 _maxRedeemDuration) public initializer {
        __ERC20_init(_name, _symbol, _minRedeemRatio, _maxRedeemRatio, _minRedeemDuration, _maxRedeemDuration);
    }

    function __ERC20_init(string memory _name, string memory _symbol,uint256 _minRedeemRatio,uint256 _maxRedeemRatio,uint256 _minRedeemDuration,uint256 _maxRedeemDuration) internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __ERC20_init_unchained(_name, _symbol, _minRedeemRatio, _maxRedeemRatio, _minRedeemDuration, _maxRedeemDuration);
    }

    function __ERC20_init_unchained(string memory _name, string memory _symbol,uint256 _minRedeemRatio,uint256 _maxRedeemRatio,uint256 _minRedeemDuration,uint256 _maxRedeemDuration) internal initializer {
        tokenName = _name;
        tokenSymbol = _symbol;
        minRedeemRatio = _minRedeemRatio;
        maxRedeemRatio = _maxRedeemRatio;
        minRedeemDuration = _minRedeemDuration;
        maxRedeemDuration = _maxRedeemDuration;
        _transferWhitelist[address(this)] = true;
    }

    /**
     * @notice Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return tokenName;
    }

    /**
     * @notice Returns the symbol of the token, usually a shorter version of the name.
     */
    function symbol() public view virtual returns (string memory) {
        return tokenSymbol;
    }

    /**
     * @notice Returns the number of decimals used to get its user representation.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @notice See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice See {IERC20-balanceOf}.
     * @return XEvmos Balance of this account
     */
    function balanceOf(address  _account) public view virtual returns (uint256) {
        return _balances[_account];
    }

    /**
     * @notice See {IERC20-balanceOf}.
     * @return XEvmos Unbonding Balance of this account
     */
    function unbondingBalancOf(address _account) public view virtual returns (uint256) {
        return _unbondingBalances[_account];
    }

    /**
     * @notice See {IERC20-transfer}.
     */
    function transfer(address _recipient, uint256 _amount) public virtual returns (bool) {
        _transfer(_msgSender(), _recipient, _amount);
        return true;
    }

    /**
     * @notice See {IERC20-allowance}.
     */
    function allowance(address _owner, address _spender) public view virtual returns (uint256) {
        return _allowances[_owner][_spender];
    }

    /**
     * @notice See {IERC20-approve}.
     */
    function approve(address _spender, uint256 _amount) public virtual returns (bool) {
        _approve(_msgSender(), _spender, _amount);
        return true;
    }

    /**
     * @notice See {IERC20-transferFrom}.
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public virtual returns (bool) {
        _transfer(_sender, _recipient, _amount);
        uint256 currentAllowance = _allowances[_sender][_msgSender()];
        require(currentAllowance >= _amount, "XEvmos ERC20: transfer amount exceeds allowance");
        unchecked {
    _approve(_sender, _msgSender(), currentAllowance - _amount);
    }
        return true;
    }

    /**
     * @notice Atomically increases the allowance granted to `spender` by the caller.
     */
    function increaseAllowance(address _spender, uint256 _addedValue) public virtual returns (bool) {
        _approve(_msgSender(), _spender, _allowances[_msgSender()][_spender] + _addedValue);
        return true;
    }

    /**
     * @notice Atomically decreases the allowance granted to `spender` by the caller.
     */
    function decreaseAllowance(address _spender, uint256 _subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][_spender];
        require(currentAllowance >= _subtractedValue, "XEvmos ERC20: decreased allowance below zero");
        unchecked {
    _approve(_msgSender(), _spender, currentAllowance - _subtractedValue);
    }
        return true;
    }

    /**
     * @notice Moves `amount` of tokens from `sender` to `recipient`.
     */
    function _transfer(address _sender, address _recipient, uint256 _amount) internal virtual {
        require(_sender != address(0), "XEvmos ERC20: transfer from the zero address");
        require(_recipient != address(0), "XEvmos ERC20: transfer to the zero address");
        _beforeTokenTransfer(_sender, _recipient, _amount);
        uint256 senderBalance = _balances[_sender];
        require(senderBalance >= _amount, "XEvmos ERC20: transfer amount exceeds balance");
        unchecked {
    _balances[_sender] -= _amount;
    }
        _balances[_recipient] += _amount;
        emit Transfer(_sender, _recipient, _amount);
        _afterTokenTransfer(_sender, _recipient, _amount);
    }

    /**
     * @notice Creates `amount` tokens and assigns them to `account`, increasing the total supply.
     */
    function _mint(address _account, uint256 _amount) internal virtual {
        require(_account != address(0), "XEvmos ERC20: mint to the zero address");
        _beforeTokenTransfer(address(0), _account, _amount);
        _totalSupply += _amount;
        _balances[_account] += _amount;
        emit Transfer(address(0), _account, _amount);
        _afterTokenTransfer(address(0), _account, _amount);
    }

    /**
     * @notice Destroys `amount` tokens from `account`, reducing the total supply.
     */
    function _burn(address _account, uint256 _amount) internal virtual {
        require(_account != address(0), "XEvmos ERC20: burn from the zero address");
        _beforeTokenTransfer(_account, address(0), _amount);
        uint256 accountBalance = _balances[_account];
        require(accountBalance >= _amount, "XEvmos ERC20: burn amount exceeds balance");
        unchecked {
    _balances[_account] -= _amount;
    }
        _totalSupply -= _amount;
        burnNumber += _amount;
        emit Transfer(_account, address(0), _amount);
        _afterTokenTransfer(_account, address(0), _amount);
    }

    /**
     * @notice Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     */
    function _approve(address _owner, address _spender, uint256 _amount) internal virtual {
        require(_owner != address(0), "XEvmos ERC20: approve from the zero address");
        require(_spender != address(0), "XEvmos ERC20: approve to the zero address");
        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    /**
    * @notice Adds or removes addresses from the transferWhitelist.
    * @param _account the account.
    * @param _add This is the status. False is delete, and true is add..
    */
    function updateTransferWhitelist(address _account, bool _add) external onlyOwner {
        require(_account != address(this), "updateTransferWhitelist: Cannot remove XEvmos from whitelist");
        if(_add) _transferWhitelist[_account] = true;
        else _transferWhitelist[_account] = false;
        emit SetTransferWhitelist(_account, _add);
    }

    /**
     * @notice Updates all redeem ratios and durations.
     * @param _minRedeemRatio the Minimum redemption ratio of XEvmos to Evmos.
     * @param _maxRedeemRatio the Maximum redemption ratio of XEvmos to Evmos.
     * @param _minRedeemDuration the Minimum Exchange Duration of XEvmos to Evmos.
     * @param _maxRedeemDuration the Maximum Exchange Duration of XEvmos to Evmos.
    */
    function updateRedeemSettings(uint256 _minRedeemRatio,uint256 _maxRedeemRatio,uint256 _minRedeemDuration,uint256 _maxRedeemDuration) external onlyOwner {
        require(_minRedeemRatio <= _maxRedeemRatio, "updateRedeemSettings: wrong ratio values");
        require(_maxRedeemDuration > 0 , "updateRedeemSettings: wrong maxDuration values");
        minRedeemRatio = _minRedeemRatio;
        maxRedeemRatio = _maxRedeemRatio;
        minRedeemDuration = _minRedeemDuration;
        maxRedeemDuration = _maxRedeemDuration;
        emit UpdateRedeemSettings(_minRedeemRatio, _maxRedeemRatio, _minRedeemDuration,_maxRedeemDuration);
    }

    /**
    * @notice Convert caller's "amount" of Evmos to XEvmos.
    */
    function convert(uint256 _amount) external nonReentrant {
        _convert(_amount, msg.sender);
    }

    /**
    * @notice Convert caller's "amount" of Evmos into XEvmos to "to"
    * @param _amount the convert quantity.
    * @param _to the convert account.
    */
    function _convert(uint256 _amount, address _to) internal {
        require(_amount != 0, "convert: amount cannot be null");
        // mint new XEvmos
        // _mint(to, amount);
        require(msg.value == _amount,"convert: The amount is not correct");
        emit Convert(msg.sender, _to, _amount);
    }

    /**
    * @notice Initiates redeem process (XEvmos to Evmos)
    * @param _xEvmosAmount the redeem quantity.
    * @param _Class the Redeem Duration type.
    */
    function redeem(uint256  _xEvmosAmount, uint256 _Class) external nonReentrant {
        require(_xEvmosAmount > 0, "redeem: xEvmosAmount cannot be null");
        if(_Class != 1 && _Class != 2){
            require(false,"redeem: Class error");
        }
        _transfer(msg.sender, address(this), _xEvmosAmount);
        // get corresponding Evmos amount
        uint256 EvmosAmount = getEvmosByVestingDuration(_xEvmosAmount, _Class);
        uint256 duration = 0;
        if(_Class == 2){
            duration = maxRedeemDuration;
        }else{
            duration = minRedeemDuration;
        }
        emit Redeem(msg.sender, _xEvmosAmount, EvmosAmount, duration);
        // add redeeming entry
        userRedeems[msg.sender].push(RedeemInfo(EvmosAmount, _xEvmosAmount, _currentBlockTimestamp(),_currentBlockTimestamp().add(duration)));
        _unbondingBalances[msg.sender] += _xEvmosAmount;
    }

    /**
    * @notice Finalizes redeem process when vesting duration has been reached
    * @param _redeemIndex the Redemption index.
    */
    function finalizeRedeem(uint256 _redeemIndex) external nonReentrant validateRedeem(msg.sender,_redeemIndex) {
        RedeemInfo storage _redeem = userRedeems[msg.sender][_redeemIndex];
        // remove from SBT total
        _unbondingBalances[msg.sender] -= _redeem.xEvmosAmount;
        require(_currentBlockTimestamp() >= _redeem.endTime, "finalizeRedeem: vesting duration has not ended yet");
        _finalizeRedeem(msg.sender, _redeem.xEvmosAmount, _redeem.EvmosAmount);
        // remove redeem entry
        _deleteRedeemEntry(_redeemIndex);
    }

    /**
    * @notice Cancels an ongoing redeem entry
    * @param _redeemIndex the Redemption index.
    */
    function cancelRedeem(uint256 _redeemIndex) external nonReentrant validateRedeem(msg.sender, _redeemIndex) {
        RedeemInfo storage _redeem = userRedeems[msg.sender][_redeemIndex];
        // make redeeming XEvmos available again
        _unbondingBalances[msg.sender] -= _redeem.xEvmosAmount;
        _transfer(address(this), msg.sender, _redeem.xEvmosAmount);
        emit CancelRedeem(msg.sender, _redeem.xEvmosAmount);
        // remove redeem entry
        _deleteRedeemEntry(_redeemIndex);
    }

    /**
    * @notice Finalizes the redeeming process for "userAddress" by transferring him "EvmosAmount" and removing "XEvmosAmount" from supply
    * @param _userAddress the User address.
    * @param _xEvmosAmount the xEvmos amount.
    * @param _EvmosAmount the Evmos amount.
    */
    function _finalizeRedeem(address _userAddress, uint256 _xEvmosAmount, uint256 _EvmosAmount) internal {
        // sends due Evmos tokens
        (bool success, ) = _userAddress.call{value:_EvmosAmount}("");
        require(success, "finalizeRedeem:Transfer failed.");
        _burn(address(this), _xEvmosAmount);
        emit FinalizeRedeem(_userAddress, _xEvmosAmount, _EvmosAmount);
    }

    /**
    * @notice delete Redeem Entry.
    * @param _index the Entry index.
    */
    function _deleteRedeemEntry(uint256 _index) internal {
        userRedeems[msg.sender][_index] = userRedeems[msg.sender][userRedeems[msg.sender].length - 1];
        userRedeems[msg.sender].pop();
    }

    /*
    * @notice returns redeemable Evmos for "amount" of XEvmos vested for "duration" seconds
    */
    function getEvmosByVestingDuration(uint256 _amount, uint256 _Class) public view returns (uint256) {
        if(_Class != 1 && _Class != 2){
            return 0;
        }
        if(_Class == 1){
            return _amount.mul(minRedeemRatio).div(100);
        }else{
            return _amount.mul(maxRedeemRatio).div(100);
        }
    }

    /**
    * @notice returns quantity of "userAddress" pending redeems
    */
    function getUserRedeemsLength(address _userAddress) external view returns (uint256) {
        return userRedeems[_userAddress].length;
    }

    /**
    * @notice returns if "account" is allowed to send/receive XEvmos
    */
    function isTransferWhitelisted(address _account) external view returns (bool) {
        return _transferWhitelist[_account];
    }

    /**
    * @notice Utility function to get the current block timestamp
    */
    function _currentBlockTimestamp() internal view virtual returns (uint256) {
        /* solhint-disable not-rely-on-time */
        return block.timestamp;
    }

    /*
    * @notice Check if a redeem entry exists
    */
    modifier validateRedeem(address _userAddress, uint256 _redeemIndex) {
        require(_redeemIndex < userRedeems[_userAddress].length, "validateRedeem: redeem entry does not exist");
        _;
    }

    /**
    * @notice Hook override to forbid transfers except from whitelisted addresses and minting
    */
    function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal view  {
        require(_from == address(0) || _to == address(0) || _transferWhitelist[_from] || _transferWhitelist[_to] , "transfer: not allowed");
    }

    function _afterTokenTransfer(address _from, address _to, uint256 _amount) internal virtual {}

    uint256[45] private __gap;

receive() external payable {}

fallback() external payable {}
}
