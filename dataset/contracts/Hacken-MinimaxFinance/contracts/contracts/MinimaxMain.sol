// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./helpers/Math.sol";
import "./interfaces/IMinimaxStaking.sol";
import "./MinimaxStaking.sol";
import "./pool/IPoolAdapter.sol";
import "./interfaces/IERC20Decimals.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IPancakeRouter.sol";
import "./interfaces/ISmartChef.sol";
import "./interfaces/IGelatoOps.sol";
import "./interfaces/IWrapped.sol";
import "./ProxyCaller.sol";
import "./ProxyCallerApi.sol";
import "./ProxyPool.sol";
import "./market/Market.sol";
import "./PositionInfo.sol";
import "./PositionExchangeLib.sol";
import "./PositionBalanceLib.sol";
import "./PositionLib.sol";
import "./interfaces/IMinimaxMain.sol";
import "./market/v2/IPairToken.sol";

/*
    MinimaxMain
*/
contract MinimaxMain is IMinimaxMain, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    // -----------------------------------------------------------------------------------------------------------------
    // Using declarations.

    using SafeERC20Upgradeable for IERC20Upgradeable;

    using ProxyCallerApi for ProxyCaller;

    using ProxyPool for ProxyCaller[];

    // -----------------------------------------------------------------------------------------------------------------
    // Enums.

    enum ClosePositionReason {
        WithdrawnByOwner,
        LiquidatedByAutomation
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Events.

    // NB: If `estimatedStakedTokenPrice` is equal to `0`, then the price is unavailable for some reason.

    event PositionWasCreated(uint indexed positionIndex);
    event PositionWasCreatedV2(
        uint indexed positionIndex,
        uint timestamp,
        uint stakedTokenPrice,
        uint8 stakedTokenPriceDecimals
    );

    event PositionWasModified(uint indexed positionIndex);

    event PositionWasClosed(uint indexed positionIndex);
    event PositionWasClosedV2(
        uint indexed positionIndex,
        uint timestamp,
        uint stakedTokenPrice,
        uint8 stakedTokenPriceDecimals
    );

    event PositionWasLiquidatedV2(
        uint indexed positionIndex,
        uint timestamp,
        uint stakedTokenPrice,
        uint8 stakedTokenPriceDecimals
    );

    // -----------------------------------------------------------------------------------------------------------------
    // Storage.

    uint public constant FEE_MULTIPLIER = 1e8;
    uint public constant SLIPPAGE_MULTIPLIER = 1e8;
    uint public constant POSITION_PRICE_LIMITS_MULTIPLIER = 1e8;

    address public cakeAddress; // TODO: remove when deploy clean version

    // BUSD for BSC, USDT for POLYGON
    address public busdAddress; // TODO: rename to stableToken when deploy clean version

    address public minimaxStaking;

    uint public lastPositionIndex;

    // Use mapping instead of array for upgradeability of PositionInfo struct
    mapping(uint => PositionInfo) public positions;

    mapping(address => bool) public isLiquidator;

    ProxyCaller[] public proxyPool;

    // Fee threshold
    struct FeeThreshold {
        uint fee;
        uint stakedAmountThreshold;
    }

    FeeThreshold[] public depositFees;

    /// @custom:oz-renamed-from poolAdapters
    mapping(address => IPoolAdapter) public poolAdaptersDeprecated;

    mapping(IERC20Upgradeable => IPriceOracle) public priceOracles;

    // TODO: deprecated
    mapping(address => address) public tokenExchanges;

    // gelato
    IGelatoOps public gelatoOps;

    address payable public gelatoPayee;

    mapping(address => uint256) public gelatoLiquidateFee; // TODO: remove when deploy clean version
    uint256 public stakeGelatoFee; // TODO: rename to stakeGelatoFee
    address public gelatoFeeToken; // TODO: remove when deploy clean version

    // TODO: deprecated
    address public defaultExchange;

    // poolAdapters by bytecode hash
    mapping(uint256 => IPoolAdapter) public poolAdapters;

    IMarket public market;

    address public wrappedNative;

    address public oneInchRouter;

    // -----------------------------------------------------------------------------------------------------------------
    // Methods.

    function setGasTankThreshold(uint256 value) external onlyOwner {
        stakeGelatoFee = value;
    }

    function setGelatoOps(address _gelatoOps) external onlyOwner {
        gelatoOps = IGelatoOps(_gelatoOps);
    }

    function setLastPositionIndex(uint newLastPositionIndex) external onlyOwner {
        require(newLastPositionIndex >= lastPositionIndex, "last position index may only be increased");
        lastPositionIndex = newLastPositionIndex;
    }

    function getPoolAdapterKey(address pool) public view returns (uint256) {
        return uint256(keccak256(pool.code));
    }

    function getPoolAdapter(address pool) public view returns (IPoolAdapter) {
        uint256 key = getPoolAdapterKey(pool);
        return poolAdapters[key];
    }

    function getPoolAdapterSafe(address pool) public view returns (IPoolAdapter) {
        IPoolAdapter adapter = getPoolAdapter(pool);
        require(address(adapter) != address(0), "pool adapter not found");
        return adapter;
    }

    function getPoolAdapters(address[] calldata pools)
        public
        view
        returns (IPoolAdapter[] memory adapters, uint256[] memory keys)
    {
        adapters = new IPoolAdapter[](pools.length);
        keys = new uint256[](pools.length);
        for (uint i = 0; i < pools.length; i++) {
            uint256 key = getPoolAdapterKey(pools[i]);
            keys[i] = key;
            adapters[i] = poolAdapters[key];
        }
    }

    // Staking pool adapters
    function setPoolAdapters(address[] calldata pools, IPoolAdapter[] calldata adapters) external onlyOwner {
        require(pools.length == adapters.length, "pools and adapters parameters should have the same length");
        for (uint32 i = 0; i < pools.length; i++) {
            uint256 key = getPoolAdapterKey(pools[i]);
            poolAdapters[key] = adapters[i];
        }
    }

    // Price oracles
    function setPriceOracles(IERC20Upgradeable[] calldata tokens, IPriceOracle[] calldata oracles) external onlyOwner {
        require(tokens.length == oracles.length, "tokens and oracles parameters should have the same length");
        for (uint32 i = 0; i < tokens.length; i++) {
            priceOracles[tokens[i]] = oracles[i];
        }
    }

    function getPriceOracleSafe(IERC20Upgradeable token) public view returns (IPriceOracle) {
        IPriceOracle oracle = priceOracles[token];
        require(address(oracle) != address(0), "price oracle not found");
        return oracle;
    }

    function setMarket(IMarket _market) external onlyOwner {
        market = _market;
    }

    function setWrappedNative(address _native) external onlyOwner {
        wrappedNative = _native;
    }

    function setOneInchRouter(address _router) external onlyOwner {
        oneInchRouter = _router;
    }

    modifier onlyAutomator() {
        require(msg.sender == address(gelatoOps) || isLiquidator[address(msg.sender)], "onlyAutomator");
        _;
    }

    function initialize(
        address _minimaxStaking,
        address _busdAddress,
        address _gelatoOps
    ) external initializer {
        minimaxStaking = _minimaxStaking;
        busdAddress = _busdAddress;
        gelatoOps = IGelatoOps(_gelatoOps);

        __Ownable_init();
        __ReentrancyGuard_init();

        // staking pool
        depositFees.push(
            FeeThreshold({
                fee: 100000, // 0.1%
                stakedAmountThreshold: 1000 * 1e18 // all stakers <= 1000 MMX would have 0.1% fee for deposit
            })
        );

        depositFees.push(
            FeeThreshold({
                fee: 90000, // 0.09%
                stakedAmountThreshold: 5000 * 1e18
            })
        );

        depositFees.push(
            FeeThreshold({
                fee: 80000, // 0.08%
                stakedAmountThreshold: 10000 * 1e18
            })
        );

        depositFees.push(
            FeeThreshold({
                fee: 70000, // 0.07%
                stakedAmountThreshold: 50000 * 1e18
            })
        );
        depositFees.push(
            FeeThreshold({
                fee: 50000, // 0.05%
                stakedAmountThreshold: 10000000 * 1e18 // this level doesn't matter
            })
        );
    }

    receive() external payable {}

    function getSlippageMultiplier() public pure returns (uint) {
        return SLIPPAGE_MULTIPLIER;
    }

    function getUserFee(address user) public view returns (uint) {
        IMinimaxStaking staking = IMinimaxStaking(minimaxStaking);

        uint amountPool2 = staking.getUserAmount(2, user);
        uint amountPool3 = staking.getUserAmount(3, user);
        uint totalStakedAmount = amountPool2 + amountPool3;

        uint length = depositFees.length;

        for (uint bucketId = 0; bucketId < length; ++bucketId) {
            uint threshold = depositFees[bucketId].stakedAmountThreshold;
            if (totalStakedAmount <= threshold) {
                return depositFees[bucketId].fee;
            }
        }

        return depositFees[length - 1].fee;
    }

    function getUserFeeAmount(address user, uint amount) public view returns (uint) {
        uint userFeeShare = getUserFee(user);
        return (amount * userFeeShare) / FEE_MULTIPLIER;
    }

    function getPositionInfo(uint positionIndex) external view returns (PositionInfo memory) {
        return positions[positionIndex];
    }

    function fillProxyPool(uint amount) external onlyOwner {
        proxyPool.add(amount);
    }

    function cleanProxyPool() external onlyOwner {
        delete proxyPool;
    }

    function transferTo(
        address token,
        address to,
        uint amount
    ) external onlyOwner {
        address nativeToken = address(0);
        if (token == nativeToken) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "transferTo: BNB transfer failed");
        } else {
            SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(token), to, amount);
        }
    }

    function setDepositFee(uint poolIdx, uint feeShare) external onlyOwner {
        require(poolIdx < depositFees.length, "wrong pool index");
        depositFees[poolIdx].fee = feeShare;
    }

    function setMinimaxStakingAddress(address stakingAddress) external onlyOwner {
        minimaxStaking = stakingAddress;
    }

    function getPositionBalances(uint[] calldata positionIndexes)
        public
        returns (PositionBalanceLib.PositionBalance[] memory)
    {
        return PositionBalanceLib.getMany(this, positions, positionIndexes);
    }

    function _stakeToken(
        PositionLib.StakeParams memory stakeParams,
        uint swapKind,
        bytes memory swapParams
    ) private returns (uint) {
        require(msg.value >= stakeGelatoFee, "gasTankThreshold");

        uint positionIndex = lastPositionIndex;
        lastPositionIndex += 1;

        PositionInfo memory position = PositionLib.stake(
            this,
            proxyPool.acquire(),
            positionIndex,
            stakeParams,
            swapKind,
            swapParams
        );

        if (address(gelatoOps) != address(0)) {
            position.gelatoLiquidateTaskId = _gelatoCreateTask(positionIndex);
            depositGasTank(position.callerAddress);
        }

        positions[positionIndex] = position;
        emitPositionWasCreated(positionIndex, position.stakedToken);
        return positionIndex;
    }

    function stake(
        uint inputAmount,
        IERC20Upgradeable inputToken,
        uint stakingAmountMin,
        IERC20Upgradeable stakingToken,
        address stakingPool,
        uint maxSlippage,
        uint stopLossPrice,
        uint takeProfitPrice,
        uint swapKind,
        bytes calldata swapParams
    ) public payable nonReentrant returns (uint) {
        return
            _stakeToken(
                PositionLib.StakeParams(
                    inputAmount,
                    inputToken,
                    stakingAmountMin,
                    stakingToken,
                    stakingPool,
                    maxSlippage,
                    stopLossPrice,
                    takeProfitPrice
                ),
                swapKind,
                swapParams
            );
    }

    function stakeToken(
        IERC20Upgradeable stakingToken,
        address stakingPool,
        uint tokenAmount,
        uint maxSlippage,
        uint stopLossPrice,
        uint takeProfitPrice
    ) public payable nonReentrant returns (uint) {
        return
            _stakeToken(
                PositionLib.StakeParams(
                    tokenAmount,
                    stakingToken,
                    tokenAmount,
                    stakingToken,
                    stakingPool,
                    maxSlippage,
                    stopLossPrice,
                    takeProfitPrice
                ),
                PositionLib.StakeSimpleKind,
                ""
            );
    }

    function swapStakeToken(
        IERC20Upgradeable inputToken,
        IERC20Upgradeable stakingToken,
        address stakingPool,
        uint inputTokenAmount,
        uint stakingTokenAmountMin,
        uint maxSlippage,
        uint stopLossPrice,
        uint takeProfitPrice,
        bytes memory hints
    ) public payable nonReentrant returns (uint) {
        return
            _stakeToken(
                PositionLib.StakeParams(
                    inputTokenAmount,
                    inputToken,
                    stakingTokenAmountMin,
                    stakingToken,
                    stakingPool,
                    maxSlippage,
                    stopLossPrice,
                    takeProfitPrice
                ),
                PositionLib.StakeSwapMarketKind,
                abi.encode(PositionLib.StakeSwapMarket(hints))
            );
    }

    function swapStakeTokenOneInch(
        IERC20Upgradeable inputToken,
        IERC20Upgradeable stakingToken,
        address stakingPool,
        uint inputTokenAmount,
        uint maxSlippage,
        uint stopLossPrice,
        uint takeProfitPrice,
        bytes memory oneInchCallData
    ) public payable nonReentrant returns (uint) {
        return
            _stakeToken(
                PositionLib.StakeParams(
                    inputTokenAmount,
                    inputToken,
                    0,
                    stakingToken,
                    stakingPool,
                    maxSlippage,
                    stopLossPrice,
                    takeProfitPrice
                ),
                PositionLib.StakeSwapOneInchKind,
                abi.encode(PositionLib.StakeSwapOneInch(oneInchCallData))
            );
    }

    function swapStakeTokenEstimate(
        address inputToken,
        address stakingToken,
        uint inputTokenAmount,
        bool tokenInPair,
        bool tokenOutPair
    ) public view returns (uint amountOut, bytes memory hints) {
        require(address(market) != address(0), "no market");
        return market.estimateOut(inputToken, stakingToken, inputTokenAmount);
    }

    function swapEstimate(
        address inputToken,
        address stakingToken,
        uint inputTokenAmount
    ) public view returns (uint amountOut, bytes memory hints) {
        require(address(market) != address(0), "no market");
        return market.estimateOut(inputToken, stakingToken, inputTokenAmount);
    }

    function deposit(uint positionIndex, uint amount) external nonReentrant {
        PositionInfo storage position = positions[positionIndex];

        PositionLib.deposit(this, position, positionIndex, amount);
        emit PositionWasModified(positionIndex);
    }

    function setLiquidator(address user, bool value) external onlyOwner {
        isLiquidator[user] = value;
    }

    function alterPositionParams(
        uint positionIndex,
        uint newAmount,
        uint newStopLossPrice,
        uint newTakeProfitPrice,
        uint newSlippage
    ) external nonReentrant {
        PositionInfo storage position = positions[positionIndex];
        bool shouldClose = PositionLib.alterPositionParams(
            this,
            position,
            positionIndex,
            newAmount,
            newStopLossPrice,
            newTakeProfitPrice,
            newSlippage
        );
        if (shouldClose) {
            closePosition(positionIndex, ClosePositionReason.WithdrawnByOwner);
        } else {
            emit PositionWasModified(positionIndex);
        }
    }

    function withdrawImpl(
        uint positionIndex,
        uint amount,
        bool withdrawAll
    ) private {
        PositionInfo storage position = positions[positionIndex];
        bool shouldClose = PositionLib.withdraw(this, position, positionIndex, amount, withdrawAll);
        if (shouldClose) {
            closePosition(positionIndex, ClosePositionReason.WithdrawnByOwner);
        } else {
            emit PositionWasModified(positionIndex);
        }
    }

    function withdrawAll(uint positionIndex) external nonReentrant {
        withdrawImpl(
            positionIndex,
            0, /* amount */
            true /* withdrawAll */
        );

        PositionInfo storage position = positions[positionIndex];

        position.callerAddress.transferAll(position.stakedToken, position.owner);
        position.callerAddress.transferAll(position.rewardToken, position.owner);
    }

    function withdraw(uint positionIndex, uint amount) external nonReentrant {
        withdrawImpl(
            positionIndex,
            amount, /* amount */
            false /* withdrawAll */
        );

        PositionInfo storage position = positions[positionIndex];

        position.callerAddress.transferAll(position.stakedToken, position.owner);
        position.callerAddress.transferAll(position.rewardToken, position.owner);
    }

    function estimateLpPartsForPosition(uint positionIndex) external returns (uint, uint) {
        PositionInfo storage position = positions[positionIndex];

        withdrawImpl(
            positionIndex,
            0, /* amount */
            true /* withdrawAll */
        );

        return PositionLib.estimateLpPartsForPosition(this, position);
    }

    struct SlotInfo {
        uint withdrawnBalance;
        address lpToken;
        uint amount0;
        uint amount1;
        address token0;
        address token1;
        uint amountFirstSwapOut;
        uint amountSecondSwapOut;
    }

    function withdrawAllWithSwap(
        uint positionIndex,
        address withdrawalToken,
        bytes memory oneInchCallData
    ) external nonReentrant {
        PositionInfo storage position = positions[positionIndex];
        require(position.stakedToken == position.rewardToken, "withdraw all only for APY");
        withdrawImpl(
            positionIndex,
            0, /* amount */
            true /* withdrawAll */
        );

        uint withdrawnBalance = position.stakedToken.balanceOf(address(position.callerAddress));
        position.callerAddress.transferAll(position.stakedToken, address(this));

        uint amountOut = PositionLib.makeSwapOneInch(
            withdrawnBalance,
            address(position.stakedToken),
            oneInchRouter,
            PositionLib.StakeSwapOneInch(oneInchCallData)
        );

        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(withdrawalToken), msg.sender, amountOut);
    }

    // TODO: add slippage for swaps
    function withdrawAllWithSwapLp(
        uint positionIndex,
        address withdrawalToken,
        bytes memory oneInchCallDataToken0,
        bytes memory oneInchCallDataToken1
    ) external nonReentrant {
        SlotInfo memory slot;
        PositionInfo storage position = positions[positionIndex];
        require(position.stakedToken == position.rewardToken, "withdraw all only for APY");
        withdrawImpl(
            positionIndex,
            0, /* amount */
            true /* withdrawAll */
        );

        slot.withdrawnBalance = position.stakedToken.balanceOf(address(position.callerAddress));
        position.callerAddress.transferAll(position.stakedToken, address(this));

        // TODO: when fee of contract is non-zero, then ensure fees from LP-tokens are not burned here
        slot.lpToken = address(position.stakedToken);
        IERC20Upgradeable(slot.lpToken).transfer(address(slot.lpToken), slot.withdrawnBalance);

        (slot.amount0, slot.amount1) = IPairToken(slot.lpToken).burn(address(this));

        slot.token0 = IPairToken(slot.lpToken).token0();
        slot.token1 = IPairToken(slot.lpToken).token1();

        slot.amountFirstSwapOut = PositionLib.makeSwapOneInch(
            slot.amount0,
            slot.token0,
            oneInchRouter,
            PositionLib.StakeSwapOneInch(oneInchCallDataToken0)
        );

        slot.amountSecondSwapOut = PositionLib.makeSwapOneInch(
            slot.amount1,
            slot.token1,
            oneInchRouter,
            PositionLib.StakeSwapOneInch(oneInchCallDataToken1)
        );

        SafeERC20Upgradeable.safeTransfer(
            IERC20Upgradeable(withdrawalToken),
            msg.sender,
            slot.amountFirstSwapOut + slot.amountSecondSwapOut
        );
    }

    // Always emits `PositionWasClosed`
    function liquidateByIndexImpl(
        uint positionIndex,
        uint amountOutMin,
        bytes memory marketHints
    ) private {
        PositionInfo storage position = positions[positionIndex];
        require(isOpen(position), "isOpen");

        position.callerAddress.withdrawAll(
            getPoolAdapterSafe(position.poolAddress),
            position.poolAddress,
            abi.encode(position.stakedToken) // pass stakedToken for aave pools
        );

        uint stakedAmount = IERC20Upgradeable(position.stakedToken).balanceOf(address(position.callerAddress));

        position.callerAddress.approve(position.stakedToken, address(market), stakedAmount);
        position.callerAddress.swap(
            market, // adapter
            address(position.stakedToken), // tokenIn
            busdAddress, // tokenOut
            stakedAmount, // amountIn
            amountOutMin, // amountOutMin
            positions[positionIndex].owner, // to
            marketHints // hints
        );

        // Firstly, 'transfer', then 'dumpRewards': order is important here when (rewardToken == CAKE)
        position.callerAddress.transferAll(position.rewardToken, position.owner);

        closePosition(positionIndex, ClosePositionReason.LiquidatedByAutomation);
    }

    function closePosition(uint positionIndex, ClosePositionReason reason) private {
        PositionInfo storage position = positions[positionIndex];

        position.closed = true;

        if (isModernProxy(position.callerAddress)) {
            withdrawGasTank(position.callerAddress, position.owner);
            proxyPool.release(position.callerAddress);
        }

        _gelatoCancelTask(position.gelatoLiquidateTaskId);

        if (reason == ClosePositionReason.WithdrawnByOwner) {
            emitPositionWasClosed(positionIndex, position.stakedToken);
        }
        if (reason == ClosePositionReason.LiquidatedByAutomation) {
            emitPositionWasLiquidated(positionIndex, position.stakedToken);
        }
    }

    function depositGasTank(ProxyCaller proxy) private {
        address(proxy).call{value: msg.value}("");
    }

    function withdrawGasTank(ProxyCaller proxy, address owner) private {
        proxy.transferNativeAll(owner);
    }

    function isModernProxy(ProxyCaller proxy) public returns (bool) {
        return address(proxy).code.length == 945;
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Position events.

    function emitPositionWasCreated(uint positionIndex, IERC20Upgradeable positionStakedToken) private {
        // TODO(TmLev): Remove once `PositionWasCreatedV2` is stable.
        emit PositionWasCreated(positionIndex);

        (uint price, uint8 priceDecimals) = PositionLib.estimatePositionStakedTokenPrice(this, positionStakedToken);
        emit PositionWasCreatedV2(positionIndex, block.timestamp, price, priceDecimals);
    }

    function emitPositionWasClosed(uint positionIndex, IERC20Upgradeable positionStakedToken) private {
        // TODO(TmLev): Remove once `PositionWasClosedV2` is stable.
        emit PositionWasClosed(positionIndex);

        (uint price, uint8 priceDecimals) = PositionLib.estimatePositionStakedTokenPrice(this, positionStakedToken);
        emit PositionWasClosedV2(positionIndex, block.timestamp, price, priceDecimals);
    }

    function emitPositionWasLiquidated(uint positionIndex, IERC20Upgradeable positionStakedToken) private {
        // TODO(TmLev): Remove once `PositionWasLiquidatedV2` is stable.
        emit PositionWasClosed(positionIndex);

        (uint price, uint8 priceDecimals) = PositionLib.estimatePositionStakedTokenPrice(this, positionStakedToken);
        emit PositionWasLiquidatedV2(positionIndex, block.timestamp, price, priceDecimals);
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Gelato

    struct AutomationParams {
        uint256 positionIndex;
        uint256 minAmountOut;
        bytes marketHints;
    }

    function isOpen(PositionInfo storage position) private view returns (bool) {
        return !position.closed && position.owner != address(0);
    }

    function automationResolve(uint positionIndex) public returns (bool canExec, bytes memory execPayload) {
        PositionInfo storage position = positions[positionIndex];
        uint256 amountOut;
        bytes memory hints;
        (canExec, amountOut, hints) = PositionLib.isOutsideRange(this, position);
        if (canExec) {
            uint minAmountOut = amountOut - (amountOut * position.maxSlippage) / SLIPPAGE_MULTIPLIER;
            AutomationParams memory params = AutomationParams(positionIndex, minAmountOut, hints);
            execPayload = abi.encodeWithSelector(this.automationExec.selector, abi.encode(params));
        }
    }

    function automationExec(bytes calldata raw) public onlyAutomator {
        AutomationParams memory params = abi.decode(raw, (AutomationParams));
        gelatoPayFee(params.positionIndex);
        liquidateByIndexImpl(params.positionIndex, params.minAmountOut, params.marketHints);
    }

    function gelatoPayFee(uint positionIndex) private {
        (uint feeAmount, address feeToken) = gelatoOps.getFeeDetails();
        if (feeAmount == 0) {
            return;
        }

        require(feeToken == GelatoNativeToken);

        address feeDestination = gelatoOps.gelato();
        ProxyCaller proxy = positions[positionIndex].callerAddress;
        proxy.transferNative(feeDestination, feeAmount);
    }

    function _gelatoCreateTask(uint positionIndex) private returns (bytes32) {
        return
            gelatoOps.createTaskNoPrepayment(
                address(this), /* execAddress */
                this.automationExec.selector, /* execSelector */
                address(this), /* resolverAddress */
                abi.encodeWithSelector(this.automationResolve.selector, positionIndex), /* resolverData */
                GelatoNativeToken
            );
    }

    function _gelatoCancelTask(bytes32 gelatoTaskId) private {
        if (address(gelatoOps) != address(0) && gelatoTaskId != "") {
            gelatoOps.cancelTask(gelatoTaskId);
        }
    }
}
