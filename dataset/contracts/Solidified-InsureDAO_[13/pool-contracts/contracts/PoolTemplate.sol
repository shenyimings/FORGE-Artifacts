pragma solidity ^0.6.0;

/**
 * @author kohshiba
 * @title InsureDAO pool template contract
 */
import "./libraries/math/SafeMath.sol";
import "./libraries/utils/Address.sol";
import "./libraries/tokens/IERC20.sol";
import "./interfaces/IParameters.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IRegistry.sol";
import "./interfaces/IIndexTemplate.sol";

contract PoolTemplate is IERC20 {
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
    event Unlocked(uint256 indexed id, uint256 amount);
    event Insured(
        uint256 indexed id,
        uint256 amount,
        bytes32 target,
        uint256 startTime,
        uint256 endTime,
        address insured
    );
    event Redeemed(
        uint256 indexed id,
        address insured,
        bytes32 target,
        uint256 amount,
        uint256 payout
    );
    event CoverApplied(
        uint256 _pending,
        uint256 _payoutNumerator,
        uint256 _payoutDenominator,
        uint256 _incidentTimestamp,
        bytes32[] _targets,
        string _memo
    );
    event CreditIncrease(address indexed depositor, uint256 credit);
    event CreditDecrease(address indexed withdrawer, uint256 credit);
    event MarketStatusChanged(MarketStatus statusValue);
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

    /// @notice Market variables
    uint256 public totalAttributions; //how much attribution point this pool's original liquidity has
    uint256 public lockedAmount; //Liquidity locked when utilized
    uint256 public totalCredit; //Liquidity from index
    uint256 public attributionPerCredit; //Times 1e12. To avoid overdlow
    uint256 public pendingEnd; //pending time when paying out

    /// @notice Market variables for margin account
    struct IndexInfo {
        uint256 credit;
        uint256 rewardDebt;
        bool exist;
    }
    mapping(address => IndexInfo) public indexes;
    address[] public indexList;

    ///@notice Market status transition management
    enum MarketStatus {
        Trading,
        Payingout
    }
    MarketStatus public marketStatus;

    ///@notice user status management
    struct Withdrawal {
        uint256 timestamp;
        uint256 amount;
    }
    mapping(address => Withdrawal) public withdrawalReq;

    ///@notice insurance status management
    struct Insurance {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        uint256 amount;
        bytes32 target;
        address insured;
        bool status;
    }
    Insurance[] public insurances;
    mapping(address => uint256[]) public insuranceHoldings;

    struct Incident {
        uint256 payoutNumerator;
        uint256 payoutDenominator;
        uint256 incidentTimestamp;
        bytes32[] targets;
    }
    Incident public incident;

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
                _conditions[0] <= _conditions[1],
            "ERROR: INITIALIZATION_BAD_CONDITIONS"
        );
        initialized = true;

        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        parameters = IParameters(_references[0]);
        vault = IVault(_references[1]);
        registry = IRegistry(_references[2]);

        metadata = _metaData;

        marketStatus = MarketStatus.Trading;

        if (_conditions[1] > 0) {
            deposit(_conditions[1]);
        }

        return true;
    }

    /**
     * Pool initeractions
     */

    /**
     * @notice A provider supplies token to the pool and receives iTokens
     */
    function deposit(uint256 _amount) public returns (uint256 _mintAmount) {
        require(
            marketStatus == MarketStatus.Trading &&
                paused == false &&
                _amount > 0,
            "ERROR: DEPOSIT_DISABLED"
        );

        _mintAmount = worth(_amount);

        uint256 _newAttribution = vault.addValue(
            _amount,
            msg.sender,
            address(this)
        );
        totalAttributions = totalAttributions.add(_newAttribution);

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
        uint256 _supply = totalSupply();
        uint256 _liquidity = vault.attributionValue(totalAttributions);
        _retVal = _divFloor(_amount.mul(_liquidity), _supply);
        require(
            marketStatus == MarketStatus.Trading &&
                withdrawalReq[msg.sender].timestamp.add(
                    parameters.getLockup(msg.sender)
                ) <
                now &&
                withdrawalReq[msg.sender]
                .timestamp
                .add(parameters.getLockup(msg.sender))
                .add(parameters.getWithdrawable(msg.sender)) >
                now &&
                _retVal <= availableBalance() &&
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
        uint256 _deductAttribution = vault.withdrawValue(_retVal, msg.sender);
        totalAttributions = totalAttributions.sub(_deductAttribution);

        emit Withdraw(msg.sender, _amount, _retVal);
    }

    /**
     * @notice Unlocks an array of insurances
     */
    function unlockBatch(uint256[] calldata _ids) external {
        for (uint256 i = 0; i < _ids.length; i++) {
            unlock(_ids[i]);
        }
    }

    /**
     * @notice Unlock funds locked in the expired insurance
     */
    function unlock(uint256 _id) public {
        Insurance storage insurance = insurances[_id];
        require(
            insurance.status == true &&
                marketStatus == MarketStatus.Trading &&
                insurance.endTime.add(parameters.getGrace(msg.sender)) < now,
            "ERROR: UNLOCK_BAD_COINDITIONS"
        );
        insurance.status == false;

        lockedAmount = lockedAmount.sub(insurance.amount);

        emit Unlocked(_id, insurance.amount);
    }

    /**
     * Index interactions
     */

    /**
     * @notice Allocate credit from indexes. Allocated credits are treated as equivalent to deposited real token.
     */

    function allocateCredit(uint256 _credit)
        external
        returns (uint256 _pending)
    {
        require(
            IRegistry(registry).isListed(msg.sender),
            "ERROR: ALLOCATE_BAD_CONDITIONS"
        );
        IndexInfo storage _index = indexes[msg.sender];
        if (indexes[msg.sender].exist == false) {
            indexes[msg.sender].exist = true;
            indexList.push(msg.sender);
        }
        if (_index.credit > 0) {
            _pending = _sub(
                _index.credit.mul(attributionPerCredit).div(1e12),
                _index.rewardDebt
            );
            if (_pending > 0) {
                vault.transferAttribution(_pending, msg.sender);
            }
        }
        if (_credit > 0) {
            totalCredit = totalCredit.add(_credit);
            indexes[msg.sender].credit = indexes[msg.sender].credit.add(
                _credit
            );
            emit CreditIncrease(msg.sender, _credit);
        }

        _index.rewardDebt = _index.credit.mul(attributionPerCredit).div(1e12);
    }

    /**
     * @notice An index withdraw credit and earn accrued premium
     */
    function withdrawCredit(uint256 _credit)
        external
        returns (uint256 _pending)
    {
        IndexInfo storage _index = indexes[msg.sender];
        require(
            IRegistry(registry).isListed(msg.sender) &&
                _index.credit >= _credit &&
                _credit <= availableBalance() &&
                _credit > 0,
            "ERROR: DEALLOCATE_BAD_CONDITIONS"
        );

        //calculate acrrued premium
        _pending = _sub(
            _index.credit.mul(attributionPerCredit).div(1e12),
            _index.rewardDebt
        );

        //Withdraw liquidity
        totalCredit = totalCredit.sub(_credit);
        indexes[msg.sender].credit = indexes[msg.sender].credit.sub(_credit);
        emit CreditDecrease(msg.sender, _credit);

        //withdraw acrrued premium
        if (_pending > 0) {
            vault.transferAttribution(_pending, msg.sender);
            _index.rewardDebt = _index.credit.mul(attributionPerCredit).div(
                1e12
            );
        }
    }

    /**
     * Insurance interactions
     */

    /**
     * @notice Get insured for the specified amount for specified span
     */
    function insure(
        uint256 _amount,
        uint256 _maxCost,
        uint256 _span,
        bytes32 _target
    ) external returns (uint256) {
        //Distribute premium and fee
        uint256 _endTime = _span.add(now);
        uint256 _premium = getPremium(_amount, _span);
        uint256 _fee = parameters.getFee(_premium, msg.sender);
        uint256 _deducted = _premium.sub(_fee);

        require(
            marketStatus == MarketStatus.Trading &&
                paused == false &&
                _amount <= availableBalance() &&
                _span <= 365 days &&
                _premium <= _maxCost &&
                parameters.getMin(msg.sender) <= _span,
            "ERROR: INSURE_BAD_CONDITIONS"
        );

        //accrue fee
        vault.addValue(_fee, msg.sender, parameters.get_owner());
        //accrue premium
        uint256 _newAttribution = vault.addValue(
            _deducted,
            msg.sender,
            address(this)
        );

        //Lock covered amount
        uint256 _id = insurances.length;
        lockedAmount = lockedAmount.add(_amount);
        Insurance memory _insurance = Insurance(
            _id,
            now,
            _endTime,
            _amount,
            _target,
            msg.sender,
            true
        );
        insurances.push(_insurance);
        insuranceHoldings[msg.sender].push(_id);

        //Calculate liquidity
        uint256 _attributionForIndex = _newAttribution.mul(totalCredit).div(
            totalLiquidity()
        );
        totalAttributions = totalAttributions.add(_newAttribution).sub(
            _attributionForIndex
        );
        if (totalCredit > 0) {
            attributionPerCredit = attributionPerCredit.add(
                _attributionForIndex.mul(1e12).div(totalCredit)
            );
        }

        emit Insured(_id, _amount, _target, now, _endTime, msg.sender);

        return _id;
    }

    /**
     * @notice Redeem an insurance policy
     */
    function redeem(uint256 _id) external {
        Insurance storage insurance = insurances[_id];

        uint256 _payoutNumerator = incident.payoutNumerator;
        uint256 _payoutDenominator = incident.payoutDenominator;
        uint256 _incidentTimestamp = incident.incidentTimestamp;
        bytes32[] memory _targets = incident.targets;
        bool isTarget;

        for (uint256 i = 0; i < _targets.length; i++) {
            if (_targets[i] == insurance.target) isTarget = true;
        }

        require(
            insurance.status == true &&
                insurance.insured == msg.sender &&
                marketStatus == MarketStatus.Payingout &&
                insurance.startTime <= _incidentTimestamp &&
                insurance.endTime >= _incidentTimestamp &&
                isTarget == true,
            "ERROR: INSURANCE_NOT_APPLICABLE"
        );
        insurance.status = false;
        lockedAmount = lockedAmount.sub(insurance.amount);

        uint256 _payoutAmount = insurance.amount.mul(_payoutNumerator).div(
            _payoutDenominator
        );
        uint256 _deductionFromIndex = _payoutAmount
        .mul(totalCredit)
        .mul(1e8)
        .div(totalLiquidity());

        for (uint256 i = 0; i < indexList.length; i++) {
            if (indexes[indexList[i]].credit > 0) {
                uint256 _shareOfIndex = indexes[indexList[i]]
                .credit
                .mul(1e8)
                .div(indexes[indexList[i]].credit);
                uint256 _redeemAmount = _divCeil(
                    _deductionFromIndex,
                    _shareOfIndex
                );
                IIndexTemplate(indexList[i]).compensate(_redeemAmount);
            }
        }

        uint256 _paidAttribution = vault.withdrawValue(
            _payoutAmount,
            msg.sender
        );
        uint256 _indexAttribution = _paidAttribution
        .mul(_deductionFromIndex)
        .div(1e8)
        .div(_payoutAmount);
        totalAttributions = totalAttributions.sub(
            _paidAttribution.sub(_indexAttribution)
        );
        emit Redeemed(
            _id,
            msg.sender,
            insurance.target,
            insurance.amount,
            _payoutAmount
        );
    }

    /**
     * @notice Transfers an active insurance
     */
    function transferInsurance(uint256 _id, address _to) external {
        Insurance storage insurance = insurances[_id];

        require(
            _to != address(0) &&
                insurance.insured == msg.sender &&
                insurance.endTime >= now &&
                insurance.status == true,
            "ERROR: INSURANCE_TRANSFER_BAD_CONDITIONS"
        );

        insurance.insured = _to;
    }

    /**
     * @notice Get how much premium for the specified amound and span
     */
    function getPremium(uint256 _amount, uint256 _span)
        public
        view
        returns (uint256 premium)
    {
        return
            parameters.getPremium(
                _amount,
                _span,
                totalLiquidity(),
                lockedAmount,
                msg.sender
            );
    }

    /**
     * Reporting interactions
     */

    /**
     * @notice Decision to make a payout
     */
    function applyCover(
        uint256 _pending,
        uint256 _payoutNumerator,
        uint256 _payoutDenominator,
        uint256 _incidentTimestamp,
        bytes32[] calldata _targets,
        string calldata _memo
    ) external onlyOwner {
        require(
            marketStatus != MarketStatus.Payingout,
            "ERROR: UNABLE_TO_APPLY"
        );
        incident.payoutNumerator = _payoutNumerator;
        incident.payoutDenominator = _payoutDenominator;
        incident.incidentTimestamp = _incidentTimestamp;
        incident.targets = _targets;
        marketStatus = MarketStatus.Payingout;
        pendingEnd = now.add(_pending);
        for (uint256 i = 0; i < indexList.length; i++) {
            if (indexes[indexList[i]].credit > 0) {
                IIndexTemplate(indexList[i]).lock(_pending);
            }
        }
        emit CoverApplied(
            _pending,
            _payoutNumerator,
            _payoutDenominator,
            _incidentTimestamp,
            _targets,
            _memo
        );
        emit MarketStatusChanged(marketStatus);
    }

    /**
     * @notice Anyone can resume the market after a pending period ends
     */
    function resume() external {
        require(
            marketStatus == MarketStatus.Payingout && pendingEnd < now,
            "ERROR: UNABLE_TO_RESUME"
        );
        marketStatus = MarketStatus.Trading;
        emit MarketStatusChanged(marketStatus);
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
    function allowance(address _owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[_owner][spender];
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
     * @notice Get the exchange rate of LP token against underlying asset(scaled by 1e18)
     */
    function rate() external view returns (uint256) {
        if (_totalSupply > 0) {
            return
                vault.attributionValue(totalAttributions).mul(1e18).div(
                    _totalSupply
                );
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
                _balance.mul(vault.attributionValue(totalAttributions)).div(
                    totalSupply()
                );
        }
    }

    /**
     * @notice Get the accrued value for an index
     */
    function pendingPremium(address _index) external view returns (uint256) {
        uint256 _credit = indexes[_index].credit;
        if (_credit == 0) {
            return 0;
        } else {
            return
                _sub(
                    _credit.mul(attributionPerCredit).div(1e12),
                    indexes[_index].rewardDebt
                );
        }
    }

    /**
     * @notice Get token number for the specified underlying value
     */
    function worth(uint256 _value) public view returns (uint256 _amount) {
        uint256 _supply = totalSupply();
        if (_supply > 0 && totalAttributions > 0) {
            _amount = _value.mul(_supply).div(
                vault.attributionValue(totalAttributions)
            );
        } else if (_supply > 0 && totalAttributions == 0) {
            _amount = _value.div(_supply);
        } else {
            _amount = _value;
        }
    }

    /**
     * @notice Get allocated credit
     */
    function allocatedCredit(address _index) public view returns (uint256) {
        return indexes[_index].credit;
    }

    /**
     * @notice Get the number of total insurances
     */
    function allInsuranceCount() public view returns (uint256) {
        return insurances.length;
    }

    /**
     * @notice Get the underlying balance of the `owner`
     */
    function getInsuranceCount(address _user) public view returns (uint256) {
        return insuranceHoldings[_user].length;
    }

    /**
     * @notice Returns the amount of underlying token available for withdrawals
     */
    function availableBalance() public view returns (uint256 _balance) {
        if (totalLiquidity() > 0) {
            return totalLiquidity().sub(lockedAmount);
        } else {
            return 0;
        }
    }

    /**
     * @notice Returns the utilization rate for this pool (should be divided by 1e10 to XX.XXX%)
     */
    function utilizationRate() public view returns (uint256 _rate) {
        if (lockedAmount > 0) {
            return lockedAmount.mul(1e8).div(totalLiquidity());
        } else {
            return 0;
        }
    }

    /**
     * @notice total Liquidity of the pool (how much can the pool sell cover)
     */
    function totalLiquidity() public view returns (uint256 _balance) {
        return vault.attributionValue(totalAttributions).add(totalCredit);
    }

    /**
     * @notice Get payout target arrays for frontend / external contracts
     */
    function getPayoutTargets() external view returns (bytes32[] memory) {
        return incident.targets;
    }

    /**
     * Admin functions
     */

    /**
     * @notice Pause the market and disable new deposit
     */
    function setPaused(bool state) external onlyOwner {
        paused = state;
        emit Paused(state);
    }

    /**
     * @notice Change metadata string
     */
    function changeMetadata(string calldata _metadata) external onlyOwner {
        metadata = _metadata;
        emit MetadataChanged(_metadata);
    }

    /**
     * Internal functions
     */

    /**
     * @notice Internal function to offset withdraw request and latest balance
     */
    function _beforeTokenTransfer(address _from, uint256 _amount) internal {
        //withdraw request operation
        uint256 _after = balanceOf(_from).sub(_amount);
        if (_after < withdrawalReq[_from].amount) {
            withdrawalReq[_from].amount = _after;
        }
    }

    /**
     * @notice Internal function for safe division
     */
    function _divCeil(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;
        if (a % b != 0) c = c + 1;
        return c;
    }

    /**
     * @notice Internal function for safe division
     */
    function _divFloor(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;
        if (a % b != 0) c = c - 1;
        return c;
    }

    /**
     * @notice Internal function for overflow free subtraction
     */
    function _sub(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a < b) {
            return 0;
        } else {
            return a - b;
        }
    }
}
