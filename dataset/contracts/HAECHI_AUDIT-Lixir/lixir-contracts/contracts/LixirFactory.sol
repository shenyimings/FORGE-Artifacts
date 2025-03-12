pragma solidity ^0.7.6;

import '@openzeppelin/contracts/utils/EnumerableSet.sol';
import '@openzeppelin/contracts/proxy/Clones.sol';
import 'contracts/interfaces/ILixirVault.sol';
import 'contracts/interfaces/ILixirStrategy.sol';
import 'contracts/LixirBase.sol';

/**
  @notice Factory for creating new vaults.
 */
contract LixirFactory is LixirBase {
  using EnumerableSet for EnumerableSet.AddressSet;
  address public immutable weth9;

  mapping(address => mapping(address => EnumerableSet.AddressSet)) _vaults;

  mapping(address => address) public vaultToImplementation;

  event VaultCreated(
    address indexed token0,
    address indexed token1,
    address indexed vault_impl,
    address vault
  );

  constructor(address _registry) LixirBase(_registry) {
    weth9 = address(LixirRegistry(_registry).weth9());
  }

  // view functions

  /**
    @notice Grab the number of vaults for the pair from `vaultsLengthForPair`
    @param token0 address of the first token
    @param token1 address of the second token
    @param index the index of the vault.
    @return the address of the vault for the token pair at the given index 
   */
  function vault(
    address token0,
    address token1,
    uint256 index
  ) public view returns (address) {
    (token0, token1) = orderTokens(token0, token1);
    return _vaults[token0][token1].at(index);
  }

  /**
    @param token0 address of the first token
    @param token1 address of the second token
    @return number of vaults for the given token pair
   */
  function vaultsLengthForPair(address token0, address token1)
    external
    view
    returns (uint256)
  {
    (token0, token1) = orderTokens(token0, token1);
    return _vaults[token0][token1].length();
  }

  // external functions

  /** 
    @notice deploys a new vault for a pair of ERC20 tokens
    @param name ERC20 metadata extension name of the vault token
    @param symbol ERC20 metadata extension symbol of the vault token
    @param token0 address of the first ERC20 token
    @param token1 address of the second ERC20 token
    @param vaultImplementation address of the vault to clone
    @param strategist external address to be granted strategist role
    @param keeper external address to be given the keeper role
    @param strategy address of the strategy contract that will
    rebalance this vault's positions
    @return the address of the newly created vault
   */
  function createVault(
    string memory name,
    string memory symbol,
    address token0,
    address token1,
    address vaultImplementation,
    address strategist,
    address keeper,
    address strategy,
    bytes memory data
  )
    external
    onlyRole(LixirRoles.deployer_role)
    hasRole(LixirRoles.strategy_role, strategy)
    hasRole(LixirRoles.vault_implementation_role, vaultImplementation)
    returns (address)
  {
    require(registry.hasRole(LixirRoles.keeper_role, keeper));
    require(registry.hasRole(LixirRoles.strategist_role, strategist));
    require(
      token0 != weth9 && token1 != weth9,
      'Use eth vault creator instead'
    );
    return
      _createVault(
        name,
        symbol,
        token0,
        token1,
        vaultImplementation,
        strategist,
        keeper,
        strategy,
        data
      );
  }

  /** 
  @notice deploys a new vault for a WETH/ERC20 pair
  @dev ERC20 pairs require a different interface from ETH/ERC20
  vaults. Otherwise this is the same as `createVault`
  @param name ERC20 metadata extension name of the vault token
  @param symbol ERC20 metadata extension symbol of the vault toke
  @param token0 address of the first ERC20 token
  @param token1 address of the second ERC20 token
  @param ethVaultImplementation address of the ethVault to clone
  @param strategist address of a (likely) user account to be granted
  the strategist role
  @param keeper address of a user to be given the keeper role
  @param strategy address of the strategy contract that uses this
  vault
  @return the address of the newly created vault
  */
  function createVaultETH(
    string memory name,
    string memory symbol,
    address token0,
    address token1,
    address ethVaultImplementation,
    address strategist,
    address keeper,
    address strategy,
    bytes memory data
  )
    external
    onlyRole(LixirRoles.deployer_role)
    hasRole(LixirRoles.strategy_role, strategy)
    hasRole(LixirRoles.eth_vault_implementation_role, ethVaultImplementation)
    returns (address)
  {
    require(registry.hasRole(LixirRoles.keeper_role, keeper));
    require(registry.hasRole(LixirRoles.strategist_role, strategist));
    require(
      token0 == weth9 || token1 == weth9,
      'No weth, use regular vault creator'
    );
    return
      _createVault(
        name,
        symbol,
        token0,
        token1,
        ethVaultImplementation,
        strategist,
        keeper,
        strategy,
        data
      );
  }

  // internal functions

  function orderTokens(address token0, address token1)
    internal
    pure
    returns (address, address)
  {
    require(token0 != token1, 'Duplicate tokens');
    (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
    return (token0, token1);
  }


  function _createVault(
    string memory name,
    string memory symbol,
    address token0,
    address token1,
    address vaultImplementation,
    address strategist,
    address keeper,
    address strategy,
    bytes memory data
  ) internal returns (address) {
    (token0, token1) = orderTokens(token0, token1);
    bytes32 salt =
      keccak256(
        abi.encodePacked(token0, token1, _vaults[token0][token1].length())
      );
    ILixirVault _vault =
      ILixirVault(Clones.cloneDeterministic(vaultImplementation, salt));
    _vault.initialize(
      name,
      symbol,
      token0,
      token1,
      strategist,
      keeper,
      strategy
    );
    _vaults[token0][token1].add(address(_vault));
    vaultToImplementation[address(_vault)] = vaultImplementation;
    registry.grantRole(LixirRoles.vault_role, address(_vault));
    ILixirStrategy(strategy).initializeVault(_vault, data);
    emit VaultCreated(token0, token1, vaultImplementation, address(_vault));
    return address(_vault);
  }
}
