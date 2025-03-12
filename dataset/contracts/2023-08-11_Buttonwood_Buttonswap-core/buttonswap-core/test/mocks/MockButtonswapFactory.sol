// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {IButtonswapFactory} from "../../src/interfaces/IButtonswapFactory/IButtonswapFactory.sol";
import {IButtonswapPair} from "../../src/interfaces/IButtonswapPair/IButtonswapPair.sol";
import {MockButtonswapPair} from "./MockButtonswapPair.sol";

contract MockButtonswapFactory is IButtonswapFactory {
    address public feeTo;
    address public feeToSetter;
    bool public isCreationRestricted;
    address public isCreationRestrictedSetter;
    address public isPausedSetter;
    address public paramSetter;
    uint16 public defaultMaxVolatilityBps = 700;
    uint32 public defaultMinTimelockDuration = 24 seconds;
    uint32 public defaultMaxTimelockDuration = 24 hours;
    uint16 public defaultMaxSwappableReservoirLimitBps = 1000;
    uint32 public defaultSwappableReservoirGrowthWindow = 24 hours;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    address lastTokenA;
    address lastTokenB;

    // Simplified constructor for testing
    constructor(address _permissionSetter) {
        feeToSetter = _permissionSetter;
        isCreationRestrictedSetter = _permissionSetter;
        isPausedSetter = _permissionSetter;
        paramSetter = _permissionSetter;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // Don't sort tokenA and tokenB, this reduces the complexity of ButtonswapPair unit tests
        lastTokenA = tokenA;
        lastTokenB = tokenB;
        bytes memory bytecode = type(MockButtonswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(tokenA, tokenB));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // Resetting lastTokenA/lastTokenB to 0 to refund gas
        lastTokenA = address(0);
        lastTokenB = address(0);
    }

    function setFeeTo(address _feeTo) external {
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        feeToSetter = _feeToSetter;
    }

    function setIsCreationRestricted(bool _isCreationRestricted) external {
        isCreationRestricted = _isCreationRestricted;
    }

    function setIsCreationRestrictedSetter(address _isCreationRestrictedSetter) external {
        if (msg.sender != isCreationRestrictedSetter) {
            revert Forbidden();
        }
        isCreationRestrictedSetter = _isCreationRestrictedSetter;
    }

    function setIsPausedSetter(address _isPausedSetter) external {
        if (msg.sender != isPausedSetter) {
            revert Forbidden();
        }
        isPausedSetter = _isPausedSetter;
    }

    function setIsPaused(address[] calldata pairs, bool isPausedNew) external {
        if (msg.sender != isPausedSetter) {
            revert Forbidden();
        }
        for (uint256 i = 0; i < pairs.length; i++) {
            IButtonswapPair(pairs[i]).setIsPaused(isPausedNew);
        }
    }

    function setParamSetter(address _paramSetter) external {
        if (msg.sender != paramSetter) {
            revert Forbidden();
        }
        paramSetter = _paramSetter;
    }

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

    function setMaxVolatilityBps(address[] calldata pairs, uint16 newMaxVolatilityBps) external {
        if (msg.sender != paramSetter) {
            revert Forbidden();
        }
        for (uint256 i = 0; i < pairs.length; i++) {
            IButtonswapPair(pairs[i]).setMaxVolatilityBps(newMaxVolatilityBps);
        }
    }

    function setMinTimelockDuration(address[] calldata pairs, uint32 newMinTimelockDuration) external {
        if (msg.sender != paramSetter) {
            revert Forbidden();
        }
        for (uint256 i = 0; i < pairs.length; i++) {
            IButtonswapPair(pairs[i]).setMinTimelockDuration(newMinTimelockDuration);
        }
    }

    function setMaxTimelockDuration(address[] calldata pairs, uint32 newMaxTimelockDuration) external {
        if (msg.sender != paramSetter) {
            revert Forbidden();
        }
        for (uint256 i = 0; i < pairs.length; i++) {
            IButtonswapPair(pairs[i]).setMaxTimelockDuration(newMaxTimelockDuration);
        }
    }

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
        token0 = lastTokenA;
        token1 = lastTokenB;
        maxVolatilityBps = defaultMaxVolatilityBps;
        minTimelockDuration = defaultMinTimelockDuration;
        maxTimelockDuration = defaultMaxTimelockDuration;
        maxSwappableReservoirLimitBps = defaultMaxSwappableReservoirLimitBps;
        swappableReservoirGrowthWindow = defaultSwappableReservoirGrowthWindow;
    }
}
