// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '@openzeppelin/contracts/proxy/Clones.sol';
import '../interfaces/IPool.sol';
import '../interfaces/IDAO.sol';
import '../interfaces/IDAOToken.sol';
import '../libraries/RegistryUser.sol';

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
