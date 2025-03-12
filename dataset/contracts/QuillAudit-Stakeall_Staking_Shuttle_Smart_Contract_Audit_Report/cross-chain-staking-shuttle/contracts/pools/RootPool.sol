pragma solidity 0.8.7;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IRootPool.sol";
import "./PoolSecurityModule.sol";

contract RootPool is IRootPool, PoolSecurityModule {
    using SafeMath for uint256;

    IFxStateRootTunnel public rootTunnel;
    IWithdrawManagerProxy public withdrawManagerProxy;
    IERC20PredicateBurnOnly public erc20PredicateBurnOnly;
    IDepositManagerProxy public depositManagerProxy;
    address public erc20PredicateProxy;
    IPolidoAdapter public polidoAdapter;
    IERC20 public maticToken;
    address public childPoolFundCollector;

    /**
     * Initialize the contract and setup roles.
     *
     * @param _rootTunnel - Address of the child tunnel.
     * @param _withdrawManagerProxy - Address of MATIC token on Polygon Mainnet
     * @param _erc20PredicateBurnOnly - Address of stMatic on Polygon Mainnet
     * @param _depositManagerProxy Deposit Manager proxy address 
     * @param _erc20PredicateProxy - Address of the erc20 Predicate Proxy
     * @param _polidoAdapter - Address of the Polido Adapter
     * @param _maticToken - Address of the matic token 
     * @param _childPoolFundCollector - Address of childPool fund collector
     * @param _owner - Address of the owner
     */
    function initialize(
        IFxStateRootTunnel _rootTunnel,
        IWithdrawManagerProxy _withdrawManagerProxy,
        IERC20PredicateBurnOnly _erc20PredicateBurnOnly,
        IDepositManagerProxy _depositManagerProxy,
        address _erc20PredicateProxy,
        IPolidoAdapter _polidoAdapter,
        IERC20 _maticToken,
        address _childPoolFundCollector,
        address _owner
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        rootTunnel = _rootTunnel;
        withdrawManagerProxy = _withdrawManagerProxy;
        erc20PredicateBurnOnly = _erc20PredicateBurnOnly;
        depositManagerProxy = _depositManagerProxy;
        erc20PredicateProxy = _erc20PredicateProxy;
        polidoAdapter = _polidoAdapter;
        maticToken = _maticToken;
        childPoolFundCollector = _childPoolFundCollector;

        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(OPERATOR_ROLE, _owner);
        _setupRole(CANCEL_ROLE, _owner);
        _setupRole(PAUSE_ROLE, _owner);
        _setupRole(GOVERNANCE_ROLE, _owner);
    }

    /**
     *   @dev Withdrawing Tokens from polyogon chain to mainnet is two step process. Step 1 is startExitWithBurntTokens.
     *   Data argument is generate from matic.js with function `matic.exitUtil.buildPayloadForExit` by passing txhash and withdraw event signature.
     *
     * @param _shuttleNumber Shuttle Number on child pool for which processing is triggered on root pool.   
     * @param _burnTokenData Data generated from matic.js which is a proof that withdraw transaction happend on polygon chain. This data is only produced after 1 checkpoint.
     */
    function startExitWithBurntTokens(uint256 _shuttleNumber, bytes memory _burnTokenData)
        public
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
    {
        require(_burnTokenData.length > 0, "!data");
        erc20PredicateBurnOnly.startExitWithBurntTokens(_burnTokenData);

        emit ShuttleProcessingInitiated(_shuttleNumber);
    }

    /**
     * @dev This method performs cross chain staking.
     * It recieves message sent by child tunnel, claims burned token on polygon chain, stake token to PoLido and bridge them back to child pool.
     *
     * @param _messageReceiveData Data generated from matic.js which is a proof that Message is send by child tunnel to root tunnel from polygon chain. This data is only produced after 1 checkpoint.
     *
     */
    function crossChainStake(bytes memory _messageReceiveData)
        external
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
    {
        require(_messageReceiveData.length > 0, "!messageReceiveData");

        // recieve message send by child tunnel
        rootTunnel.receiveMessage(_messageReceiveData);

        // decode received message
        (uint256 shuttleNumber, uint256 amount) = rootTunnel.readData();

        uint256 beforeBalance = maticToken.balanceOf(address(this));

        // Step 2 for claiming tokens send from polygon to ethereum
        withdrawManagerProxy.processExits(address(maticToken));

        uint256 afterBalance = maticToken.balanceOf(address(this));
        uint256 effectiveBalance = afterBalance.sub(beforeBalance);

        require(effectiveBalance >= amount, "Insufficient amount to stake");

        maticToken.approve(address(polidoAdapter), amount);

        // stake matic and bridge stMatic
        uint256 stMaticAmount = polidoAdapter.depositForAndBridge(
            address(this),
            amount
        );
        rootTunnel.sendMessageToChild(
            abi.encode(
                shuttleNumber,
                stMaticAmount,
                ShuttleProcessingStatus.PROCESSED
            )
        );

        emit ShuttleProcessed(
            shuttleNumber,
            amount,
            stMaticAmount,
            ShuttleProcessingStatus.PROCESSED
        );
    }

    /**
     * @dev This method cancels the shuttle.
     * It recieves message sent by child tunnel, claims burned token on polygon chain, and bridge them back to child pool.
     *
     * @param _messageReceiveData Data generated from matic.js which is a proof that Message is send by child tunnel to root tunnel from polygon chain. This data is only produced after 1 checkpoint.
     *
     */
    function cancelShuttle(bytes memory _messageReceiveData)
        external
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
    {
        require(_messageReceiveData.length > 0, "!messageReceiveData");

        // recieve message send by child tunnel
        rootTunnel.receiveMessage(_messageReceiveData);

        // decode received message
        (uint256 shuttleNumber, uint256 amount) = rootTunnel.readData();

        uint256 beforeBalance = maticToken.balanceOf(address(this));

        // Step 2 for claiming tokens send from polygon to ethereum
        withdrawManagerProxy.processExits(address(maticToken));

        uint256 afterBalance = maticToken.balanceOf(address(this));
        uint256 effectiveBalance = afterBalance.sub(beforeBalance);

        require(effectiveBalance >= amount, "Insufficient amount recieved");

        maticToken.approve(address(depositManagerProxy), amount);

        depositManagerProxy.depositERC20ForUser(
            address(maticToken),
            childPoolFundCollector,
            amount
        );

        rootTunnel.sendMessageToChild(
            abi.encode(shuttleNumber, amount, ShuttleProcessingStatus.CANCELLED)
        );

          emit ShuttleProcessed(
            shuttleNumber,
            amount,
            0,
            ShuttleProcessingStatus.CANCELLED
        );

    }
}
