pragma solidity 0.7.4;

/**
 * @notice The TieredOwnable can assign ownership tiers to addresses,
 * allowing inheriting contracts to choose which tier can call which function.
 */
contract TieredOwnable {
  uint256 constant internal HIGHEST_OWNER_TIER = 2**256-1; //Highest possible tier

  mapping(address => uint256) internal ownerTier;
  event OwnershipGranted(address indexed owner, uint256 indexed previousTier, uint256 indexed newTier);

  /**
   * @dev Sets the _firstOwner provided to highest owner tier
   * @dev _firstOwner First address to be a owner of this contract
   */
  constructor (address _firstOwner) {
    require(_firstOwner != address(0), "TieredOwnable#constructor: INVALID_FIRST_OWNER");
    ownerTier[_firstOwner] = HIGHEST_OWNER_TIER;
    emit OwnershipGranted(_firstOwner, 0, HIGHEST_OWNER_TIER);
  }

  /**
   * @dev Throws if called by an account that's in lower ownership tier than expected
   */
  modifier onlyOwnerTier(uint256 _minTier) {
    require(ownerTier[msg.sender] >= _minTier, "TieredOwnable#onlyOwnerTier: OWNER_TIER_IS_TOO_LOW");
    _;
  }

  /**
   * @notice Highest owners can change ownership tier of other owners
   * @dev Prevents changing sender's tier to ensure there is always at least one HIGHEST_OWNER_TIER owner.
   * @param _address Address of the owner
   * @param _tier    Ownership tier assigned to owner
   */
  function assignOwnership(address _address, uint256 _tier) external onlyOwnerTier(HIGHEST_OWNER_TIER) {
    require(_address != address(0), "TieredOwnable#assignOwnership: INVALID_ADDRESS");
    require(msg.sender != _address, "TieredOwnable#assignOwnership: UPDATING_SELF_TIER");
    emit OwnershipGranted(_address, ownerTier[_address], _tier);
    ownerTier[_address] = _tier;
  }

  /**
   * @notice Returns the ownership tier of provided owner
   * @param _owner Owner's address to query ownership tier
   */
  function getOwnerTier(address _owner) external view returns (uint256) {
    return ownerTier[_owner];
  }
}