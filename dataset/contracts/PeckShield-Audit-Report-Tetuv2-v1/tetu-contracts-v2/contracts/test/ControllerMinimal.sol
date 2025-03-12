// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../tools/TetuERC165.sol";
import "../interfaces/IProxyControlled.sol";
import "../interfaces/IController.sol";
import "../lib/InterfaceIds.sol";

contract ControllerMinimal is TetuERC165, IController {

  address public override governance;
  address public override voter;
  address public override liquidator;
  address public override forwarder;
  address public override investFund;
  address public override veDistributor;
  address public override platformVoter;
  address[] public override vaults;
  mapping(address => bool) public operators;

  constructor (address governance_) {
    governance = governance_;
    operators[governance_] = true;
  }

  function setVoter(address _voter) external {
    voter = _voter;
  }

  function setPlatformVoter(address _voter) external {
    platformVoter = _voter;
  }

  function setLiquidator(address value) external {
    liquidator = value;
  }

  function setInvestFund(address value) external {
    investFund = value;
  }

  function setForwarder(address value) external {
    forwarder = value;
  }

  function setVeDistributor(address value) external {
    veDistributor = value;
  }

  function addVault(address vault) external {
    vaults.push(vault);
  }

  function updateProxies(address[] memory proxies, address[] memory newLogics) external {
    require(proxies.length == newLogics.length, "Wrong arrays");
    for (uint i; i < proxies.length; i++) {
      IProxyControlled(proxies[i]).upgrade(newLogics[i]);
    }
  }

  function vaultsList() external view override returns (address[] memory) {
    return vaults;
  }

  function vaultsListLength() external override view returns (uint) {
    return vaults.length;
  }

  function isValidVault(address _vault) external view override returns (bool) {
    for (uint i; i < vaults.length; i++) {
      if (_vault == vaults[i]) {
        return true;
      }
    }
    return false;
  }

  function isOperator(address _adr) external view override returns (bool) {
    return operators[_adr];
  }

  /// @dev See {IERC165-supportsInterface}.
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == InterfaceIds.I_CONTROLLER || super.supportsInterface(interfaceId);
  }

}
