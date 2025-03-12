// Dependency file: @openzeppelin/contracts/proxy/Clones.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (proxy/Clones.sol)

// pragma solidity ^0.8.0;

/**
 * @dev https://eips.ethereum.org/EIPS/eip-1167[EIP 1167] is a standard for
 * deploying minimal proxy contracts, also known as "clones".
 *
 * > To simply and cheaply clone contract functionality in an immutable way, this standard specifies
 * > a minimal bytecode implementation that delegates all calls to a known, fixed address.
 *
 * The library includes functions to deploy a proxy using either `create` (traditional deployment) or `create2`
 * (salted deterministic deployment). It also includes functions to predict the addresses of clones deployed using the
 * deterministic method.
 *
 * _Available since v3.4._
 */
library Clones {
    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(address implementation) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
        require(instance != address(0), "ERC1167: create failed");
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create2(0, ptr, 0x37, salt)
        }
        require(instance != address(0), "ERC1167: create2 failed");
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf3ff00000000000000000000000000000000)
            mstore(add(ptr, 0x38), shl(0x60, deployer))
            mstore(add(ptr, 0x4c), salt)
            mstore(add(ptr, 0x6c), keccak256(ptr, 0x37))
            predicted := keccak256(add(ptr, 0x37), 0x55)
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(address implementation, bytes32 salt)
        internal
        view
        returns (address predicted)
    {
        return predictDeterministicAddress(implementation, salt, address(this));
    }
}


// Dependency file: contracts/interfaces/IPool.sol

// pragma solidity >=0.8.4 <0.9.0;

interface IPool {
  function init(address registry_, bytes32 domain_) external returns (bool);
}


// Dependency file: contracts/interfaces/IDAO.sol

// pragma solidity >=0.8.4 <0.9.0;

interface IDAO {
  struct Proposal {
    bytes32 proposalDigest;
    int256 vote;
    uint64 expired;
    bool executed;
    bool delegate;
    address target;
    bytes data;
  }

  function init(address _registry, bytes32 _domain) external returns (bool);

  function createProposal(Proposal memory newProposal) external returns (uint256);

  function voteProposal(uint256 proposalId, bool positive) external returns (bool);

  function execute(uint256 proposalId) external returns (bool);
}


// Dependency file: contracts/interfaces/IDAOToken.sol

// pragma solidity >=0.8.4 <0.9.0;

interface IDAOToken {
  function init(
    string memory name,
    string memory symbol,
    address genesis,
    uint256 supply
  ) external returns (bool);

  function totalSupply() external view returns (uint256);

  function calculatePower(address owner) external view returns (uint256);
}


// Dependency file: contracts/interfaces/IRegistry.sol

// pragma solidity >=0.8.4 <0.9.0;

interface IRegistry {
  event Registered(bytes32 domain, bytes32 indexed name, address indexed addr);

  function isExistRecord(bytes32 domain, bytes32 name) external view returns (bool);

  function set(
    bytes32 domain,
    bytes32 name,
    address addr
  ) external returns (bool);

  function batchSet(
    bytes32[] calldata domains,
    bytes32[] calldata names,
    address[] calldata addrs
  ) external returns (bool);

  function getAddress(bytes32 domain, bytes32 name) external view returns (address);

  function getDomainAndName(address addr) external view returns (bytes32, bytes32);
}


// Dependency file: contracts/libraries/RegistryUser.sol

// pragma solidity >=0.8.4 <0.9.0;

// import 'contracts/interfaces/IRegistry.sol';

abstract contract RegistryUser {
  // Registry contract
  IRegistry internal _registry;

  // Active domain
  bytes32 internal _domain;

  // Initialized
  bool private _initialized = false;

  // Allow same domain calls
  modifier onlyAllowSameDomain(bytes32 name) {
    require(msg.sender == _registry.getAddress(_domain, name), 'UserRegistry: Only allow call from same domain');
    _;
  }

  // Allow cross domain call
  modifier onlyAllowCrossDomain(bytes32 fromDomain, bytes32 name) {
    require(
      msg.sender == _registry.getAddress(fromDomain, name),
      'UserRegistry: Only allow call from allowed cross domain'
    );
    _;
  }

  /*******************************************************
   * Internal section
   ********************************************************/

  // Constructing with registry address and its active domain
  function _registryUserInit(address registry_, bytes32 domain_) internal returns (bool) {
    require(!_initialized, "UserRegistry: It's only able to initialize once");
    _registry = IRegistry(registry_);
    _domain = domain_;
    _initialized = true;
    return true;
  }

  // Get address in the same domain
  function _getAddressSameDomain(bytes32 name) internal view returns (address) {
    return _registry.getAddress(_domain, name);
  }

  /*******************************************************
   * View section
   ********************************************************/

  // Return active domain
  function getDomain() external view returns (bytes32) {
    return _domain;
  }

  // Return registry address
  function getRegistry() external view returns (address) {
    return address(_registry);
  }
}


// Root file: contracts/dao/Factory.sol

pragma solidity >=0.8.4 <0.9.0;

// import '/Users/chiro/GitHub/infrastructure/node_modules/@openzeppelin/contracts/proxy/Clones.sol';
// import 'contracts/interfaces/IPool.sol';
// import 'contracts/interfaces/IDAO.sol';
// import 'contracts/interfaces/IDAOToken.sol';
// import 'contracts/libraries/RegistryUser.sol';

/**
 * Factory
 * Name: Factory
 * Domain: Infrastructure
 */
contract Factory is RegistryUser {
  // Use clone lib for address
  using Clones for address;

  // New DAO data
  struct NewDAO {
    bytes32 domain;
    address genesis;
    uint256 supply;
    string name;
    string symbol;
  }

  // Pass constructor parameter to User
  constructor(address registry_, bytes32 domain_) {
    _registryUserInit(registry_, domain_);
  }

  /*******************************************************
   * Same domain section
   ********************************************************/

  function cloneNewDAO(NewDAO calldata creatingDAO) external onlyAllowSameDomain('Infrastructure') returns (bool) {
    // New DAO will be cloned from DKDAO
    address newDAO = _registry.getAddress('Infrastructure', 'DAO').clone();
    bool success = IDAO(newDAO).init(address(_registry), creatingDAO.domain);

    // New DAO Token will be cloned from DKDAOToken
    address newDAOToken = _registry.getAddress('Infrastructure', 'DAOToken').clone();
    success =
      success &&
      IDAOToken(newDAOToken).init(creatingDAO.name, creatingDAO.symbol, creatingDAO.genesis, creatingDAO.supply);

    // New Pool will be clone from
    address newPool = _registry.getAddress('Infrastructure', 'Pool').clone();
    success = success && IPool(newPool).init(address(_registry), creatingDAO.domain);

    require(success, 'Factory: All initialized must be successed');

    return true;
  }
}
