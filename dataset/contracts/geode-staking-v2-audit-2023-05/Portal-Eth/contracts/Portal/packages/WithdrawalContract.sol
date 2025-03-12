// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// globals
import {ID_TYPE} from "../globals/id_type.sol";
import {RESERVED_KEY_SPACE as rks} from "../globals/reserved_key_space.sol";
// interfaces
import {IWithdrawalContract} from "../interfaces/packages/IWithdrawalContract.sol";
import {IPortal} from "../interfaces/IPortal.sol";
import {IGeodeModule} from "../interfaces/modules/IGeodeModule.sol";
// libraries
import {DataStoreModuleLib as DSML} from "../modules/DataStoreModule/libs/DataStoreModuleLib.sol";
// contracts
import {GeodeModule} from "../modules/GeodeModule/GeodeModule.sol";

contract WithdrawalContract is IWithdrawalContract, GeodeModule {
  /**
   * @custom:section                           ** VARIABLES **
   * Following immutable parameters are set when the referance library implementation is deployed.
   * Making necessary data for initialization reachable for all instances of LP package.
   */
  /// @notice gETH position
  address internal immutable gETHPos;
  /// @notice Portal position
  address internal immutable portalPos;
  uint internal POOL_ID; // delete this, just a placeholder for now.
  /**
   * @custom:section                           ** MODIFIERS **
   */

  modifier onlyOwner() {
    require(msg.sender == GEODE.SENATE, "LPP:sender NOT owner");
    _;
  }

  /**
   * @custom:section                           ** INITIALIZING **
   */
  /**
   * @custom:oz-upgrades-unsafe-allow constructor
   *
   * @dev we don't want to provide these package-specific not-changing parameters
   * accross all instances of the packages.
   * So we will store them in the ref implementation contract of the package,
   * and fetch when needed on initialization.
   */
  constructor(address _gETHPos, address _portalPos) {
    require(_gETHPos != address(0), "LPP:_gETHPos can not be zero");
    require(_portalPos != address(0), "LPP:_portalPos can not be zero");

    gETHPos = _gETHPos;
    portalPos = _portalPos;

    _disableInitializers();
  }

  function initialize(
    uint256 pooledTokenId,
    address poolOwner,
    bytes calldata versionName,
    bytes calldata data
  ) public virtual override initializer {
    __WithdrawalContract_init(pooledTokenId, poolOwner, versionName);
  }

  function __WithdrawalContract_init(
    uint256 pooledTokenId,
    address poolOwner,
    bytes calldata versionName
  ) internal onlyInitializing {
    __GeodeModule_init(
      portalPos,
      poolOwner,
      type(uint256).max,
      ID_TYPE.PACKAGE_WITHDRAWAL_CONTRACT,
      versionName
    );

    __WithdrawalContract_init_unchained(pooledTokenId);
  }

  function __WithdrawalContract_init_unchained(uint256 pooledTokenId) internal onlyInitializing {
    POOL_ID = pooledTokenId;
  }

  // todo
  function getPoolId() public view override returns (uint256) {
    return POOL_ID;
  }

  /**
   * @notice get Portal as a contract
   */
  function getPortal() public view override returns (IPortal) {
    return IPortal(GEODE.GOVERNANCE);
  }

  /**
   * @dev GeodeModule override
   */
  function getProposedVersion() public view virtual override returns (uint256) {
    return getPortal().getPackageVersion(GEODE.PACKAGE_TYPE);
  }

  function pullUpgrade() external virtual override onlyOwner {
    require(!(getPortal().isolationMode()), "LPP:Portal is isolated");
    require(getProposedVersion() != getContractVersion(), "LPP:no upgrades");

    bytes memory versionName = getPortal().pushUpgrade(GEODE.PACKAGE_TYPE);
    approveProposal(DSML.generateId(versionName, ID_TYPE.CONTRACT_UPGRADE));
  }

  /**
   * @dev GeodeModule override
   */
  function isolationMode()
    external
    view
    virtual
    override(GeodeModule, IGeodeModule)
    returns (bool)
  {
    if (getContractVersion() != getProposedVersion()) return true;
    if (GEODE.APPROVED_UPGRADE != _getImplementation()) return true;
    if (getPortal().readAddress(getPoolId(), rks.CONTROLLER) != GEODE.SENATE) return true;
    return false;
  }
}
