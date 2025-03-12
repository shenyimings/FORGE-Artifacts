// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {Address} from '../dependencies/openzeppelin/contracts/Address.sol';
import {IERC20Detailed} from '../dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {IMarketAccessController} from '../access/interfaces/IMarketAccessController.sol';
import {AccessFlags} from '../access/AccessFlags.sol';
import {ILendingPool} from '../interfaces/ILendingPool.sol';
import {IStableDebtToken} from '../interfaces/IStableDebtToken.sol';
import {IVariableDebtToken} from '../interfaces/IVariableDebtToken.sol';
import {ReserveConfiguration} from '../protocol/libraries/configuration/ReserveConfiguration.sol';
import {UserConfiguration} from '../protocol/libraries/configuration/UserConfiguration.sol';
import {DataTypes} from '../protocol/libraries/types/DataTypes.sol';
import {IReserveInterestRateStrategy} from '../interfaces/IReserveInterestRateStrategy.sol';
import {IPoolAddressProvider} from '../interfaces/IPoolAddressProvider.sol';
import {IUiPoolDataProvider} from './interfaces/IUiPoolDataProvider.sol';
import {IPriceOracleGetter} from '../interfaces/IPriceOracleGetter.sol';
import {IDepositToken} from '../interfaces/IDepositToken.sol';
import {IDerivedToken} from '../interfaces/IDerivedToken.sol';
import {IStakeConfigurator} from '../protocol/stake/interfaces/IStakeConfigurator.sol';
import {IStakeToken} from '../protocol/stake/interfaces/IStakeToken.sol';

contract ProtocolDataProvider is IUiPoolDataProvider {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using UserConfiguration for DataTypes.UserConfigurationMap;

  address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  address public constant USD = 0x10F7Fc1F91Ba351f9C629c5947AD69bD03C05b96;

  enum TokenType {PoolAsset, Deposit, VariableDebt, StableDebt, Stake, Reward, RewardStake}

  struct TokenDescription {
    address token;
    // priceToken == 0 for a non-transferrable token
    address priceToken;
    string tokenSymbol;
    address underlying;
    uint8 decimals;
    TokenType tokenType;
    bool active;
  }

  struct TokenData {
    string symbol;
    address tokenAddress;
  }

  struct StakeTokenBalance {
    uint256 balance;
    uint32 unstakeWindowStart;
    uint32 unstakeWindowEnd;
  }

  IMarketAccessController public immutable ADDRESS_PROVIDER;

  constructor(IMarketAccessController addressesProvider) public {
    ADDRESS_PROVIDER = addressesProvider;
  }

  function getAllTokenDescriptions(bool includeAssets)
    external
    view
    returns (TokenDescription[] memory tokens, uint256 tokenCount)
  {
    IStakeConfigurator stakeCfg = IStakeConfigurator(ADDRESS_PROVIDER.getStakeConfigurator());
    address[] memory stakeList = stakeCfg.list();

    ILendingPool pool = ILendingPool(ADDRESS_PROVIDER.getLendingPool());
    address[] memory reserveList = pool.getReservesList();

    tokenCount = 2 + stakeList.length + reserveList.length * 3;
    if (includeAssets) {
      tokenCount += reserveList.length;
    }

    tokens = new TokenDescription[](tokenCount);

    address token = ADDRESS_PROVIDER.getRewardToken();
    tokens[0] = TokenDescription(
      token,
      token,
      IERC20Detailed(token).symbol(),
      address(0),
      IERC20Detailed(token).decimals(),
      TokenType.Reward,
      true
    );

    token = ADDRESS_PROVIDER.getRewardStakeToken();
    tokens[1] = TokenDescription(
      token,
      address(0),
      IERC20Detailed(token).symbol(),
      tokens[0].token,
      IERC20Detailed(token).decimals(),
      TokenType.RewardStake,
      true
    );
    tokenCount = 2;

    for (uint256 i = 0; i < reserveList.length; i++) {
      token = reserveList[i];
      DataTypes.ReserveData memory reserveData = pool.getReserveData(token);
      (bool isActive, , bool canBorrow, bool canBorrowStable) =
        reserveData.configuration.getFlagsMemory();
      canBorrow = isActive && canBorrow;
      canBorrowStable = canBorrowStable && canBorrow;

      uint8 decimals = reserveData.configuration.getDecimalsMemory();

      if (includeAssets) {
        tokens[tokenCount] = TokenDescription(
          token,
          token,
          IERC20Detailed(token).symbol(),
          address(0),
          decimals,
          TokenType.PoolAsset,
          true
        );
        tokenCount++;
      }

      tokens[tokenCount] = TokenDescription(
        reserveData.aTokenAddress,
        reserveData.aTokenAddress,
        IERC20Detailed(reserveData.aTokenAddress).symbol(),
        token,
        decimals,
        TokenType.Deposit,
        isActive
      );
      tokenCount++;

      if (reserveData.variableDebtTokenAddress != address(0)) {
        tokens[tokenCount] = TokenDescription(
          reserveData.variableDebtTokenAddress,
          address(0),
          IERC20Detailed(reserveData.variableDebtTokenAddress).symbol(),
          token,
          decimals,
          TokenType.VariableDebt,
          canBorrow
        );
        tokenCount++;
      }

      if (reserveData.stableDebtTokenAddress != address(0)) {
        tokens[tokenCount] = TokenDescription(
          reserveData.stableDebtTokenAddress,
          address(0),
          IERC20Detailed(reserveData.stableDebtTokenAddress).symbol(),
          token,
          decimals,
          TokenType.StableDebt,
          canBorrowStable
        );
        tokenCount++;
      }
    }

    for (uint256 i = 0; i < stakeList.length; i++) {
      token = stakeList[i];
      tokens[tokenCount] = TokenDescription(
        token,
        address(0),
        IERC20Detailed(token).symbol(),
        IDerivedToken(token).UNDERLYING_ASSET_ADDRESS(),
        IERC20Detailed(token).decimals(),
        TokenType.Stake,
        true
      );
      tokenCount++;
    }

    return (tokens, tokenCount);
  }

  function getAllTokens(bool includeAssets)
    public
    view
    returns (address[] memory tokens, uint256 tokenCount)
  {
    IStakeConfigurator stakeCfg = IStakeConfigurator(ADDRESS_PROVIDER.getStakeConfigurator());
    address[] memory stakeList = stakeCfg.list();

    ILendingPool pool = ILendingPool(ADDRESS_PROVIDER.getLendingPool());
    address[] memory reserveList = pool.getReservesList();

    tokenCount = 2 + stakeList.length + reserveList.length * 3;
    if (includeAssets) {
      tokenCount += reserveList.length;
    }
    tokens = new address[](tokenCount);

    tokens[0] = ADDRESS_PROVIDER.getRewardToken();
    tokens[1] = ADDRESS_PROVIDER.getRewardStakeToken();

    tokenCount = 2;

    for (uint256 i = 0; i < reserveList.length; i++) {
      address token = reserveList[i];
      DataTypes.ReserveData memory reserveData = pool.getReserveData(token);
      (bool isActive, , bool canBorrow, bool canBorrowStable) =
        reserveData.configuration.getFlagsMemory();
      canBorrow = isActive && canBorrow;
      canBorrowStable = canBorrowStable && canBorrow;

      if (includeAssets) {
        tokens[tokenCount] = token;
        tokenCount++;
      }

      tokens[tokenCount] = reserveData.aTokenAddress;
      tokenCount++;

      if (reserveData.variableDebtTokenAddress != address(0)) {
        tokens[tokenCount] = reserveData.variableDebtTokenAddress;
        tokenCount++;
      }

      if (reserveData.stableDebtTokenAddress != address(0)) {
        tokens[tokenCount] = reserveData.stableDebtTokenAddress;
        tokenCount++;
      }
    }

    for (uint256 i = 0; i < stakeList.length; i++) {
      tokens[tokenCount] = stakeList[i];
      tokenCount++;
    }

    return (tokens, tokenCount);
  }

  function getPoolTokensByType(TokenType tt) public view returns (TokenData[] memory tokens) {
    ILendingPool pool = ILendingPool(ADDRESS_PROVIDER.getLendingPool());
    address[] memory reserves = pool.getReservesList();
    tokens = new TokenData[](reserves.length);

    address token;
    for (uint256 i = 0; i < reserves.length; i++) {
      if (tt == TokenType.PoolAsset) {
        token = reserves[i];
      } else {
        DataTypes.ReserveData memory reserveData = pool.getReserveData(reserves[i]);
        if (tt == TokenType.Deposit) {
          token = reserveData.aTokenAddress;
        } else if (tt == TokenType.VariableDebt) {
          token = reserveData.variableDebtTokenAddress;
        } else if (tt == TokenType.StableDebt) {
          token = reserveData.stableDebtTokenAddress;
        } else {
          revert('UNSUPPORTED');
        }
      }

      if (token != address(0)) {
        tokens[i] = TokenData({symbol: IERC20Detailed(token).symbol(), tokenAddress: token});
      }
    }

    return tokens;
  }

  function getAllDepositTokens() external view returns (TokenData[] memory) {
    return getPoolTokensByType(TokenType.Deposit);
  }

  function getAllReserveTokens() external view returns (TokenData[] memory) {
    return getPoolTokensByType(TokenType.PoolAsset);
  }

  function getReserveConfigurationData(address asset)
    external
    view
    returns (
      uint256 decimals,
      uint256 ltv,
      uint256 liquidationThreshold,
      uint256 liquidationBonus,
      uint256 reserveFactor,
      bool usageAsCollateralEnabled,
      bool borrowingEnabled,
      bool stableBorrowRateEnabled,
      bool isActive,
      bool isFrozen
    )
  {
    DataTypes.ReserveConfigurationMap memory configuration =
      ILendingPool(ADDRESS_PROVIDER.getLendingPool()).getConfiguration(asset);

    (ltv, liquidationThreshold, liquidationBonus, decimals, reserveFactor) = configuration
      .getParamsMemory();

    (isActive, isFrozen, borrowingEnabled, stableBorrowRateEnabled) = configuration
      .getFlagsMemory();

    usageAsCollateralEnabled = liquidationThreshold > 0;
  }

  function getReserveData(address asset)
    external
    view
    returns (
      uint256 availableLiquidity,
      uint256 totalStableDebt,
      uint256 totalVariableDebt,
      uint256 liquidityRate,
      uint256 variableBorrowRate,
      uint256 stableBorrowRate,
      uint256 averageStableBorrowRate,
      uint256 liquidityIndex,
      uint256 variableBorrowIndex,
      uint40 lastUpdateTimestamp
    )
  {
    DataTypes.ReserveData memory reserve =
      ILendingPool(ADDRESS_PROVIDER.getLendingPool()).getReserveData(asset);

    return (
      IERC20Detailed(asset).balanceOf(reserve.aTokenAddress),
      IERC20Detailed(reserve.stableDebtTokenAddress).totalSupply(),
      IERC20Detailed(reserve.variableDebtTokenAddress).totalSupply(),
      reserve.currentLiquidityRate,
      reserve.currentVariableBorrowRate,
      reserve.currentStableBorrowRate,
      IStableDebtToken(reserve.stableDebtTokenAddress).getAverageStableRate(),
      reserve.liquidityIndex,
      reserve.variableBorrowIndex,
      reserve.lastUpdateTimestamp
    );
  }

  function getUserReserveData(address asset, address user)
    external
    view
    returns (
      uint256 currentDepositBalance,
      uint256 currentStableDebt,
      uint256 currentVariableDebt,
      uint256 principalStableDebt,
      uint256 scaledVariableDebt,
      uint256 stableBorrowRate,
      uint256 liquidityRate,
      uint40 stableRateLastUpdated,
      bool usageAsCollateralEnabled
    )
  {
    DataTypes.ReserveData memory reserve =
      ILendingPool(ADDRESS_PROVIDER.getLendingPool()).getReserveData(asset);

    DataTypes.UserConfigurationMap memory userConfig =
      ILendingPool(ADDRESS_PROVIDER.getLendingPool()).getUserConfiguration(user);

    currentDepositBalance = IERC20Detailed(reserve.aTokenAddress).balanceOf(user);
    currentVariableDebt = IERC20Detailed(reserve.variableDebtTokenAddress).balanceOf(user);
    currentStableDebt = IERC20Detailed(reserve.stableDebtTokenAddress).balanceOf(user);
    principalStableDebt = IStableDebtToken(reserve.stableDebtTokenAddress).principalBalanceOf(user);
    scaledVariableDebt = IVariableDebtToken(reserve.variableDebtTokenAddress).scaledBalanceOf(user);
    liquidityRate = reserve.currentLiquidityRate;
    stableBorrowRate = IStableDebtToken(reserve.stableDebtTokenAddress).getUserStableRate(user);
    stableRateLastUpdated = IStableDebtToken(reserve.stableDebtTokenAddress).getUserLastUpdated(
      user
    );
    usageAsCollateralEnabled = userConfig.isUsingAsCollateral(reserve.id);
  }

  function getReserveTokensAddresses(address asset)
    external
    view
    returns (
      address depositTokenAddress,
      address stableDebtTokenAddress,
      address variableDebtTokenAddress
    )
  {
    DataTypes.ReserveData memory reserve =
      ILendingPool(ADDRESS_PROVIDER.getLendingPool()).getReserveData(asset);

    return (
      reserve.aTokenAddress,
      reserve.stableDebtTokenAddress,
      reserve.variableDebtTokenAddress
    );
  }

  function getInterestRateStrategySlopes(IReserveInterestRateStrategy interestRateStrategy)
    internal
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    // return (
    //   interestRateStrategy.variableRateSlope1(),
    //   interestRateStrategy.variableRateSlope2(),
    //   interestRateStrategy.stableRateSlope1(),
    //   interestRateStrategy.stableRateSlope2()
    // );
  }

  function getReservesData(address user)
    external
    view
    override
    returns (
      AggregatedReserveData[] memory,
      UserReserveData[] memory,
      uint256
    )
  {
    return _getReservesData(IPoolAddressProvider(address(ADDRESS_PROVIDER)), user);
  }

  function getReservesDataOf(IPoolAddressProvider provider, address user)
    external
    view
    override
    returns (
      AggregatedReserveData[] memory,
      UserReserveData[] memory,
      uint256
    )
  {
    return _getReservesData(provider, user);
  }

  function _getReservesData(IPoolAddressProvider provider, address user)
    private
    view
    returns (
      AggregatedReserveData[] memory,
      UserReserveData[] memory,
      uint256
    )
  {
    ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
    IPriceOracleGetter oracle = IPriceOracleGetter(provider.getPriceOracle());
    address[] memory reserves = lendingPool.getReservesList();
    DataTypes.UserConfigurationMap memory userConfig = lendingPool.getUserConfiguration(user);

    AggregatedReserveData[] memory reservesData = new AggregatedReserveData[](reserves.length);
    UserReserveData[] memory userReservesData =
      new UserReserveData[](user != address(0) ? reserves.length : 0);

    for (uint256 i = 0; i < reserves.length; i++) {
      AggregatedReserveData memory reserveData = reservesData[i];
      reserveData.underlyingAsset = reserves[i];
      reserveData.pricingAsset = reserveData.underlyingAsset;

      // reserve current state
      DataTypes.ReserveData memory baseData =
        lendingPool.getReserveData(reserveData.underlyingAsset);
      reserveData.liquidityIndex = baseData.liquidityIndex;
      reserveData.variableBorrowIndex = baseData.variableBorrowIndex;
      reserveData.liquidityRate = baseData.currentLiquidityRate;
      reserveData.variableBorrowRate = baseData.currentVariableBorrowRate;
      reserveData.stableBorrowRate = baseData.currentStableBorrowRate;
      reserveData.lastUpdateTimestamp = baseData.lastUpdateTimestamp;
      reserveData.depositTokenAddress = baseData.aTokenAddress;
      reserveData.stableDebtTokenAddress = baseData.stableDebtTokenAddress;
      reserveData.variableDebtTokenAddress = baseData.variableDebtTokenAddress;
      reserveData.interestRateStrategyAddress = baseData.interestRateStrategyAddress;
      reserveData.priceInEth = oracle.getAssetPrice(reserveData.pricingAsset);

      reserveData.availableLiquidity = IERC20Detailed(reserveData.underlyingAsset).balanceOf(
        reserveData.depositTokenAddress
      );
      (
        reserveData.totalPrincipalStableDebt,
        ,
        reserveData.averageStableRate,
        reserveData.stableDebtLastUpdateTimestamp
      ) = IStableDebtToken(reserveData.stableDebtTokenAddress).getSupplyData();
      reserveData.totalScaledVariableDebt = IVariableDebtToken(reserveData.variableDebtTokenAddress)
        .scaledTotalSupply();

      // reserve configuration

      // we're getting this info from the aToken, because some of assets can be not compliant with ETC20Detailed
      reserveData.symbol = IERC20Detailed(reserveData.depositTokenAddress).symbol();
      reserveData.name = '';

      (
        reserveData.baseLTVasCollateral,
        reserveData.reserveLiquidationThreshold,
        reserveData.reserveLiquidationBonus,
        reserveData.decimals,
        reserveData.reserveFactor
      ) = baseData.configuration.getParamsMemory();
      (
        reserveData.isActive,
        reserveData.isFrozen,
        reserveData.borrowingEnabled,
        reserveData.stableBorrowRateEnabled
      ) = baseData.configuration.getFlagsMemory();
      reserveData.usageAsCollateralEnabled = reserveData.baseLTVasCollateral != 0;
      (
        reserveData.variableRateSlope1,
        reserveData.variableRateSlope2,
        reserveData.stableRateSlope1,
        reserveData.stableRateSlope2
      ) = getInterestRateStrategySlopes(
        IReserveInterestRateStrategy(reserveData.interestRateStrategyAddress)
      );

      if (user != address(0)) {
        // user reserve data
        userReservesData[i].underlyingAsset = reserveData.underlyingAsset;
        userReservesData[i].scaledDepositTokenBalance = IDepositToken(
          reserveData
            .depositTokenAddress
        )
          .scaledBalanceOf(user);
        userReservesData[i].usageAsCollateralEnabledOnUser = userConfig.isUsingAsCollateral(i);

        if (userConfig.isBorrowing(i)) {
          userReservesData[i].scaledVariableDebt = IVariableDebtToken(
            reserveData
              .variableDebtTokenAddress
          )
            .scaledBalanceOf(user);
          userReservesData[i].principalStableDebt = IStableDebtToken(
            reserveData
              .stableDebtTokenAddress
          )
            .principalBalanceOf(user);
          if (userReservesData[i].principalStableDebt != 0) {
            userReservesData[i].stableBorrowRate = IStableDebtToken(
              reserveData
                .stableDebtTokenAddress
            )
              .getUserStableRate(user);
            userReservesData[i].stableBorrowLastUpdateTimestamp = IStableDebtToken(
              reserveData
                .stableDebtTokenAddress
            )
              .getUserLastUpdated(user);
          }
        }
      }
    }
    return (reservesData, userReservesData, oracle.getAssetPrice(USD));
  }

  function getAddresses() external view override returns (Addresses memory data) {
    data.addressProvider = address(ADDRESS_PROVIDER);
    data.lendingPool = ADDRESS_PROVIDER.getAddress(AccessFlags.LENDING_POOL);
    data.stakeConfigurator = ADDRESS_PROVIDER.getAddress(AccessFlags.STAKE_CONFIGURATOR);
    data.rewardConfigurator = ADDRESS_PROVIDER.getAddress(AccessFlags.REWARD_CONFIGURATOR);
    data.rewardController = ADDRESS_PROVIDER.getAddress(AccessFlags.REWARD_CONTROLLER);
    data.wethGateway = ADDRESS_PROVIDER.getAddress(AccessFlags.WETH_GATEWAY);
    data.priceOracle = ADDRESS_PROVIDER.getAddress(AccessFlags.PRICE_ORACLE);
    data.lendingPriceOracle = ADDRESS_PROVIDER.getAddress(AccessFlags.LENDING_RATE_ORACLE);
    data.rewardToken = ADDRESS_PROVIDER.getAddress(AccessFlags.REWARD_TOKEN);
    data.rewardStake = ADDRESS_PROVIDER.getAddress(AccessFlags.REWARD_STAKE_TOKEN);
    data.referralRegistry = ADDRESS_PROVIDER.getAddress(AccessFlags.REFERRAL_REGISTRY);
  }

  /**
   * @notice Fetches balances for a list of _users and _tokens (ETH included with mock address)
   * @param users The list of users
   * @param tokens The list of stake tokens
   * @return balances - an array with the concatenation of balances for each user
   **/
  function batchStakeBalanceOf(address[] calldata users, address[] calldata tokens)
    external
    view
    returns (StakeTokenBalance[] memory balances)
  {
    balances = new StakeTokenBalance[](users.length * tokens.length);

    for (uint256 i = 0; i < users.length; i++) {
      for (uint256 j = 0; j < tokens.length; j++) {
        StakeTokenBalance memory b;
        (b.balance, b.unstakeWindowStart, b.unstakeWindowEnd) = IStakeToken(tokens[j])
          .balanceAndCooldownOf(users[i]);
        balances[i * tokens.length + j] = b;
      }
    }

    return balances;
  }

  // influenced by Aave && https://github.com/wbobeirne/eth-balance-checker/blob/master/contracts/BalanceChecker.sol

  /**
    @dev Check the token balance of a wallet in a token contract
    Returns the balance of the token for user, and 0 on non-contract address
    **/
  function balanceOf(address user, address token) public view returns (uint256) {
    if (token == ETH) {
      return user.balance; // ETH balance
    } else if (Address.isContract(token)) {
      return IERC20Detailed(token).balanceOf(user);
    }
    return 0;
  }

  /**
   * @notice Fetches balances for a list of _users and _tokens (ETH included with mock address)
   * @param users The list of users
   * @param tokens The list of tokens
   * @return An array with the concatenation of balances for each user
   **/
  function batchBalanceOf(address[] calldata users, address[] calldata tokens)
    external
    view
    returns (uint256[] memory)
  {
    uint256[] memory balances = new uint256[](users.length * tokens.length);

    for (uint256 i = 0; i < users.length; i++) {
      for (uint256 j = 0; j < tokens.length; j++) {
        balances[i * tokens.length + j] = balanceOf(users[i], tokens[j]);
      }
    }

    return balances;
  }

  /**
    @dev provides balances of user wallet for all tokens available on the protocol
    */
  function getUserWalletBalances(address user, bool includeAssets)
    external
    view
    returns (
      address[] memory tokens,
      uint256[] memory balances,
      uint256 tokenCount
    )
  {
    (tokens, tokenCount) = getAllTokens(includeAssets);

    balances = new uint256[](tokenCount);
    for (uint256 j = 0; j < tokenCount; j++) {
      balances[j] = balanceOf(user, tokens[j]);
    }

    return (tokens, balances, tokenCount);
  }
}
