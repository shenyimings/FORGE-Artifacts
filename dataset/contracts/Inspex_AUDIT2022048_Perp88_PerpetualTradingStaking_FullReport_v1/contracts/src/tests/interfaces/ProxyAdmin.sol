// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

interface ProxyAdmin {
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );

  function changeProxyAdmin(address proxy, address newAdmin) external;

  function getProxyAdmin(address proxy) external view returns (address);

  function getProxyImplementation(address proxy)
    external
    view
    returns (address);

  function owner() external view returns (address);

  function renounceOwnership() external;

  function transferOwnership(address newOwner) external;

  function upgrade(address proxy, address implementation) external;

  function upgradeAndCall(
    address proxy,
    address implementation,
    bytes memory data
  ) external payable;
}
