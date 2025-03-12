// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import "openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import "openzeppelin-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "openzeppelin-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IAdapter.sol";
import "./interfaces/IBalancer.sol";
import "./helpers/SwapExecutor.sol";


bytes32 constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE"); // timelock
bytes32 constant ADD_ADAPTER_ROLE = keccak256("ADD_ADAPTER_ROLE"); // timelock
bytes32 constant REMOVE_ADAPTER_ROLE = keccak256("REMOVE_ADAPTER_ROLE"); // timelock
bytes32 constant ACTIVATE_ADAPTER_ROLE = keccak256("ACTIVATE_ADAPTER_ROLE");
bytes32 constant DEACTIVATE_ADAPTER_ROLE = keccak256("DEACTIVATE_ADAPTER_ROLE");
bytes32 constant REBALANCE_ROLE = keccak256("REBALANCE_ROLE");
bytes32 constant COMPOUND_ROLE = keccak256("COMPOUND_ROLE");
bytes32 constant TAKE_PERFORMANCE_FEE_ROLE = keccak256("TAKE_PERFORMANCE_FEE_ROLE"); // timelock
bytes32 constant UPGRADE_ROLE = keccak256("UPGRADE_ROLE"); // timelock
bytes32 constant RECOVER_FUNDS_ROLE = keccak256("RECOVER_FUNDS_ROLE");
bytes32 constant SWAP_POOL_ADDRESSES_ADMIN_ROLE = keccak256("SWAP_POOL_ADDRESSES_ADMIN_ROLE"); // timelock

contract BalancerUpgradeable is IBalancer, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeERC20 for IERC20;

    uint256 public constant PERCENTAGE_COEFFICIENT = 1e6; // 100%
    uint256 public constant MAX_REBALANCE_VALUE_LOSS = PERCENTAGE_COEFFICIENT / 100; // 1%
    uint256 public constant MAX_UPGRADE_ADAPTER_VALUE_LOSS = PERCENTAGE_COEFFICIENT / 100000; // 0.001%
    uint256 public constant MAX_COMPOUND_PERFORMANCE_FEE = PERCENTAGE_COEFFICIENT / 20; // 5%
    uint256 public constant MAX_PROFIT_FACTOR = PERCENTAGE_COEFFICIENT / 100;  // 1%
    uint256 public constant REBALANCE_COOLDOWN = 6 hours; // 6 hour
    uint256 public constant TAKE_PROFIT_COOLDOWN = 1 days;

    uint256 public constant VALUE_DEGRADATION_COEFFICIENT = 1e18; // 100%
    
    uint256 public constant VALUE_DEGRADATION_DURATION = 7 days;
    uint256 public constant VALUE_DEGRADATION_RATE = VALUE_DEGRADATION_COEFFICIENT / VALUE_DEGRADATION_DURATION; // (0.0000016534*100)% per sec, 100% in 7 days

    
    SwapExecutor private immutable SWAP_EXECUTOR;
    uint256 public immutable DEPOSIT_FEE;
    IERC20 public immutable ABRA;
    EnumerableSetUpgradeable.AddressSet private $adapters;
    EnumerableSetUpgradeable.AddressSet private $chargedAdapters;    
    mapping(address => bool) public $isActiveAdapter;

    /**
     * @dev valueDecay holds amount of value that has to be subtracted from totalValue
     * When a strategy receives profit through gradual increase of it's undelyings value
     * we must periodically subtract our performance fee from the vault
     */
    /// @dev February 7, 2106 ought to be enough for anybody
    uint32  public $lastValueLock;
    uint112 public $valueDecayTarget; 

    uint32  public $lastRebalanceTime;
    uint32  public $lastTakeProfitTime;
    address public $feeReceiver;

    uint32  public $rewardPeriodFinish;
    uint32  public $rewardLastUpdateTime;
    uint256 public $rewardRate;
    uint256 public $rewardPerTokenStored;
    mapping(address => uint256) public $userRewardPerTokenPaid;
    mapping(address => uint256) public $rewards;
    address[] public $swapPoolAddresses;

    constructor(address _abra, address _swapExecutor, uint256 _depositFee) {
        ABRA = IERC20(_abra);
        if (_depositFee > PERCENTAGE_COEFFICIENT) {
            revert ('invalid deposit fee');
        }
        SWAP_EXECUTOR = SwapExecutor(_swapExecutor);
        DEPOSIT_FEE = _depositFee;
    }

    function initialize(string memory name_, string memory symbol_, address feeReceiver_) public initializer {
        __ERC20_init(name_, symbol_);
        __AccessControl_init();
        __ReentrancyGuard_init();
        $feeReceiver = feeReceiver_;
        // codesize optimization
        bytes32 _TIMELOCK_ADMIN_ROLE = TIMELOCK_ADMIN_ROLE;
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender()); // must be transferred to MULTISIG after deployment
        _grantRole(_TIMELOCK_ADMIN_ROLE, _msgSender()); // must be transferred to TIMELOCK after deployment
        
        _setRoleAdmin(ADD_ADAPTER_ROLE, _TIMELOCK_ADMIN_ROLE); 
        _setRoleAdmin(REMOVE_ADAPTER_ROLE, _TIMELOCK_ADMIN_ROLE); 
        _setRoleAdmin(TAKE_PERFORMANCE_FEE_ROLE, _TIMELOCK_ADMIN_ROLE); 
        _setRoleAdmin(UPGRADE_ROLE, _TIMELOCK_ADMIN_ROLE); 

        emit FeeReceiverChanged(address(0), feeReceiver_);
    }

    /** 
     * @param targetAdapter adapter which have been supplied with liquidity and should be accounted in minting
     * 
     */
    function invest(address targetAdapter, address receiver) external override nonReentrant returns (uint sharesWithChargedFee) {
        if (!$isActiveAdapter[targetAdapter]) {
            revert InvalidAdapter(targetAdapter);
        }

        (uint sharesAdded, uint valuePrior, uint valueAdded) = _processInvest(targetAdapter, receiver);

        sharesWithChargedFee = sharesAdded * (PERCENTAGE_COEFFICIENT - DEPOSIT_FEE) / PERCENTAGE_COEFFICIENT;

        emit Invest(targetAdapter, receiver, valuePrior, valueAdded, sharesAdded, sharesWithChargedFee);
        _mint(receiver, sharesWithChargedFee);
    }

    function redeem(uint shares, IAdapter targetAdapter, address receiver)
        external
        override 
        nonReentrant
        returns (
            address[] memory tokens,
            uint[] memory amounts
        )
    {
        uint b = balanceOf(msg.sender);
        if (b < shares) revert InsufficientFunds(b, shares);

        (uint tv, AdapterCache memory adapterCache) = _totalValueAndDetails(targetAdapter);
        (uint nav,) = _totalNAV(tv);

        uint redeemValue = _convertToValue(shares, nav);
        
        if (redeemValue > adapterCache.value) {
            revert AdapterRedeemExceeds(adapterCache.value, redeemValue);
        }

        if (redeemValue == 0) {
            revert EmptyRedeem(shares, redeemValue, address(targetAdapter), adapterCache.value, adapterCache.lpAmount);
        }

        emit Redeem(address(targetAdapter), receiver, shares, tv, redeemValue);
        _burn(msg.sender, shares);

        uint lpsToRedeem = adapterCache.lpAmount * redeemValue / adapterCache.value;
        uint lpsLeft = adapterCache.lpAmount - lpsToRedeem;

        if (lpsToRedeem == 0) {
            revert EmptyRedeem(shares, redeemValue, address(targetAdapter), adapterCache.value, adapterCache.lpAmount);
        }     

        if (lpsLeft == 0) {
            $chargedAdapters.remove(address(targetAdapter));
        }

        (tokens, amounts) = targetAdapter.redeem(lpsToRedeem, receiver);
    }
        
    function _processInvest(
        address targetAdapter, 
        address receiver
    ) internal returns (uint sharesToMint, uint valuePrior, uint valueAdded) {
        return _processInvestOrCompound(targetAdapter, receiver, false, new SwapInfo[](0));
    }

    function _processCompound(
        address targetAdapter, 
        SwapInfo[] memory swaps
    ) internal returns (uint sharesToMint, uint valuePrior, uint valueAdded) {
        return _processInvestOrCompound(targetAdapter, address(0), true, swaps);
    }

    function _processInvestOrCompound(
        address targetAdapter, 
        address receiver,
        bool isCompound,
        SwapInfo[] memory swaps
    ) internal returns (uint sharesToMint, uint valuePrior, uint valueAdded) {

        uint l = $chargedAdapters.length();
        bool isNewAdapter = true;

        for (uint i=0; i < l; i++) {
            IAdapter adapter = IAdapter($chargedAdapters.at(i));
            if (targetAdapter == address(adapter)) {
                isNewAdapter = false;

                uint valueBefore;
                uint valueAfter;
                if (isCompound) {
                    (valueBefore, valueAfter) = adapter.compound(swaps);
                } else {
                   (valueBefore, valueAfter) = adapter.invest(receiver);
                }

                valuePrior += valueBefore;
                valueAdded += valueAfter - valueBefore;
            } else {
                (uint v,) = adapter.value();
                valuePrior += v;
            }
        }

        if (isNewAdapter) {
            $chargedAdapters.add(targetAdapter);
            IAdapter adapter = IAdapter(targetAdapter);

            uint valueAfter;
            if (isCompound) {
                (, valueAfter) = adapter.compound(swaps);
            } else {
                (, valueAfter) = adapter.invest(receiver);
            }

            valueAdded += valueAfter;
        }

        // subtract all unreleased profits and taken fees;
        // Note that nav can be 0 while valuePrior > 0 
        (uint nav,) = _totalNAV(valuePrior);


        // shouldn't be susceptible to inflation attacks, since `valuePrior` can only increase through adding shares (???)
        sharesToMint = _convertToShares(valueAdded, nav);

        // still, some protection isn't going to hurt
        if (sharesToMint == 0) {
            revert SharesInflationError(valueAdded, nav);
        }
    }

    function _convertToShares(uint value, uint nav) internal view returns (uint) {
        if (nav == 0) {
            return value;
        }
        uint totalSupply = totalSupply();
        if (totalSupply == 0) {
            return value;
        }
        return value * totalSupply / nav;
    }

    function _convertToValue(uint shares, uint nav) internal view returns (uint) {
        return shares * nav / totalSupply();
    }

    function _lockedFunds() internal view returns (uint112 lockedFee) {        
        uint degradationRatio = uint256(block.timestamp - $lastValueLock) * VALUE_DEGRADATION_RATE;

        // if decayRatio >= 100% we consider that all fees were locked so, from now on we use entire target value
        if (degradationRatio < VALUE_DEGRADATION_COEFFICIENT) {
           lockedFee = uint112(uint256($valueDecayTarget) * degradationRatio / VALUE_DEGRADATION_COEFFICIENT);
        } else {
           lockedFee = $valueDecayTarget;
        }
    }

    /**
     * @param value Value in equivalent
     * @return nav Net Asset Value
     * @return lockedFee Performance fee that we periodically take, increases every second
     */
    function _totalNAV(uint value) internal view returns (uint nav, uint112 lockedFee) {
        lockedFee = _lockedFunds();
        nav = value > lockedFee ? value - lockedFee : 0;
    }
    
    function totalNAV() external override view returns (uint nav, uint112 lockedFee) {
        uint tv = totalValue();
        return _totalNAV(tv);
    }

    function totalValue() public override view returns (uint value) {
       (value,) = _totalValueAndDetails(IAdapter(address(0)));
    }

    function _totalValueAndDetails(IAdapter targetAdapter) internal view returns (uint value, AdapterCache memory cache) {
        uint l = $chargedAdapters.length();

        for (uint i=0; i < l; i++) {
            IAdapter adapter = IAdapter($chargedAdapters.at(i));
            (uint v, uint a) = adapter.value();             
            value += v;
            if (adapter == targetAdapter) {
                cache.value = v;
                cache.lpAmount = a;
            }
        }
    }

    /**
     * @dev Return the entire set of adapters in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function adapters() external override view returns (address[] memory) {
        return $adapters.values();
    }

    /**
     * @dev Return the entire set of charged adapters in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function chargedAdapters() external override view returns (address[] memory) {
        return $chargedAdapters.values();
    }

    function swapExecutor() external override view returns (address) {
        return address(SWAP_EXECUTOR);
    }

    //╔═══════════════════════════════════════════ ADMINISTRATIVE FUNCTIONS ═══════════════════════════════════════════╗

    function setFeeReceiver(address feeReceiver_) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        emit FeeReceiverChanged($feeReceiver, feeReceiver_);
        $feeReceiver = feeReceiver_;
    }

    function addAdapter(address adapterAddress) external override onlyRole(ADD_ADAPTER_ROLE) returns (bool isAdded) {
        IAdapter adapter = IAdapter(adapterAddress);
        (uint v, uint a) = adapter.value();
        if (v != 0 || a != 0) {
            revert AdapterNotEmpty(adapterAddress);
        }
        isAdded = $adapters.add(adapterAddress);
        if (isAdded) {
            emit AdapterAdded(adapterAddress);
        }
    }

    function removeAdapter(address adapterAddress) external override onlyRole(REMOVE_ADAPTER_ROLE) returns (bool) {
        if ($adapters.contains(adapterAddress)) {
            IAdapter adapter = IAdapter(adapterAddress);
            (uint v, uint a) = adapter.value();
            if (v != 0 || a != 0) {
                revert AdapterNotEmpty(adapterAddress);
            }
            _deactivateAdapter(adapterAddress);
            emit AdapterRemoved(adapterAddress);
            return $adapters.remove(adapterAddress);
        }
        return false;
    }

    function activateAdapter(address adapterAddress) external override onlyRole(ACTIVATE_ADAPTER_ROLE) returns (bool) {
        uint l = $adapters.length();

        for (uint i=0; i < l; i++) {
            if ($adapters.at(i) == adapterAddress) {
                $isActiveAdapter[adapterAddress] = true;
                emit AdapterActivityChanged(adapterAddress, true);
                return true;
            }
        }

        return false;
    }

    function deactivateAdapter(address adapterAddress) external override onlyRole(DEACTIVATE_ADAPTER_ROLE) {
        _deactivateAdapter(adapterAddress);
    }

    function _deactivateAdapter(address adapterAddress) internal {
        $isActiveAdapter[adapterAddress] = false;
        emit AdapterActivityChanged(adapterAddress, false);
    }

    function rebalance(
        IAdapter fromAdapter,
        IAdapter toAdapter,
        uint lpAmount,
        SwapInfo[] calldata swaps,
        TransferInfo[] calldata transfers,
        uint minRebalancedValue,
        uint32 deadline
    ) external override onlyRole(REBALANCE_ROLE) nonReentrant {
        if (deadline < block.timestamp) {
            revert Expired(deadline);
        }
        if (!$isActiveAdapter[address(toAdapter)]) {
            revert InvalidAdapter(address(toAdapter));
        }
        if ($lastRebalanceTime + REBALANCE_COOLDOWN > block.timestamp) {
            revert Cooldown($lastRebalanceTime + REBALANCE_COOLDOWN);
        }      
        
        (uint valueTotalBefore, uint totalLp) = fromAdapter.value();
        if (totalLp < lpAmount) {
            revert InsufficientFunds(totalLp, lpAmount);
        }
        uint rebalancedValueBefore = lpAmount * valueTotalBefore / totalLp;              

        fromAdapter.redeem(lpAmount, address(this));

        for (uint i = 0; i < swaps.length; i++) {
            IBalancer.SwapInfo calldata swap = swaps[i];
            SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(swap.token), address(SWAP_EXECUTOR), swap.amount);
        }
        SWAP_EXECUTOR.executeSwaps(swaps);

        for (uint i = 0; i < transfers.length; i++) {
            TransferInfo calldata transfer = transfers[i];
            SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(transfer.token), address(toAdapter), transfer.amount);
        }

        (uint vb, uint va) = toAdapter.invest(address(this));
        
        {
            uint rebalancedValueAfter = va - vb;
            if (rebalancedValueAfter < rebalancedValueBefore) { 
                uint diff = rebalancedValueBefore - rebalancedValueAfter;
                if (diff * PERCENTAGE_COEFFICIENT / rebalancedValueBefore > MAX_REBALANCE_VALUE_LOSS) {
                    revert ValueLost(diff);
                }
            }
            if (rebalancedValueAfter < minRebalancedValue) {
                revert MinRebalanceSlippageExceeds(minRebalancedValue, rebalancedValueAfter);
            }
        }

        $lastRebalanceTime = uint32(block.timestamp);
        emit Rebalance(address(fromAdapter), address(toAdapter), lpAmount);  
    }

    function upgradeAdapter(
        IAdapter sourceAdapter,
        IAdapter targetAdapter,        
        uint32   deadline
    )  external override onlyRole(REBALANCE_ROLE) nonReentrant {
        if (deadline < block.timestamp) {
            revert Expired(deadline);
        }        
        if (!$isActiveAdapter[address(targetAdapter)]) {
            revert InvalidAdapter(address(targetAdapter));
        }
      
        // check that both adapters have the same set of tokens
        address[] memory sourceTokens = sourceAdapter.depositTokens();
        address[] memory targetTokens = targetAdapter.depositTokens();
        if (sourceTokens.length != targetTokens.length) {
            revert UpgradeAdaptersDontMatch(address(sourceAdapter), address(targetAdapter));
        }
        for (uint i = 0; i < sourceTokens.length; i++) {
            (address sourceToken, address targetToken) = (sourceTokens[i], targetTokens[i]);
            if (sourceToken != targetToken) {
                revert UpgradeAdaptersDontMatch(address(sourceAdapter), address(targetAdapter));
            }
        }

        (uint sourceValueBefore, uint sourceLPAmount) = sourceAdapter.value();

        sourceAdapter.redeem(sourceLPAmount, address(targetAdapter));

        (uint targetValueBefore, uint targetValueAfter) = targetAdapter.invest(address(this));
        uint targetValueIncrease = targetValueAfter - targetValueBefore;

        // sanity checks
        if (targetValueIncrease < sourceValueBefore) { 
            uint diff = sourceValueBefore - targetValueIncrease;  
            if (PERCENTAGE_COEFFICIENT * diff / sourceValueBefore > MAX_UPGRADE_ADAPTER_VALUE_LOSS) {
                revert ValueLost(diff);
            }
        }

        emit Rebalance(address(sourceAdapter), address(targetAdapter), sourceLPAmount);
    }
        
    function compound(
        address adapter, 
        uint performanceFee, 
        SwapInfo[] calldata swaps, 
        uint256 minTokensBought,
        uint32 deadline
    ) external override onlyRole(COMPOUND_ROLE) nonReentrant returns (uint tokensBought) {
        if (deadline < block.timestamp) {
            revert Expired(deadline);
        }
        if (!$adapters.contains(adapter)) {
            revert InvalidAdapter(adapter);
        }
        if (performanceFee > MAX_COMPOUND_PERFORMANCE_FEE) {
            revert InvalidPerformanceFee(performanceFee);
        }

        (uint sharesToMint, uint valuePrior, uint valueAdded) = _processCompound(adapter, swaps);
        _mint(address(SWAP_EXECUTOR), sharesToMint);

        tokensBought = SWAP_EXECUTOR.defaultSwap(address(this), address(ABRA), minTokensBought, deadline);

        uint fee = tokensBought * performanceFee / PERCENTAGE_COEFFICIENT;
        ABRA.safeTransfer($feeReceiver, fee);

        emit Compound(adapter, valuePrior, valueAdded, tokensBought, fee);
        _lockToken(tokensBought - fee);
    }

    function takePerformanceFee(
        uint112 feeValue,
        uint256 minTokensBought,
        uint32 deadline
    ) 
        external 
        override 
        onlyRole(TAKE_PERFORMANCE_FEE_ROLE) 
        nonReentrant 
    {
        if ($lastTakeProfitTime + TAKE_PROFIT_COOLDOWN > block.timestamp) {
            revert Cooldown($lastTakeProfitTime + TAKE_PROFIT_COOLDOWN);
        }

        uint tv = totalValue();
        if (feeValue > tv) {
            revert InsufficientFunds(tv, feeValue);
        }
        if (feeValue * PERCENTAGE_COEFFICIENT / tv > MAX_PROFIT_FACTOR) {
            revert HugePerformanceFee(feeValue, tv);
        }

        _lockFee(feeValue, minTokensBought, deadline);

        emit TakePerformanceFee(feeValue, tv);
        $lastTakeProfitTime = uint32(block.timestamp);
    }

    function recoverFunds(
        address adapter, 
        TransferInfo calldata transfer, 
        address to
    )   
        external 
        virtual 
        override 
        onlyRole(RECOVER_FUNDS_ROLE)
    {
        IAdapter(adapter).recoverFunds(transfer, to);
    }

    function _lockFee(uint112 feeToLock, uint256 minTokensBought, uint256 deadline) internal {
        uint tv = totalValue();
        (uint nav, uint112 lockedFee) = _totalNAV(tv);

        // if any fee was locked then convert it to shares and decrease lock fee target
        if (lockedFee > 0) {
            uint shares = _convertToShares(lockedFee, nav);
            $valueDecayTarget -= lockedFee;
            _mint(address(SWAP_EXECUTOR), shares);

            uint tokenAmount = SWAP_EXECUTOR.defaultSwap(address(this), address(ABRA), minTokensBought, deadline);
            ABRA.safeTransfer($feeReceiver, tokenAmount);
        } else {
            if (minTokensBought > 0) {
                revert ('Unlocked fee is empty');
            }
        }

        // new target for value decay
        $valueDecayTarget += feeToLock;

        $lastValueLock = uint32(block.timestamp);
        emit FeeLocked(tv, feeToLock, block.timestamp + VALUE_DEGRADATION_DURATION);
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADE_ROLE) {}

    function addSwapPoolAddress(address swapPool) external onlyRole(SWAP_POOL_ADDRESSES_ADMIN_ROLE) {
        $swapPoolAddresses.push(swapPool);
        emit SwapPoolAddressAdded(swapPool);
    }

    function removeSwapPoolAddress(uint index) external onlyRole(SWAP_POOL_ADDRESSES_ADMIN_ROLE) {
        uint _length = $swapPoolAddresses.length;
        if (index >= _length) {
            revert ArrayIndexOutOfBounds();
        }
        address element = $swapPoolAddresses[index];
        if (index < _length - 1) {
            $swapPoolAddresses[index] = $swapPoolAddresses[$swapPoolAddresses.length - 1];
        }
        $swapPoolAddresses.pop();
        emit SwapPoolAddressRemoved(element);
    }

    //╔═══════════════════════════════════════════ GAUGE FUNCTIONS ═══════════════════════════════════════════╗

    ///@notice last time reward
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < $rewardPeriodFinish ? block.timestamp : $rewardPeriodFinish;
    }

    ///@notice  reward for a single token
    function rewardPerToken() public view returns (uint256 _rewardPerToken) {
        _rewardPerToken = $rewardPerTokenStored;
        uint256 _lastTimeRewardApplicable = lastTimeRewardApplicable();
        if (_lastTimeRewardApplicable > $rewardLastUpdateTime) {
            uint256 _totalSupply = totalSupply();
            if (_totalSupply != 0) {
                _rewardPerToken += (_lastTimeRewardApplicable - $rewardLastUpdateTime) * $rewardRate * 1e18 / _totalSupply;
            }
        }
    }

    ///@notice see earned rewards for user
    function earned(address account) public view returns (uint256) {
        return $rewards[account] + balanceOf(account) * (rewardPerToken() - $userRewardPerTokenPaid[account]) / 1e18;
    }

    ///@notice User harvest function
    function getReward() external {
        uint reward = _getReward(msg.sender);
        if (reward > 0) {
            ABRA.safeTransfer(msg.sender, reward);
        }
    }
    
    function getSwapPoolsReward() external returns (uint reward) {
        uint l = $swapPoolAddresses.length;
        for (uint i = 0; i < l; i++) {
            reward += _getReward($swapPoolAddresses[i]);
        }
        if (reward > 0) {
            ABRA.safeTransfer($feeReceiver, reward);
        }
    }

    function _getReward(address from) internal returns (uint reward){
        reward = earned(from);
        if (reward > 0) {
            updateRewardPerTokenStored();
            $userRewardPerTokenPaid[from] = $rewardPerTokenStored;
            $rewards[from] = 0;
            emit Harvest(from, reward);
        }
    }

    function updateRewardPerTokenStored() private {
        uint256 _lastTimeRewardApplicable = lastTimeRewardApplicable();
        if (_lastTimeRewardApplicable > $rewardLastUpdateTime) {
            // some reward should be in case _lastTimeRewardApplicable > rewardLastUpdateTime so no need to save gas checking rewardPerToken() differs from rewardPerTokenStored
            $rewardPerTokenStored = rewardPerToken();
            $rewardLastUpdateTime = uint32(_lastTimeRewardApplicable);
        }
    }

    function updateReward(address account) private {
        // always must be called only after updateRewardPerTokenStored
        if (account != address(0)) {
            uint256 _earned = earned(account);
            if (_earned > $rewards[account]) {
                $rewards[account] = _earned;
            }
            uint256 _rewardPerTokenStored = $rewardPerTokenStored;
            if (_rewardPerTokenStored > $userRewardPerTokenPaid[account]) {
                $userRewardPerTokenPaid[account] = $rewardPerTokenStored;
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 /*amount*/
    ) internal override {
        updateRewardPerTokenStored();
        updateReward(from);
        updateReward(to);
    }

    function _lockToken(uint reward) private {
        // codesize optimization
        uint _VALUE_DEGRADATION_DURATION = VALUE_DEGRADATION_DURATION;
        updateRewardPerTokenStored();
        uint256 _rewardPeriodFinish = $rewardPeriodFinish;
        if (block.timestamp >= _rewardPeriodFinish) {
            $rewardRate = reward / _VALUE_DEGRADATION_DURATION;
        } else {
            uint256 remaining = _rewardPeriodFinish - block.timestamp;
            uint256 leftover = remaining * $rewardRate;
            $rewardRate = (reward + leftover) / _VALUE_DEGRADATION_DURATION;
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = ABRA.balanceOf(address(this));
        require($rewardRate <= balance / _VALUE_DEGRADATION_DURATION, "Provided reward too high");

        $rewardLastUpdateTime = uint32(block.timestamp);
        $rewardPeriodFinish = uint32(block.timestamp + _VALUE_DEGRADATION_DURATION);
        emit RewardLocked(reward, block.timestamp + _VALUE_DEGRADATION_DURATION);
    }
}