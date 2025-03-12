pragma solidity ^0.8.3;

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Hegic
 * Copyright (C) 2022 Hegic Protocol
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

import "@hegic/utils/contracts/ERC20Recovery.sol";
import "../Pool/HegicStakeAndCover.sol";

contract HegicStakeAndCoverDistributor is Ownable, ERC20Recovery {
    HegicStakeAndCover public immutable sac;

    struct TransferItem {
        address account;
        uint256 amount;
    }

    constructor(HegicStakeAndCover _sac) {
        sac = _sac;
    }

    function distribute(TransferItem[] calldata transfers) external onlyOwner {
        if (sac.profitOf(address(this)) > 0) sac.claimProfit();
        for (uint32 i; i < transfers.length; i++) {
            TransferItem memory ti = transfers[i];
            sac.transferShare(ti.account, ti.amount);
        }
    }
}
