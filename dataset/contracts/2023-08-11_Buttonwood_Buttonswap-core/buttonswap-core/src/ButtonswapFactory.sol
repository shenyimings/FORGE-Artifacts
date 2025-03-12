// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {IButtonswapFactory} from "./interfaces/IButtonswapFactory/IButtonswapFactory.sol";
import {IButtonswapPair} from "./interfaces/IButtonswapPair/IButtonswapPair.sol";
import {ButtonswapPair} from "./ButtonswapPair.sol";

contract ButtonswapFactory is IButtonswapFactory {
    /**
     * @inheritdoc IButtonswapFactory
     */
    address public feeTo;

    /**
     * @inheritdoc IButtonswapFactory
     */
    address public feeToSetter;

    /**
     * @inheritdoc IButtonswapFactory
     */
    mapping(address => mapping(address => address)) public getPair;

    /**
     * @inheritdoc IButtonswapFactory
     */
    address[] public allPairs;

    address internal lastToken0;

    address internal lastToken1;

    /**
     * @inheritdoc IButtonswapFactory
     */
    address public paramSetter;

    /**
     * @inheritdoc IButtonswapFactory
     */
    uint16 public defaultMaxVolatilityBps = 700;

    /**
     * @inheritdoc IButtonswapFactory
     */
    uint32 public defaultMinTimelockDuration = 24 seconds;

    /**
     * @inheritdoc IButtonswapFactory
     */
    uint32 public defaultMaxTimelockDuration = 24 hours;

    /**
     * @inheritdoc IButtonswapFactory
     */
    uint16 public defaultMaxSwappableReservoirLimitBps = 1000;

    /**
     * @inheritdoc IButtonswapFactory
     */
    uint32 public defaultSwappableReservoirGrowthWindow = 24 hours;

    /**
     * @inheritdoc IButtonswapFactory
     */
    bool public isCreationRestricted;

    /**
     * @inheritdoc IButtonswapFactory
     */
    address public isCreationRestrictedSetter;

    /**
     * @inheritdoc IButtonswapFactory
     */
    address public isPausedSetter;

    /**
     * @dev `feeTo` is not initialised during deployment, and must be set separately by a call to {setFeeTo}.
     * @param _feeToSetter The account that has the ability to set `feeToSetter` and `feeTo`
     * @param _isCreationRestrictedSetter The account that has the ability to set `isCreationRestrictedSetter` and `isCreationRestricted`
     * @param _isPausedSetter The account that has the ability to set `isPausedSetter` and `isPaused`
     * @param _paramSetter The account that has the ability to set `paramSetter`, default parameters, and current parameters on existing pairs
     */
    constructor(
        address _feeToSetter,
        address _isCreationRestrictedSetter,
        address _isPausedSetter,
        address _paramSetter
    ) {
        feeToSetter = _feeToSetter;
        isCreationRestrictedSetter = _isCreationRestrictedSetter;
        isPausedSetter = _isPausedSetter;
        paramSetter = _paramSetter;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function allPairsLength() external view returns (uint256 count) {
        count = allPairs.length;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        if (isCreationRestricted && msg.sender != isCreationRestrictedSetter) {
            revert Forbidden();
        }
        if (tokenA == tokenB) {
            revert TokenIdenticalAddress();
        }
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) {
            revert TokenZeroAddress();
        }
        // single check is sufficient
        if (getPair[token0][token1] != address(0)) {
            revert PairExists();
        }
        lastToken0 = token0;
        lastToken1 = token1;
        bytes memory bytecode = type(ButtonswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // Resetting lastToken0/lastToken1 to 0 to refund gas
        lastToken0 = address(0);
        lastToken1 = address(0);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setFeeTo(address _feeTo) external {
        if (msg.sender != feeToSetter) {
            revert Forbidden();
        }
        feeTo = _feeTo;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setFeeToSetter(address _feeToSetter) external {
        if (msg.sender != feeToSetter) {
            revert Forbidden();
        }
        feeToSetter = _feeToSetter;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setIsCreationRestricted(bool _isCreationRestricted) external {
        if (msg.sender != isCreationRestrictedSetter) {
            revert Forbidden();
        }
        isCreationRestricted = _isCreationRestricted;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setIsCreationRestrictedSetter(address _isCreationRestrictedSetter) external {
        if (msg.sender != isCreationRestrictedSetter) {
            revert Forbidden();
        }
        isCreationRestrictedSetter = _isCreationRestrictedSetter;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setIsPaused(address[] calldata pairs, bool isPausedNew) external {
        if (msg.sender != isPausedSetter) {
            revert Forbidden();
        }
        for (uint256 i = 0; i < pairs.length; i++) {
            IButtonswapPair(pairs[i]).setIsPaused(isPausedNew);
        }
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setIsPausedSetter(address _isPausedSetter) external {
        if (msg.sender != isPausedSetter) {
            revert Forbidden();
        }
        isPausedSetter = _isPausedSetter;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setParamSetter(address _paramSetter) external {
        if (msg.sender != paramSetter) {
            revert Forbidden();
        }
        paramSetter = _paramSetter;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setDefaultParameters(
        uint16 _defaultMaxVolatilityBps,
        uint32 _defaultMinTimelockDuration,
        uint32 _defaultMaxTimelockDuration,
        uint16 _defaultMaxSwappableReservoirLimitBps,
        uint32 _defaultSwappableReservoirGrowthWindow
    ) external {
        if (msg.sender != paramSetter) {
            revert Forbidden();
        }
        defaultMaxVolatilityBps = _defaultMaxVolatilityBps;
        defaultMinTimelockDuration = _defaultMinTimelockDuration;
        defaultMaxTimelockDuration = _defaultMaxTimelockDuration;
        defaultMaxSwappableReservoirLimitBps = _defaultMaxSwappableReservoirLimitBps;
        defaultSwappableReservoirGrowthWindow = _defaultSwappableReservoirGrowthWindow;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setMaxVolatilityBps(address[] calldata pairs, uint16 newMaxVolatilityBps) external {
        if (msg.sender != paramSetter) {
            revert Forbidden();
        }
        for (uint256 i = 0; i < pairs.length; i++) {
            IButtonswapPair(pairs[i]).setMaxVolatilityBps(newMaxVolatilityBps);
        }
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setMinTimelockDuration(address[] calldata pairs, uint32 newMinTimelockDuration) external {
        if (msg.sender != paramSetter) {
            revert Forbidden();
        }
        for (uint256 i = 0; i < pairs.length; i++) {
            IButtonswapPair(pairs[i]).setMinTimelockDuration(newMinTimelockDuration);
        }
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setMaxTimelockDuration(address[] calldata pairs, uint32 newMaxTimelockDuration) external {
        if (msg.sender != paramSetter) {
            revert Forbidden();
        }
        for (uint256 i = 0; i < pairs.length; i++) {
            IButtonswapPair(pairs[i]).setMaxTimelockDuration(newMaxTimelockDuration);
        }
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setMaxSwappableReservoirLimitBps(address[] calldata pairs, uint16 newMaxSwappableReservoirLimitBps)
        external
    {
        if (msg.sender != paramSetter) {
            revert Forbidden();
        }
        for (uint256 i = 0; i < pairs.length; i++) {
            IButtonswapPair(pairs[i]).setMaxSwappableReservoirLimitBps(newMaxSwappableReservoirLimitBps);
        }
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setSwappableReservoirGrowthWindow(address[] calldata pairs, uint32 newSwappableReservoirGrowthWindow)
        external
    {
        if (msg.sender != paramSetter) {
            revert Forbidden();
        }
        for (uint256 i = 0; i < pairs.length; i++) {
            IButtonswapPair(pairs[i]).setSwappableReservoirGrowthWindow(newSwappableReservoirGrowthWindow);
        }
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function lastCreatedTokensAndParameters()
        external
        view
        returns (
            address token0,
            address token1,
            uint16 maxVolatilityBps,
            uint32 minTimelockDuration,
            uint32 maxTimelockDuration,
            uint16 maxSwappableReservoirLimitBps,
            uint32 swappableReservoirGrowthWindow
        )
    {
        token0 = lastToken0;
        token1 = lastToken1;
        maxVolatilityBps = defaultMaxVolatilityBps;
        minTimelockDuration = defaultMinTimelockDuration;
        maxTimelockDuration = defaultMaxTimelockDuration;
        maxSwappableReservoirLimitBps = defaultMaxSwappableReservoirLimitBps;
        swappableReservoirGrowthWindow = defaultSwappableReservoirGrowthWindow;
    }
}
