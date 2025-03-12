//   ██████╗ ███████╗ ██████╗ ██████╗ ███████╗    ██████╗  ██████╗ ██████╗ ████████╗ █████╗ ██╗
//  ██╔════╝ ██╔════╝██╔═══██╗██╔══██╗██╔════╝    ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝██╔══██╗██║
//  ██║  ███╗█████╗  ██║   ██║██║  ██║█████╗      ██████╔╝██║   ██║██████╔╝   ██║   ███████║██║
//  ██║   ██║██╔══╝  ██║   ██║██║  ██║██╔══╝      ██╔═══╝ ██║   ██║██╔══██╗   ██║   ██╔══██║██║
//  ╚██████╔╝███████╗╚██████╔╝██████╔╝███████╗    ██║     ╚██████╔╝██║  ██║   ██║   ██║  ██║███████╗
//   ╚═════╝ ╚══════╝ ╚═════╝ ╚═════╝ ╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝
//

// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// globals
import {ID_TYPE} from "./globals/id_type.sol";
// interfaces
import {IGeodeModule} from "./interfaces/modules/IGeodeModule.sol";
import {IPortal} from "./interfaces/IPortal.sol";
import {IStakeModule} from "./interfaces/modules/IStakeModule.sol";
// libraries
import {DataStoreModuleLib as DSML} from "./modules/DataStoreModule/libs/DataStoreModuleLib.sol";
import {GeodeModuleLib as GML} from "./modules/GeodeModule/libs/GeodeModuleLib.sol";
import {StakeModuleLib as SML} from "./modules/StakeModule/libs/StakeModuleLib.sol";
// contracts
import {GeodeModule} from "./modules/GeodeModule/GeodeModule.sol";
import {StakeModule} from "./modules/StakeModule/StakeModule.sol";

/**
 * @title Geode Portal: Geode Module + Stake Module
 *
 * @notice Global standard for staking with on chain delegation and customizable staking pools.
 * Management of the state of the protocol governance through dual governance and proposals.
 * Version management and distribution of packages used by the staking pools.
 *
 * @dev TYPE: PACKAGE_PORTAL
 * @dev Portal is a special package that is deployed once. Does not utilize IGeodePackage interface.
 *
 * @dev review: GM for The Limited Upgradability through Dual Governance:
 * * Governance is a governance token.
 * * Senate is a multisig, planned to be a contract that allows pool CONTROLLERs to maintain power.
 * * Senate expiry is effective.
 *
 * @dev review: SM for Staking logic.
 *
 * @dev There are 2 functionalities that are implemented here:
 * * Special Governance functions for Portal:
 * * * Pausing gETH, pausing Portal, releasing prisoned operators,and seting a governance fee.
 * * Push end of the version management logic via pull->push.
 * * * approveProposal changes the package version or allows specified middleware.
 * * * pushUpgrade creates a contract upgrade proposal on the package, and requires package owner to approve it.
 *
 * @dev authentication:
 * * GeodeModule has OnlyGovernance, OnlySenate and OnlyController checks with modifiers.
 * * StakeModuleLib has "authenticate()" function which checks for Maintainers, Controllers, and TYPE.
 * * OracleModuleLib has OnlyOracle checks with a modifier.
 * * Portal has an OnlyGovernance check on : pause, unpause, pausegETH, unpausegETH, setGovernanceFee, releasePrisoned.
 *
 * @author Ice Bear & Crash Bandicoot
 */
contract Portal is IPortal, StakeModule, GeodeModule {
  using DSML for DSML.IsolatedStorage;
  using GML for GML.DualGovernance;

  /**
   * @custom:section                           ** EVENTS **
   */
  event Released(uint256 operatorId);
  event GovernanceFeeSet(uint256 fee);

  /**
   * @custom:section                           ** MODIFIERS **
   */
  modifier onlyGovernance() {
    require(msg.sender == GEODE.SENATE, "Portal:sender NOT governance");
    _;
  }

  /**
   * @custom:section                           ** INITIALIZING **
   */

  ///@custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    address _governance,
    address _senate,
    address _gETH,
    address _oracle_position,
    bytes calldata versionName
  ) public virtual initializer {
    __Portal_init(_governance, _senate, _gETH, _oracle_position, versionName);
  }

  function __Portal_init(
    address _governance,
    address _senate,
    address _gETH,
    address _oracle_position,
    bytes calldata versionName
  ) internal onlyInitializing {
    __GeodeModule_init(
      _governance,
      _senate,
      block.timestamp + GML.MAX_SENATE_PERIOD,
      ID_TYPE.PACKAGE_PORTAL,
      versionName
    );
    __StakeModule_init(_gETH, _oracle_position);
    __Portal_init_unchained();
  }

  function __Portal_init_unchained() internal onlyInitializing {}

  /**
   * @custom:section                           ** GETTER FUNCTIONS **
   *
   * @custom:visibility -> view-external
   */

  /**
   * @dev GeodeModule override
   *
   * @notice Isolation Mode is an external view function signaling other contracts
   * * to isolate themselves from Portal. For example, withdrawalContract will not fetch upgrades.
   * @return isRecovering true if isolationMode is active:
   * * 1. Portal is paused
   * * 2. Portal needs to be upgraded
   * * 3. Senate expired
   */
  function isolationMode()
    external
    view
    virtual
    override(GeodeModule, IGeodeModule)
    returns (bool)
  {
    return (paused() ||
      GEODE.APPROVED_UPGRADE != _getImplementation() ||
      block.timestamp > GEODE.SENATE_EXPIRY);
  }

  /**
   * @custom:section                           ** GOVERNANCE FUNCTIONS **
   *
   * @custom:visibility -> external
   */

  function pause() external virtual override(StakeModule, IStakeModule) onlyGovernance {
    _pause();
  }

  function unpause() external virtual override(StakeModule, IStakeModule) onlyGovernance {
    _unpause();
  }

  function pausegETH() external virtual override onlyGovernance {
    STAKE.gETH.pause();
  }

  function unpausegETH() external virtual override onlyGovernance {
    STAKE.gETH.unpause();
  }

  /**
   * @notice releases an imprisoned operator immidately
   * @dev in different situations such as a faulty imprisonment or coordinated testing periods
   * * Governance can release the prisoners
   * @dev onlyGovernance SHOULD be checked in Portal
   */
  function releasePrisoned(uint256 operatorId) external virtual override onlyGovernance {
    DATASTORE.writeUint(operatorId, "release", block.timestamp);

    emit Released(operatorId);
  }

  function setGovernanceFee(uint256 newFee) external virtual override onlyGovernance {
    require(newFee <= SML.MAX_GOVERNANCE_FEE, "Portal:> MAX_GOVERNANCE_FEE");
    require(block.timestamp > 1714514461, "Portal:not yet");

    STAKE.GOVERNANCE_FEE = newFee;

    emit GovernanceFeeSet(newFee);
  }

  /**
   * @custom:section                           ** PACKAGE VERSION MANAGEMENT **
   *
   * @custom:visibility -> external
   */

  /**
   * @notice approves a specific proposal
   * @dev OnlySenate is checked inside the GeodeModule
   */
  function approveProposal(
    uint256 id
  )
    public
    virtual
    override(GeodeModule, IGeodeModule)
    returns (address _controller, uint256 _type, bytes memory _name)
  {
    (_controller, _type, _name) = super.approveProposal(id);

    if (_type > ID_TYPE.LIMIT_MIN_PACKAGE && _type < ID_TYPE.LIMIT_MAX_PACKAGE) {
      STAKE.packages[_type] = id;
    } else if (_type > ID_TYPE.LIMIT_MIN_MIDDLEWARE && _type < ID_TYPE.LIMIT_MAX_MIDDLEWARE) {
      STAKE.middlewares[_type][id] = true;
    }
  }

  function pushUpgrade(
    uint256 packageType
  ) external virtual override whenNotPaused nonReentrant returns (bytes memory versionName) {
    require(
      packageType > ID_TYPE.LIMIT_MIN_PACKAGE && packageType < ID_TYPE.LIMIT_MAX_PACKAGE,
      "PORTAL:invalid package type"
    );

    uint256 currentPackageVersion = STAKE.packages[packageType];
    versionName = DATASTORE.readBytes(currentPackageVersion, "NAME");

    uint256 id = IGeodeModule(msg.sender).propose(
      DATASTORE.readAddress(currentPackageVersion, "CONTROLLER"),
      ID_TYPE.CONTRACT_UPGRADE,
      versionName,
      GML.MAX_PROPOSAL_DURATION
    );

    require(id > 0, "PORTAL:cannot push upgrade");
  }

  /**
   * @notice fallback functions
   */

  receive() external payable {}

  /**
   * @notice keep the contract size at 50
   */
  uint256[50] private __gap;
}
