// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ZNSCurvePricer } from "../../price/ZNSCurvePricer.sol";
import { UpgradeMock } from "../UpgradeMock.sol";


// solhint-disable-next-line no-empty-blocks
contract ZNSCurvePricerUpgradeMock is ZNSCurvePricer, UpgradeMock {}
