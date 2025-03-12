pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./interfaces/IRegistry.sol";
import "./interfaces/IPoaToken.sol";
import "./interfaces/IPoaCrowdsale.sol";
import "./PoaProxy.sol";


contract PoaManager is Ownable {
  using SafeMath for uint256;

  uint256 constant version = 1;

  IRegistry public registry;

  struct EntityState {
    uint256 index;
    bool active;
  }

  // Keeping a list for addresses we track for easy access
  address[] private issuerAddressList;
  address[] private tokenAddressList;

  // A mapping for each address we track
  mapping (address => EntityState) private tokenMap;
  mapping (address => EntityState) private issuerMap;

  event IssuerAdded(address indexed issuer);
  event IssuerRemoved(address indexed issuer);
  event IssuerStatusChanged(address indexed issuer, bool active);

  event TokenAdded(address indexed token);
  event TokenRemoved(address indexed token);
  event TokenStatusChanged(address indexed token, bool active);

  modifier isNewIssuer(address _issuerAddress) {
    require(_issuerAddress != address(0));
    require(issuerMap[_issuerAddress].index == 0);
    _;
  }

  modifier onlyActiveIssuer() {
    EntityState memory entity = issuerMap[msg.sender];
    require(entity.active);
    _;
  }

  constructor(address _registryAddress)
    public
  {
    require(_registryAddress != address(0));
    registry = IRegistry(_registryAddress);
  }

  //
  // Entity functions
  //

  function doesEntityExist(
    address _entityAddress,
    EntityState entity
  )
    private
    pure
    returns (bool)
  {
    return (_entityAddress != address(0) && entity.index != 0);
  }

  function addEntity(
    address _entityAddress,
    address[] storage entityList,
    bool _active
  )
    private
    returns (EntityState)
  {
    entityList.push(_entityAddress);
    // we do not offset by `-1` so that we never have `entity.index = 0` as this is what is
    // used to check for existence in modifier [doesEntityExist]
    uint256 index = entityList.length;
    EntityState memory entity = EntityState(index, _active);

    return entity;
  }

  function removeEntity(
    EntityState _entityToRemove,
    address[] storage _entityList
  )
    private
    returns (address, uint256)
  {
    // we offset by -1 here to account for how `addEntity` marks the `entity.index` value
    uint256 index = _entityToRemove.index.sub(1);

    // swap the entity to be removed with the last element in the list
    _entityList[index] = _entityList[_entityList.length - 1];

    // because we wanted seperate mappings for token and issuer, and we cannot pass a storage mapping
    // as a function argument, this abstraction is leaky; we return the address and index so the
    // caller can update the mapping
    address entityToSwapAddress = _entityList[index];

    // we do not need to delete the element, the compiler should clean up for us
    _entityList.length--;

    return (entityToSwapAddress, _entityToRemove.index);
  }

  function setEntityActiveValue(
    EntityState storage entity,
    bool _active
  )
    private
  {
    require(entity.active != _active);
    entity.active = _active;
  }

  //
  // Issuer functions
  //

  // Return all tracked issuer addresses
  function getIssuerAddressList()
    public
    view
    returns (address[])
  {
    return issuerAddressList;
  }

  // Add an issuer and set active value to true
  function addIssuer(address _issuerAddress)
    public
    onlyOwner
    isNewIssuer(_issuerAddress)
  {
    issuerMap[_issuerAddress] = addEntity(
      _issuerAddress,
      issuerAddressList,
      true
    );

    emit IssuerAdded(_issuerAddress);
  }

  // Remove an issuer
  function removeIssuer(address _issuerAddress)
    public
    onlyOwner
  {
    require(doesEntityExist(_issuerAddress, issuerMap[_issuerAddress]));

    address addressToUpdate;
    uint256 indexUpdate;
    (addressToUpdate, indexUpdate) = removeEntity(issuerMap[_issuerAddress], issuerAddressList);
    issuerMap[addressToUpdate].index = indexUpdate;
    delete issuerMap[_issuerAddress];

    emit IssuerRemoved(_issuerAddress);
  }

  // Set previously delisted issuer to listed
  function listIssuer(address _issuerAddress)
    public
    onlyOwner
  {
    require(doesEntityExist(_issuerAddress, issuerMap[_issuerAddress]));

    setEntityActiveValue(issuerMap[_issuerAddress], true);
    emit IssuerStatusChanged(_issuerAddress, true);
  }

  // Set previously listed issuer to delisted
  function delistIssuer(address _issuerAddress)
    public
    onlyOwner
  {
    require(doesEntityExist(_issuerAddress, issuerMap[_issuerAddress]));

    setEntityActiveValue(issuerMap[_issuerAddress], false);
    emit IssuerStatusChanged(_issuerAddress, false);
  }

  function isActiveIssuer(address _issuerAddress)
    public
    view
    returns (bool)
  {
    require(doesEntityExist(_issuerAddress, issuerMap[_issuerAddress]));

    return issuerMap[_issuerAddress].active;
  }

  function isRegisteredIssuer(address _issuerAddress)
    external
    view
    returns (bool)
  {
    return doesEntityExist(_issuerAddress, issuerMap[_issuerAddress]);
  }

  //
  // Token functions
  //

  // Return all tracked token addresses
  function getTokenAddressList()
    public
    view
    returns (address[])
  {
    return tokenAddressList;
  }

  function createPoaTokenProxy()
    private
    returns (address _proxyContract)
  {
    address _poaTokenMaster = registry.getContractAddress("PoaTokenMaster");
    address _poaCrowdsaleMaster = registry.getContractAddress("PoaCrowdsaleMaster");
    _proxyContract = new PoaProxy(_poaTokenMaster, _poaCrowdsaleMaster, address(registry));
  }

  /**
    @notice Creates a PoaToken contract with given parameters, and set active value to false
    @param _fiatCurrency32 Fiat symbol used in ExchangeRates
    @param _startTimeForFundingPeriod Given as unix time in seconds since 01.01.1970
    @param _durationForFiatFundingPeriod How long fiat funding can last, given in seconds
    @param _durationForEthFundingPeriod How long eth funding can last, given in seconds
    @param _durationForActivationPeriod How long a custodian has to activate token, given in seconds
    @param _fundingGoalInCents Given as fiat cents
   */
  function addNewToken(
    bytes32 _name32,
    bytes32 _symbol32,
    bytes32 _fiatCurrency32,
    address _custodian,
    uint256 _totalSupply,
    uint256 _startTimeForFundingPeriod,
    uint256 _durationForFiatFundingPeriod,
    uint256 _durationForEthFundingPeriod,
    uint256 _durationForActivationPeriod,
    uint256 _fundingGoalInCents
  )
    public
    onlyActiveIssuer
    returns (address)
  {
    address _tokenAddress = createPoaTokenProxy();

    IPoaToken(_tokenAddress).initializeToken(
      _name32,
      _symbol32,
      msg.sender,
      _custodian,
      registry,
      _totalSupply
    );

    IPoaCrowdsale(_tokenAddress).initializeCrowdsale(
      _fiatCurrency32,
      _startTimeForFundingPeriod,
      _durationForFiatFundingPeriod,
      _durationForEthFundingPeriod,
      _durationForActivationPeriod,
      _fundingGoalInCents
    );

    tokenMap[_tokenAddress] = addEntity(
      _tokenAddress,
      tokenAddressList,
      false
    );

    emit TokenAdded(_tokenAddress);

    return _tokenAddress;
  }

  /**
    @notice Add existing `PoaProxy` contracts when `PoaManager` has been upgraded
    @param _tokenAddress the `PoaProxy` address to address
    @param _isListed if `PoaProxy` should be added as active or inactive
    @dev `PoaProxy` contracts can only be added when the POA's issuer is already listed.
         Furthermore, we use `issuer()` as check if `_tokenAddress` represents a `PoaProxy`.
   */
  function addExistingToken(address _tokenAddress, bool _isListed)
    external
    onlyOwner
  {
    require(!doesEntityExist(_tokenAddress, tokenMap[_tokenAddress]));
    // Issuer address of `_tokenAddress` must be an active Issuer.
    // If `_tokenAddress` is not an instance of PoaProxy, this will fail as desired.
    require(isActiveIssuer(IPoaToken(_tokenAddress).issuer()));

    tokenMap[_tokenAddress] = addEntity(
      _tokenAddress,
      tokenAddressList,
      _isListed
    );
  }

  // Remove a token
  function removeToken(address _tokenAddress)
    public
    onlyOwner
  {
    require(doesEntityExist(_tokenAddress, tokenMap[_tokenAddress]));

    address addressToUpdate;
    uint256 indexUpdate;
    (addressToUpdate, indexUpdate) = removeEntity(tokenMap[_tokenAddress], tokenAddressList);
    tokenMap[addressToUpdate].index = indexUpdate;
    delete tokenMap[_tokenAddress];

    emit TokenRemoved(_tokenAddress);
  }

  // Set previously delisted token to listed
  function listToken(address _tokenAddress)
    public
    onlyOwner
  {
    require(doesEntityExist(_tokenAddress, tokenMap[_tokenAddress]));

    setEntityActiveValue(tokenMap[_tokenAddress], true);
    emit TokenStatusChanged(_tokenAddress, true);
  }

  // Set previously listed token to delisted
  function delistToken(address _tokenAddress)
    public
    onlyOwner
  {
    require(doesEntityExist(_tokenAddress, tokenMap[_tokenAddress]));

    setEntityActiveValue(tokenMap[_tokenAddress], false);
    emit TokenStatusChanged(_tokenAddress, false);
  }

  function isActiveToken(address _tokenAddress)
    public
    view
    returns (bool)
  {
    require(doesEntityExist(_tokenAddress, tokenMap[_tokenAddress]));

    return tokenMap[_tokenAddress].active;
  }

  function isRegisteredToken(address _tokenAddress)
    external
    view
    returns (bool)
  {
    return doesEntityExist(_tokenAddress, tokenMap[_tokenAddress]);
  }

  //
  // Token onlyOwner functions as PoaManger is `owner` of all PoaToken
  //

  // Allow unpausing a listed PoaToken
  function pauseToken(address _tokenAddress)
    public
    onlyOwner
  {
    IPoaToken(_tokenAddress).pause();
  }

  // Allow unpausing a listed PoaToken
  function unpauseToken(IPoaToken _tokenAddress)
    public
    onlyOwner
  {
    _tokenAddress.unpause();
  }

  // Allow terminating a listed PoaToken
  function terminateToken(IPoaToken _tokenAddress)
    public
    onlyOwner
  {
    _tokenAddress.terminate();
  }

  // upgrade an existing PoaToken proxy to what is stored in ContractRegistry
  function upgradeToken(PoaProxy _proxyToken)
    external
    onlyOwner
    returns (bool)
  {
    _proxyToken.proxyChangeTokenMaster(
      registry.getContractAddress("PoaTokenMaster")
    );

    return true;
  }

  // upgrade an existing PoaCrowdsale proxy to what is stored in ContractRegistry
  function upgradeCrowdsale(PoaProxy _proxyToken)
    external
    onlyOwner
    returns (bool)
  {
    _proxyToken.proxyChangeCrowdsaleMaster(
      registry.getContractAddress("PoaCrowdsaleMaster")
    );

    return true;
  }
}
