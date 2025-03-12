// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ZNSAddressResolver } from "../../resolver/ZNSAddressResolver.sol";
import { UpgradeMock } from "../UpgradeMock.sol";

 /* solhint-disable */
contract ZNSAddressResolverUpgradeMock is ZNSAddressResolver, UpgradeMock{}
