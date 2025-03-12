// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ERC20BondingCurveL.sol";
import "./GumbarL.sol";
import "./Gumball.sol";

interface IGumbarL {
  function addReward(address _rewardsToken, address _rewardsDistributor) external;
  function setRewardsDistributor(address _rewardsToken, address _rewardsDistributor) external;
  function nominateNewOwner(address _owner) external;
  function acceptOwnership() external;
}

contract Factory is Ownable, ReentrancyGuardUpgradeable {

  address public tokenLibraryAddress;
  address public gumballLibraryAddress;

  address[] public tokensDeployed; 
  address[] public gumballsDeployed;
  bool[] public whitelist;

  mapping (address => bool) whitelisted;

  event ProxiesDeployed(address tokenProxy, address gumballProxy, address gumbar, address tokenLibrary, address gumballLibrary);
  event UpdateTokenLibrary(address newLibraryAddress);
  event UpdateNftLibrary(address newLibraryAddress);
  event WhitelistExisting(uint256 index, bool _bool);
  event FactoryWhitelistUpdate(address factory, bool flag);

  constructor (address _tokenLibraryAddress, address _gumballLibraryAddress) {
    tokenLibraryAddress = _tokenLibraryAddress;
    gumballLibraryAddress = _gumballLibraryAddress;
  }

  function deployInfo(uint256 id) public view returns (address token, address nft, bool _whitelist) {
    return (tokensDeployed[id], gumballsDeployed[id], whitelist[id]);
  }

  function totalDeployed() public view returns (uint256 length) {
    return tokensDeployed.length;
  }

  function deployProxies(string memory name, string memory symbol, string[] memory _URIs, uint256 _supplyCap, uint256 _init_vBase, address _baseToken, address _artist, uint256 _delay) public nonReentrant {
    require(bytes(name).length != 0 && bytes(symbol).length != 0 && bytes(_URIs[0]).length != 0 && bytes(_URIs[1]).length != 0, "Incomplete name, symbol or URI");
    require(_URIs.length == 2 && _supplyCap >= 1 && _init_vBase >=1, "Invalid URI length, supply or virtual base");
    require(_baseToken != address(0) && _artist != address(0), "Base token or artist cannot be zero address");
    require(_delay <= 1209600, "14 day max");

    address tokenClone = createProxy(tokenLibraryAddress);
    address gumballClone = createProxy(gumballLibraryAddress);

    address gumbarAddr = address(deployGumbar(address(this), tokenClone, gumballClone, _baseToken));

    ERC20BondingCurveL(tokenClone).initialize(
      name, 
      symbol,
      _baseToken,
      _init_vBase,
      _supplyCap, 
      gumballClone,
      gumbarAddr,
      _artist,
      _delay
    );

    string memory gumballName = string(abi.encodePacked(name));
    string memory gumballSymbol = string(abi.encodePacked(symbol)); 

    Gumball(gumballClone).initialize(
      gumballName, 
      gumballSymbol, 
      _URIs,
      tokenClone
      );

    tokensDeployed.push(tokenClone);
    gumballsDeployed.push(gumballClone);

    if (whitelisted[msg.sender]) {
      whitelist.push(true);
    } else {
      whitelist.push(false);
    }

    emit ProxiesDeployed(tokenClone, gumballClone, gumbarAddr, tokenLibraryAddress, gumballLibraryAddress);
  }

  function updateTokenLibrary(address _tokenLibraryAddress) public onlyOwner {
    tokenLibraryAddress = _tokenLibraryAddress;

    emit UpdateTokenLibrary(_tokenLibraryAddress);
  }

  function updateNFTLibrary(address _gumballLibraryAddress) public onlyOwner {
    gumballLibraryAddress = _gumballLibraryAddress;

    emit UpdateNftLibrary(_gumballLibraryAddress);
  }

  function deployGumbar(address _owner, address _nativeToken, address _gumball, address _baseToken) internal returns (address) {
    GumbarL gumbar = new GumbarL(_owner, _nativeToken, _gumball, _baseToken);
    return address(gumbar);
  }

  function createProxy(address target) internal returns (address result) {
    bytes20 targetBytes = bytes20(target);
    assembly {
      let clone := mload(0x40)
      mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
      mstore(add(clone, 0x14), targetBytes)
      mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
      result := create(0, clone, 0x37)
    }
  }

  function addOrRemoveFactoryWhitelist(address _addr, bool _bool) external onlyOwner {
    whitelisted[_addr] = _bool;
    
    emit FactoryWhitelistUpdate(_addr, _bool);
  }

  function whitelistExisting(uint256 _index, bool _bool) external onlyOwner {
    whitelist[_index] = _bool;

    emit WhitelistExisting(_index, _bool);
  }

  function getOwner() public view returns (address) {
    return owner();
  }

  function addReward(address _gumbarAddr, address _rewardsToken, address _rewardsDistributor) external onlyOwner {
    IGumbarL(_gumbarAddr).addReward(_rewardsToken, _rewardsDistributor);
  }

  function setRewardsDistributor(address _gumbarAddr, address _rewardsToken, address _rewardsDistributor) external onlyOwner {
    IGumbarL(_gumbarAddr).setRewardsDistributor(_rewardsToken, _rewardsDistributor);
  }

  function nominateOwnerForGumbar(address _gumbarAddr, address _newOwner) external onlyOwner {
    IGumbarL(_gumbarAddr).nominateNewOwner(_newOwner);
  }

  function acceptNewOwnershipForGumbar(address _gumbarAddr) external onlyOwner {
    IGumbarL(_gumbarAddr).acceptOwnership();
  }
}