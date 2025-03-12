// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPoolAdapter.sol";

struct ReserveConfigurationMap {
    uint256 data;
}

struct ReserveData {
    // stores the reserve configuration
    ReserveConfigurationMap configuration;
    // the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    // the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    // variable borrow index. Expressed in ray
    uint128 variableBorrowIndex;
    // the current variable borrow rate. Expressed in ray
    uint128 currentVariableBorrowRate;
    // the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    // timestamp of last update
    uint40 lastUpdateTimestamp;
    // the id of the reserve. Represents the position in the list of the active reserves
    uint16 id;
    // aToken address
    address aTokenAddress;
    // stableDebtToken address
    address stableDebtTokenAddress;
    // variableDebtToken address
    address variableDebtTokenAddress;
    // address of the interest rate strategy
    address interestRateStrategyAddress;
    // the current treasury balance, scaled
    uint128 accruedToTreasury;
    // the outstanding unbacked aTokens minted through the bridging feature
    uint128 unbacked;
    // the outstanding debt borrowed against this asset in isolation mode
    uint128 isolationModeTotalDebt;
}

interface IAavePoolAddressesProvider {
    function getPool() external view returns (address);
}

interface IAavePoolV3 {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    function getReservesList() external view returns (address[] memory);

    function getReserveData(address asset) external view returns (ReserveData memory);
}

contract AavePoolAdapter is IPoolAdapter {
    address private immutable poolAddress;

    constructor(address poolAddressesProvider) {
        poolAddress = IAavePoolAddressesProvider(poolAddressesProvider).getPool();
    }

    function stakingBalance(address, bytes memory args) external returns (uint256) {
        // args should contain staked token address
        address asset = abi.decode(args, (address));
        ReserveData memory data = IAavePoolV3(poolAddress).getReserveData(asset);
        return IERC20(data.aTokenAddress).balanceOf(address(this));
    }

    function rewardBalance(address, bytes memory) external returns (uint256) {
        return 0;
    }

    function deposit(
        address,
        uint256 amount,
        bytes memory args
    ) external {
        address asset = abi.decode(args, (address));
        IAavePoolV3(poolAddress).supply(
            asset, // asset
            amount, // amount
            address(this), // onBehalfOf
            uint16(0) // referralCode
        );
    }

    function withdraw(
        address,
        uint256 amount,
        bytes memory args
    ) external {
        address asset = abi.decode(args, (address));
        IAavePoolV3(poolAddress).withdraw(
            asset, // asset
            amount, // amount
            address(this) // to
        );
    }

    function withdrawAll(address, bytes memory args) external {
        address asset = abi.decode(args, (address));
        // Pass type(uint256).max for withdrawing all
        IAavePoolV3(poolAddress).withdraw(
            asset, // asset
            type(uint256).max, // amount
            address(this) // to
        );
    }

    function stakedToken(address, bytes memory args) external returns (address) {
        // args should contain staked token address
        address givenToken = abi.decode(args, (address));
        address[] memory aaveTokens = IAavePoolV3(poolAddress).getReservesList();
        for (uint i = 0; i < aaveTokens.length; i++) {
            if (aaveTokens[i] == givenToken) {
                return givenToken;
            }
        }

        return address(0);
    }

    function rewardToken(address, bytes memory args) external returns (address) {
        // args should contain reward token address
        // For all Aave pools stakedToken = rewardToken
        return abi.decode(args, (address));
    }
}
