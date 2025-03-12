pragma solidity ^0.6.0;
/**
 * @author kohshiba
 * @title InsureDAO cds contract template contract
 */

import "./libraries/math/SafeMath.sol";
import "./libraries/utils/Address.sol";
import "./libraries/tokens/IERC20.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IRegistry.sol";
import "./interfaces/IParameters.sol";
import "./interfaces/ICDS.sol";
import "./interfaces/IMinter.sol";

contract CDS is IERC20 {
    using Address for address;
    using SafeMath for uint256;

    /**
     * EVENTS
     */

    event Deposit(
        address indexed depositor,
        uint256 amount,
        uint256 mint,
        uint256 balance,
        uint256 underlying
    );
    event Withdraw(address indexed withdrawer, uint256 amount, uint256 retVal);
    event Compensated(address indexed index, uint256 amount);
    event Paused(bool paused);
    event MetadataChanged(string metadata);
    /**
     * Storage
     */

    /// @notice Market setting
    bool public initialized;
    bool public paused;
    string public metadata;

    /// @notice EIP-20 token variables
    string public name;
    string public symbol;
    uint8 public decimals;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    /// @notice External contract call addresses
    IParameters public parameters;
    IRegistry public registry;
    IVault public vault;
    IMinter public minter;

    ///@notice user status management
    struct Withdrawal {
        uint256 timestamp;
        uint256 amount;
    }
    mapping(address => Withdrawal) public withdrawalReq;

    /**
     * @notice Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(
            msg.sender == parameters.get_owner(),
            "Ownable: caller is not the owner"
        );
        _;
    }

    /**
     * Initialize interaction
     */

    /**
     * @notice Initialize market
     * This function registers market conditions.
     * references[0] = parameter
     * references[1] = vault address
     * references[2] = registry
     * references[3] = minter
     */
    function initialize(
        address _owner,
        string calldata _metaData,
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals,
        uint256[] calldata _conditions,
        address[] calldata _references
    ) external returns (bool) {
        require(
            bytes(_metaData).length > 10 &&
                bytes(_name).length > 0 &&
                bytes(_symbol).length > 0 &&
                _decimals > 0 &&
                _owner != address(0) &&
                _references[0] != address(0) &&
                _references[1] != address(0) &&
                _references[2] != address(0) &&
                _references[3] != address(0),
            "ERROR: INITIALIZATION_BAD_CONDITIONS"
        );

        initialized = true;

        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        parameters = IParameters(_references[0]);
        vault = IVault(_references[1]);
        registry = IRegistry(_references[2]);
        minter = IMinter(_references[3]);

        metadata = _metaData;

        return true;
    }

    /**
     * Pool initeractions
     */

    /**
     * @notice A provider supplies collatral to the pool and receives iTokens
     */
    function deposit(uint256 _amount) public returns (uint256 _mintAmount) {
        require(paused == false, "ERROR: DEPOSIT_DISABLED");
        require(_amount > 0);

        uint256 _fee = parameters.getFee2(_amount, msg.sender);
        uint256 _add = _amount.sub(_fee);
        uint256 _supply = totalSupply();
        uint256 _totalLiquidity = totalLiquidity();
        //deposit and pay fees
        vault.addValue(_add, msg.sender, address(this));
        vault.addValue(_fee, msg.sender, parameters.get_owner());

        //Calculate iToken value
        if (_supply > 0 && _totalLiquidity > 0) {
            _mintAmount = _add.mul(_supply).div(_totalLiquidity);
        } else if (_supply > 0 && _totalLiquidity == 0) {
            _mintAmount = _add.div(_supply);
        } else {
            _mintAmount = _add;
        }

        emit Deposit(
            msg.sender,
            _amount,
            _mintAmount,
            balanceOf(msg.sender),
            valueOfUnderlying(msg.sender)
        );

        //mint iToken
        _mint(msg.sender, _mintAmount);
    }

    /**
     * @notice Provider request withdrawal of collateral
     */
    function requestWithdraw(uint256 _amount) external {
        uint256 _balance = balanceOf(msg.sender);
        require(
            _balance >= _amount && _amount > 0,
            "ERROR: WITHDRAW_REQUEST_BAD_CONDITIONS"
        );
        withdrawalReq[msg.sender].timestamp = now;
        withdrawalReq[msg.sender].amount = _amount;
    }

    /**
     * @notice Provider burns iToken and receives collatral from the pool
     */
    function withdraw(uint256 _amount) external returns (uint256 _retVal) {
        //Calculate underlying value
        _retVal = vault.underlyingValue(address(this)).mul(_amount).div(
            totalSupply()
        );

        require(
            paused == false &&
                withdrawalReq[msg.sender].timestamp.add(
                    parameters.getLockup(msg.sender)
                ) <
                now &&
                withdrawalReq[msg.sender]
                .timestamp
                .add(parameters.getLockup(msg.sender))
                .add(parameters.getWithdrawable(msg.sender)) >
                now &&
                withdrawalReq[msg.sender].amount >= _amount &&
                _amount > 0,
            "ERROR: WITHDRAWAL_BAD_CONDITIONS"
        );

        //reduce requested amount
        withdrawalReq[msg.sender].amount = withdrawalReq[msg.sender].amount.sub(
            _amount
        );

        //Burn iToken
        _burn(msg.sender, _amount);

        //Withdraw liquidity
        vault.withdrawValue(_retVal, msg.sender);
        emit Withdraw(msg.sender, _amount, _retVal);
    }

    /**
     * Insurance interactions
     */

    /**
     * @notice Compensate the shortage if an index is insolvent
     */
    function compensate(uint256 _amount) external {
        require(registry.isListed(msg.sender));
        uint256 _available = vault.underlyingValue(address(this));
        if (_available >= _amount) {
            //Normal case
            vault.transferValue(_amount, msg.sender);
        } else {
            uint256 _shortage = _amount.sub(_available);
            //transfer as much as possible
            vault.transferValue(_available, msg.sender);
            //mint and swap for the shortage
            minter.emergency_mint(_shortage);
        }
        emit Compensated(msg.sender, _amount);
    }

    /**
     * iToken functions
     */

    /**
     * @notice See `IERC20.totalSupply`.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice See `IERC20.balanceOf`.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @notice See `IERC20.transfer`.
     */
    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @notice See `IERC20.allowance`.
     */
    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @notice See `IERC20.approve`.
     */
    function approve(address spender, uint256 value)
        public
        override
        returns (bool)
    {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @notice See `IERC20.transferFrom`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            msg.sender,
            _allowances[sender][msg.sender].sub(amount)
        );
        return true;
    }

    /**
     * @notice Atomically increases the allowance granted to `spender` by the caller.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender].add(addedValue)
        );
        return true;
    }

    /**
     * @notice Atomically decreases the allowance granted to `spender` by the caller.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender].sub(subtractedValue)
        );
        return true;
    }

    /**
     * @notice Moves tokens `amount` from `sender` to `recipient`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(
            sender != address(0) && recipient != address(0),
            "ERC20: TRANSFER_BAD_CONDITIONS"
        );

        _beforeTokenTransfer(sender, amount);

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /**
     * @notice Creates `amount` tokens and assigns them to `account`, increasing
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @notice Destoys `amount` tokens from `account`, reducing the
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @notice Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     */
    function _approve(
        address _owner,
        address _spender,
        uint256 _value
    ) internal {
        require(
            _owner != address(0) && _spender != address(0),
            "ERC20: APPROVE_BAD_CONDITIONS"
        );

        _allowances[_owner][_spender] = _value;
        emit Approval(_owner, _spender, _value);
    }

    /**
     * Utilities
     */

    /**
     * @notice total Liquidity of the pool (how much can the pool sell cover)
     */
    function totalLiquidity() public view returns (uint256 _balance) {
        return vault.underlyingValue(address(this));
    }

    /**
     * @notice Get the exchange rate of LP token against underlying asset(scaled by 1e18)
     */
    function rate() external view returns (uint256) {
        if (_totalSupply > 0) {
            return totalLiquidity().mul(1e18).div(_totalSupply);
        } else {
            return 0;
        }
    }

    /**
     * @notice Get the underlying balance of the `owner`
     */
    function valueOfUnderlying(address _owner) public view returns (uint256) {
        uint256 _balance = balanceOf(_owner);
        if (_balance == 0) {
            return 0;
        } else {
            return
                _balance.mul(
                    vault.underlyingValue(address(this)).div(totalSupply())
                );
        }
    }

    /**
     * Admin functions
     */

    /**
     * @notice Change metadata string
     */
    function changeMetadata(string calldata _metadata) external onlyOwner {
        metadata = _metadata;
        emit MetadataChanged(_metadata);
    }

    /**
     * @notice Used for changing settlementFeeRecipient
     */
    function setPaused(bool state) external onlyOwner {
        paused = state;
        emit Paused(state);
    }

    /**
     * Internal functions
     */

    /**
     * @notice Internal function to offset deposit time stamp when transfer iToken
     */
    function _beforeTokenTransfer(address _from, uint256 _amount) internal {
        //withdraw request operation
        uint256 _after = balanceOf(_from).sub(_amount);
        if (_after < withdrawalReq[_from].amount) {
            withdrawalReq[_from].amount = _after;
        }
    }
}
