//SPDX-License-Identifier: CC-BY-NC-ND-4.0
pragma solidity 0.8.7;

import "../interfaces/IPoolFactory.sol";
import "../interfaces/ILeveragedPool.sol";
import "../interfaces/IPoolCommitter.sol";
import "../interfaces/IERC20DecimalsWrapper.sol";
import "../interfaces/IAutoClaim.sol";
import "../interfaces/ITwoStepGovernance.sol";
import "./LeveragedPool.sol";
import "./PoolToken.sol";
import "./PoolKeeper.sol";
import "./PoolCommitter.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title The pool factory contract
contract PoolFactory is IPoolFactory, ITwoStepGovernance {
    // #### Globals
    address public immutable pairTokenBaseAddress;
    address public immutable poolBaseAddress;
    IPoolKeeper public poolKeeper;
    address public immutable poolCommitterBaseAddress;

    address public autoClaim;
    address public invariantCheck;

    // Contract address which has governance permissions
    address public override governance;
    bool public override governanceTransferInProgress;
    address public override provisionalGovernance;
    // Contract address to receive protocol fees
    address public feeReceiver;
    // Default fee, annualised; Fee value as a decimal multiplied by 10^18. For example, 50% is represented as 0.5 * 10^18
    uint256 public fee;
    // Percent of fees that go to secondary fee address if applicable.
    uint256 public secondaryFeeSplitPercent = 10;

    // This is required because we must pass along *some* value for decimal
    // precision to the base pool tokens as we use the Cloneable pattern
    uint8 constant DEFAULT_NUM_DECIMALS = 18;
    uint8 constant MAX_DECIMALS = DEFAULT_NUM_DECIMALS;
    // Considering leap year thus using 365.2425 days per year
    uint32 constant DAYS_PER_LEAP_YEAR = 365.2425 days;
    // Default max leverage of 10
    uint16 public maxLeverage = 10;

    /**
     * @notice Format: Pool counter => pool address
     */
    mapping(uint256 => address) public override pools;
    uint256 public override numPools;

    /**
     * @notice Format: Pool address => validity
     */
    mapping(address => bool) public override isValidPool;

    /**
     * @notice Format: PoolCommitter address => validity
     */
    mapping(address => bool) public override isValidPoolCommitter;

    // #### Modifiers
    modifier onlyGov() {
        require(msg.sender == governance, "msg.sender not governance");
        _;
    }

    // #### Functions
    constructor(address _feeReceiver, address _governance) {
        require(_feeReceiver != address(0), "Address cannot be null");
        require(_governance != address(0), "Address cannot be null");
        governance = _governance;

        // Deploy base contracts
        PoolToken pairTokenBase = new PoolToken(DEFAULT_NUM_DECIMALS);
        pairTokenBaseAddress = address(pairTokenBase);
        LeveragedPool poolBase = new LeveragedPool();
        poolBaseAddress = address(poolBase);
        PoolCommitter poolCommitterBase = new PoolCommitter();
        poolCommitterBaseAddress = address(poolCommitterBase);

        feeReceiver = _feeReceiver;

        /* initialise base PoolCommitter template (with dummy values) */
        poolCommitterBase.initialize(address(this), address(this), address(this), governance, governance, 0, 0, 0);
    }

    /**
     * @notice Deploy a leveraged pool and its committer/pool tokens with given parameters
     * @notice Rebasing tokens are not supported and will break functionality
     * @param deploymentParameters Deployment parameters of the market. Some may be reconfigurable.
     * @return Address of the created pool
     * @dev Throws if pool keeper is null
     * @dev Throws if deployer does not own the oracle wrapper
     * @dev Throws if leverage amount is invalid
     * @dev Throws if decimal precision is too high (i.e., greater than `MAX_DECIMALS`)
     */
    function deployPool(PoolDeployment calldata deploymentParameters) external override returns (address) {
        address _poolKeeper = address(poolKeeper);
        require(_poolKeeper != address(0), "PoolKeeper not set");
        require(autoClaim != address(0), "AutoClaim not set");
        require(invariantCheck != address(0), "InvariantCheck not set");
        require(
            IOracleWrapper(deploymentParameters.oracleWrapper).deployer() == msg.sender,
            "Deployer must be oracle wrapper owner"
        );
        require(
            deploymentParameters.leverageAmount >= 1 && deploymentParameters.leverageAmount <= maxLeverage,
            "PoolKeeper: leveraged amount invalid"
        );
        require(
            IERC20DecimalsWrapper(deploymentParameters.quoteToken).decimals() <= MAX_DECIMALS,
            "Decimal precision too high"
        );

        bytes32 uniquePoolHash = keccak256(
            abi.encode(
                deploymentParameters.frontRunningInterval,
                deploymentParameters.updateInterval,
                deploymentParameters.leverageAmount,
                deploymentParameters.quoteToken,
                deploymentParameters.oracleWrapper
            )
        );

        PoolCommitter poolCommitter = PoolCommitter(
            Clones.cloneDeterministic(poolCommitterBaseAddress, uniquePoolHash)
        );

        address poolCommitterAddress = address(poolCommitter);
        poolCommitter.initialize(
            address(this),
            invariantCheck,
            autoClaim,
            governance,
            deploymentParameters.feeController,
            deploymentParameters.mintingFee,
            deploymentParameters.burningFee,
            deploymentParameters.changeInterval
        );

        require(
            deploymentParameters.leverageAmount >= 1 && deploymentParameters.leverageAmount <= maxLeverage,
            "PoolKeeper: leveraged amount invalid"
        );
        require(
            IERC20DecimalsWrapper(deploymentParameters.quoteToken).decimals() <= MAX_DECIMALS,
            "Decimal precision too high"
        );

        LeveragedPool pool = LeveragedPool(Clones.cloneDeterministic(poolBaseAddress, uniquePoolHash));
        address _pool = address(pool);
        emit DeployPool(_pool, address(poolCommitter), deploymentParameters.poolName);

        string memory leverage = Strings.toString(deploymentParameters.leverageAmount);

        ILeveragedPool.Initialization memory initialization = ILeveragedPool.Initialization({
            _owner: governance, // governance is the owner of pools -- if this changes, `onlyGov` breaks
            _keeper: _poolKeeper,
            _oracleWrapper: deploymentParameters.oracleWrapper,
            _settlementEthOracle: deploymentParameters.settlementEthOracle,
            _longToken: deployPairToken(_pool, leverage, deploymentParameters, "L-"),
            _shortToken: deployPairToken(_pool, leverage, deploymentParameters, "S-"),
            _poolCommitter: poolCommitterAddress,
            _invariantCheckContract: invariantCheck,
            _poolName: string(abi.encodePacked(leverage, "-", deploymentParameters.poolName)),
            _frontRunningInterval: deploymentParameters.frontRunningInterval,
            _updateInterval: deploymentParameters.updateInterval,
            _fee: (fee * deploymentParameters.updateInterval) / (DAYS_PER_LEAP_YEAR),
            _leverageAmount: deploymentParameters.leverageAmount,
            _feeAddress: feeReceiver,
            _secondaryFeeAddress: msg.sender,
            _quoteToken: deploymentParameters.quoteToken,
            _secondaryFeeSplitPercent: secondaryFeeSplitPercent
        });

        // approve the quote token on the pool committer to finalise linking
        // this also stores the pool address in the committer
        // finalise pool setup
        pool.initialize(initialization);
        IPoolCommitter(poolCommitterAddress).setQuoteAndPool(deploymentParameters.quoteToken, _pool);
        poolKeeper.newPool(_pool);
        pools[numPools] = _pool;
        // numPools overflowing would require an unrealistic number of markets
        unchecked {
            numPools++;
        }
        isValidPool[_pool] = true;
        isValidPoolCommitter[address(poolCommitter)] = true;
        return _pool;
    }

    /**
     * @notice Deploy a contract for pool tokens
     * @param poolOwner Address of the owner of the pool
     * @param leverage Amount of leverage for pool
     * @param deploymentParameters Deployment parameters for parent function
     * @param direction Long or short token, L- or S-
     * @return Address of the pool token
     */
    function deployPairToken(
        address poolOwner,
        string memory leverage,
        PoolDeployment memory deploymentParameters,
        string memory direction
    ) internal returns (address) {
        string memory poolNameAndSymbol = string(abi.encodePacked(leverage, direction, deploymentParameters.poolName));
        uint8 settlementDecimals = IERC20DecimalsWrapper(deploymentParameters.quoteToken).decimals();
        bytes32 uniqueTokenHash = keccak256(
            abi.encode(
                deploymentParameters.leverageAmount,
                deploymentParameters.quoteToken,
                deploymentParameters.oracleWrapper,
                direction
            )
        );

        PoolToken pairToken = PoolToken(Clones.cloneDeterministic(pairTokenBaseAddress, uniqueTokenHash));
        pairToken.initialize(poolOwner, poolNameAndSymbol, poolNameAndSymbol, settlementDecimals);
        return address(pairToken);
    }

    /**
     * @notice Sets the address of the associated `PoolKeeper` contract
     * @param _poolKeeper Address of the `PoolKeeper`
     * @dev Throws if provided address is null
     * @dev Only callable by the owner
     * @dev Emits a `PoolKeeperChanged` event on success
     */
    function setPoolKeeper(address _poolKeeper) external override onlyGov {
        require(_poolKeeper != address(0), "address cannot be null");
        poolKeeper = IPoolKeeper(_poolKeeper);
        emit PoolKeeperChanged(_poolKeeper);
    }

    /**
     * @notice Sets the address of the associated `InvariantCheck` contract
     * @param _invariantCheck Address of the `InvariantCheck`
     * @dev Throws if provided address is null
     * @dev Only callable by the owner
     */
    function setInvariantCheck(address _invariantCheck) external override onlyGov {
        require(_invariantCheck != address(0), "address cannot be null");
        invariantCheck = _invariantCheck;
        emit InvariantCheckChanged(_invariantCheck);
    }

    /**
     * @notice Sets the address of the associated `AutoClaim` contract
     * @param _autoClaim Address of the `AutoClaim`
     * @dev Throws if provided address is null
     * @dev Only callable by the owner
     */
    function setAutoClaim(address _autoClaim) external override onlyGov {
        require(_autoClaim != address(0), "address cannot be null");
        autoClaim = _autoClaim;
        emit AutoClaimChanged(_autoClaim);
    }

    /**
     * @notice Sets the maximum leverage
     * @param newMaxLeverage Maximum leverage permitted for all pools
     * @dev Throws if provided maximum leverage is non-positive
     * @dev Only callable by the owner
     * @dev Emits a `MaxLeverageChanged` event on success
     */
    function setMaxLeverage(uint16 newMaxLeverage) external override onlyGov {
        require(newMaxLeverage > 0, "Maximum leverage must be non-zero");
        maxLeverage = newMaxLeverage;
        emit MaxLeverageChanged(newMaxLeverage);
    }

    /**
     * @notice Sets the primary fee receiver of deployed Leveraged pools.
     * @param _feeReceiver address of fee receiver
     * @dev Only callable by the owner of this contract
     * @dev This fuction does not change anything for already deployed pools, only pools deployed after the change
     * @dev Emits a `FeeReceiverChanged` event on success
     */
    function setFeeReceiver(address _feeReceiver) external override onlyGov {
        require(_feeReceiver != address(0), "address cannot be null");
        feeReceiver = _feeReceiver;
        emit FeeReceiverChanged(_feeReceiver);
    }

    /**
     * @notice Sets the proportion of fees to be split to the nominated secondary fees recipient
     * @param newFeePercent Proportion of fees to split
     * @dev Only callable by the owner of this contract
     * @dev Throws if `newFeePercent` exceeds 100
     * @dev Emits a `SecondaryFeeSplitChanged` event on success
     */
    function setSecondaryFeeSplitPercent(uint256 newFeePercent) external override onlyGov {
        require(newFeePercent <= 100, "Secondary fee split cannot exceed 100%");
        secondaryFeeSplitPercent = newFeePercent;
        emit SecondaryFeeSplitChanged(newFeePercent);
    }

    /**
     * @notice Set the yearly fee amount. The max yearly fee is 10%
     * @dev This is a percentage in WAD; multiplied by 10^18 e.g. 5% is 0.05 * 10^18
     * @param _fee The fee amount as a percentage
     * @dev Throws if fee is greater than 10%
     * @dev Emits a `FeeChanged` event on success
     */
    function setFee(uint256 _fee) external override onlyGov {
        require(_fee <= 0.1e18, "Fee cannot be > 10%");
        fee = _fee;
        emit FeeChanged(_fee);
    }

    /**
     * @notice Starts to transfer governance of the pool. The new governance
     *          address must call `claimGovernance` in order for this to take
     *          effect. Until this occurs, the existing governance address
     *          remains in control of the pool.
     * @param _governance New address of the governance of the pool
     * @dev First step of the two-step governance transfer process
     * @dev Sets the governance transfer flag to true
     * @dev See `claimGovernance`
     */
    function transferGovernance(address _governance) external override onlyGov {
        require(_governance != governance, "New governance address cannot be same as old governance address");
        require(_governance != address(0), "Governance address cannot be 0 address");
        provisionalGovernance = _governance;
        governanceTransferInProgress = true;
        emit ProvisionalGovernanceChanged(_governance);
    }

    /**
     * @notice Completes transfer of governance by actually changing permissions
     *          over the pool.
     * @dev Second and final step of the two-step governance transfer process
     * @dev See `transferGovernance`
     * @dev Sets the governance transfer flag to false
     * @dev After a successful call to this function, the actual governance
     *      address and the provisional governance address MUST be equal.
     */
    function claimGovernance() external override {
        require(governanceTransferInProgress, "No governance change active");
        address _provisionalGovernance = provisionalGovernance;
        require(msg.sender == _provisionalGovernance, "Not provisional governor");
        address oldGovernance = governance; /* for later event emission */
        governance = _provisionalGovernance;
        governanceTransferInProgress = false;
        emit GovernanceAddressChanged(oldGovernance, _provisionalGovernance);
    }
}
