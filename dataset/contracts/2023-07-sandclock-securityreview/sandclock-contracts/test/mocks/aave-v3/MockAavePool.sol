// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPool} from "aave-v3/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "aave-v3/interfaces/IPoolAddressesProvider.sol";
import {DataTypes} from "aave-v3/protocol/libraries/types/DataTypes.sol";

import {Constants as C} from "../../../src/lib/Constants.sol";
import {MockChainlinkPriceFeed} from "../chainlink/MockChainlinkPriceFeed.sol";
import {MockWETH} from "../MockWETH.sol";

contract MockAavePool is IPool {
    using FixedPointMathLib for uint256;

    struct AssetData {
        uint256 supplyAmount;
        uint256 borrowAmount;
    }

    ERC20 usdc;
    MockWETH weth;
    MockChainlinkPriceFeed usdcToEthPriceFeed;

    ERC20 wstEth;
    MockChainlinkPriceFeed stEthToEthPriceFeed;

    mapping(address => mapping(address => AssetData)) public book;

    function supply(address asset, uint256 amount, address, uint16) external override {
        book[msg.sender][asset].supplyAmount += amount;
        ERC20(asset).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(address asset, uint256 amount, address to) external override returns (uint256) {
        uint256 balance = book[msg.sender][asset].supplyAmount;
        require(balance > amount, "MockAavePool: AMOUNT_TOO_HIGH");
        require(ERC20(asset).balanceOf(address(this)) >= amount, "MockAavePool: INSUFFICIENT_BALANCE_IN_POOL");

        ERC20(asset).transfer(to, amount);
        book[msg.sender][asset].supplyAmount -= amount;

        return amount;
    }

    function borrow(address asset, uint256 amount, uint256, uint16, address) external override {
        require(ERC20(asset).balanceOf(address(this)) >= amount, "MockAavePool: INSUFFICIENT_BALANCE_IN_POOL");

        book[msg.sender][asset].borrowAmount += amount;
        ERC20(asset).transfer(msg.sender, amount);
    }

    function repay(address asset, uint256 amount, uint256, address) external override returns (uint256) {
        uint256 balance = book[msg.sender][asset].borrowAmount;
        require(balance >= amount, "MockAavePool: AMOUNT_TOO_HIGH");
        require(ERC20(asset).balanceOf(address(this)) >= amount, "MockAavePool: INSUFFICIENT_BALANCE_IN_POOL");

        book[msg.sender][asset].borrowAmount -= amount;
        ERC20(asset).transferFrom(msg.sender, address(this), amount);

        return amount;
    }

    function addInterestOnSupply(address user, address asset, uint256 amount) external {
        require(book[user][asset].supplyAmount != 0, "MockAavePool: USER_SUPPLY_ZERO");

        book[user][asset].supplyAmount += amount;
        ERC20(asset).transferFrom(msg.sender, address(this), amount);
    }

    function addInterestOnDebt(address user, address asset, uint256 amount) external {
        require(book[user][asset].borrowAmount != 0, "MockAavePool: USER_DEBT_ZERO");

        book[user][asset].borrowAmount += amount;
    }

    function getEModeCategoryData(uint8) external pure override returns (DataTypes.EModeCategory memory) {
        return DataTypes.EModeCategory(9000, 0, 0, address(0), "");
    }

    function setUsdcWethPriceFeed(MockChainlinkPriceFeed _usdcToEthPriceFeed, ERC20 _usdc, MockWETH _weth) external {
        usdcToEthPriceFeed = _usdcToEthPriceFeed;
        usdc = _usdc;
        weth = _weth;
    }

    function setStEthToEthPriceFeed(MockChainlinkPriceFeed _stEthToEthPriceFeed, ERC20 _wstEth, MockWETH _weth)
        external
    {
        stEthToEthPriceFeed = _stEthToEthPriceFeed;
        wstEth = _wstEth;
        weth = _weth;
    }

    function getUserAccountData(address user)
        external
        view
        override
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        // to ignore unused variables compiler warning
        availableBorrowsBase = 0;
        currentLiquidationThreshold = 0;
        ltv = 0;
        healthFactor = 0;

        if (book[user][address(usdc)].supplyAmount > 0) {
            totalCollateralBase = book[user][address(usdc)].supplyAmount;

            uint256 borrowedWeth = book[user][address(weth)].borrowAmount;
            (, int256 usdcPriceInWeth,,,) = usdcToEthPriceFeed.latestRoundData();
            totalDebtBase = (borrowedWeth / C.WETH_USDC_DECIMALS_DIFF).divWadDown(uint256(usdcPriceInWeth));
        } else {
            totalCollateralBase = book[user][address(wstEth)].supplyAmount;

            uint256 borrowedWeth = book[user][address(weth)].borrowAmount;
            (, int256 wstEthPriceInWeth,,,) = stEthToEthPriceFeed.latestRoundData();
            totalDebtBase = borrowedWeth.divWadDown(uint256(wstEthPriceInWeth));
        }
    }

    /*//////////////////////////////////////////////////////////////
                            UNUSED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function rebalanceStableBorrowRate(address asset, address user) external override {}

    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external override {}

    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external override {}

    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external override {}

    function mintUnbacked(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external override {}

    function backUnbacked(address asset, uint256 amount, uint256 fee) external override returns (uint256) {}

    function supplyWithPermit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external override {}

    function repayWithPermit(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external override returns (uint256) {}

    function repayWithATokens(address asset, uint256 amount, uint256 interestRateMode)
        external
        override
        returns (uint256)
    {}

    function swapBorrowRateMode(address asset, uint256 interestRateMode) external override {}

    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external override {}

    function initReserve(
        address asset,
        address aTokenAddress,
        address stableDebtAddress,
        address variableDebtAddress,
        address interestRateStrategyAddress
    ) external override {}

    function dropReserve(address asset) external override {}

    function setReserveInterestRateStrategyAddress(address asset, address rateStrategyAddress) external override {}

    function setConfiguration(address asset, DataTypes.ReserveConfigurationMap calldata configuration)
        external
        override
    {}

    function getConfiguration(address asset)
        external
        view
        override
        returns (DataTypes.ReserveConfigurationMap memory)
    {}

    function getUserConfiguration(address user)
        external
        view
        override
        returns (DataTypes.UserConfigurationMap memory)
    {}

    function getReserveNormalizedIncome(address asset) external view override returns (uint256) {}

    function getReserveNormalizedVariableDebt(address asset) external view override returns (uint256) {}

    function getReserveData(address asset) external view override returns (DataTypes.ReserveData memory) {}

    function finalizeTransfer(
        address asset,
        address from,
        address to,
        uint256 amount,
        uint256 balanceFromBefore,
        uint256 balanceToBefore
    ) external override {}

    function getReservesList() external view override returns (address[] memory) {}

    function getReserveAddressById(uint16 id) external view override returns (address) {}

    function ADDRESSES_PROVIDER() external view override returns (IPoolAddressesProvider) {}

    function updateBridgeProtocolFee(uint256 bridgeProtocolFee) external override {}

    function updateFlashloanPremiums(uint128 flashLoanPremiumTotal, uint128 flashLoanPremiumToProtocol)
        external
        override
    {}

    function configureEModeCategory(uint8 id, DataTypes.EModeCategory memory config) external override {}

    function setUserEMode(uint8 categoryId) external override {}

    function getUserEMode(address user) external view override returns (uint256) {}

    function resetIsolationModeTotalDebt(address asset) external override {}

    function MAX_STABLE_RATE_BORROW_SIZE_PERCENT() external view override returns (uint256) {}

    function FLASHLOAN_PREMIUM_TOTAL() external view override returns (uint128) {}

    function BRIDGE_PROTOCOL_FEE() external view override returns (uint256) {}

    function FLASHLOAN_PREMIUM_TO_PROTOCOL() external view override returns (uint128) {}

    function MAX_NUMBER_RESERVES() external view override returns (uint16) {}

    function mintToTreasury(address[] calldata assets) external override {}

    function rescueTokens(address token, address to, uint256 amount) external override {}

    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external override {}
}
