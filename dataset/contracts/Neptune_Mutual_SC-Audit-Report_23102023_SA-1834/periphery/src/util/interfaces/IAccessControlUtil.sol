// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

interface IAccessControlUtil {
  struct AccountWithRoles {
    address account;
    bytes32[] roles;
  }

  function grantRoles(AccountWithRoles[] calldata detail) external;
}
