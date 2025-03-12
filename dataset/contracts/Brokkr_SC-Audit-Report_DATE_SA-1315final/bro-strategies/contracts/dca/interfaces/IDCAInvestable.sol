// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IDCA } from "./IDCA.sol";
import { IDCAFor } from "./IDCAFor.sol";
import { IDCAEquity } from "./IDCAEquity.sol";
import { IDCALimits } from "./IDCALimits.sol";
import { IDCAStatus } from "./IDCAStatus.sol";

interface IDCAInvestable is IDCA, IDCAFor, IDCAEquity, IDCALimits, IDCAStatus {}
