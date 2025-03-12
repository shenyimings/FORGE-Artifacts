// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { AppStorage } from "./AppStorage.sol";
import { LibObject } from "./libs/LibObject.sol";
import { LibHelpers } from "./libs/LibHelpers.sol";
import { LibConstants } from "./libs/LibConstants.sol";
import { LibAdmin } from "./libs/LibAdmin.sol";
import { LibACL } from "./libs/LibACL.sol";

contract InitDiamond {
    AppStorage internal s;

    event InitializeDiamond(address sender, bytes32 systemManager);

    function initialize() external {
        // Initial total supply of NAYM
        s.totalSupply = 1_000_000_000e18;
        s.balances[msg.sender] = s.totalSupply;

        LibACL._updateRoleGroup(LibConstants.ROLE_SYSTEM_ADMIN, LibConstants.GROUP_SYSTEM_ADMINS, true);
        LibACL._updateRoleGroup(LibConstants.ROLE_SYSTEM_ADMIN, LibConstants.GROUP_SYSTEM_MANAGERS, true);
        LibACL._updateRoleGroup(LibConstants.ROLE_SYSTEM_MANAGER, LibConstants.GROUP_SYSTEM_MANAGERS, true);
        LibACL._updateRoleGroup(LibConstants.ROLE_ENTITY_ADMIN, LibConstants.GROUP_ENTITY_ADMINS, true);
        LibACL._updateRoleGroup(LibConstants.ROLE_ENTITY_MANAGER, LibConstants.GROUP_ENTITY_MANAGERS, true);
        LibACL._updateRoleGroup(LibConstants.ROLE_BROKER, LibConstants.GROUP_BROKERS, true);
        LibACL._updateRoleGroup(LibConstants.ROLE_UNDERWRITER, LibConstants.GROUP_UNDERWRITERS, true);
        LibACL._updateRoleGroup(LibConstants.ROLE_INSURED_PARTY, LibConstants.GROUP_INSURED_PARTIES, true);
        LibACL._updateRoleGroup(LibConstants.ROLE_CAPITAL_PROVIDER, LibConstants.GROUP_CAPITAL_PROVIDERS, true);
        LibACL._updateRoleGroup(LibConstants.ROLE_CLAIMS_ADMIN, LibConstants.GROUP_CLAIMS_ADMINS, true);
        LibACL._updateRoleGroup(LibConstants.ROLE_TRADER, LibConstants.GROUP_TRADERS, true);
        LibACL._updateRoleGroup(LibConstants.ROLE_SEGREGATED_ACCOUNT, LibConstants.GROUP_SEGREGATED_ACCOUNTS, true);
        LibACL._updateRoleGroup(LibConstants.ROLE_SERVICE_PROVIDER, LibConstants.GROUP_SERVICE_PROVIDERS, true);
        LibACL._updateRoleGroup(LibConstants.ROLE_BROKER, LibConstants.GROUP_POLICY_HANDLERS, true);
        LibACL._updateRoleGroup(LibConstants.ROLE_INSURED_PARTY, LibConstants.GROUP_POLICY_HANDLERS, true);

        LibACL._updateRoleAssigner(LibConstants.ROLE_SYSTEM_ADMIN, LibConstants.GROUP_SYSTEM_ADMINS);
        LibACL._updateRoleAssigner(LibConstants.ROLE_SYSTEM_MANAGER, LibConstants.GROUP_SYSTEM_MANAGERS);
        LibACL._updateRoleAssigner(LibConstants.ROLE_ENTITY_ADMIN, LibConstants.GROUP_SYSTEM_MANAGERS);
        LibACL._updateRoleAssigner(LibConstants.ROLE_ENTITY_MANAGER, LibConstants.GROUP_SYSTEM_MANAGERS);
        LibACL._updateRoleAssigner(LibConstants.ROLE_BROKER, LibConstants.GROUP_SYSTEM_MANAGERS);
        LibACL._updateRoleAssigner(LibConstants.ROLE_UNDERWRITER, LibConstants.GROUP_SYSTEM_MANAGERS);
        LibACL._updateRoleAssigner(LibConstants.ROLE_INSURED_PARTY, LibConstants.GROUP_SYSTEM_MANAGERS);
        LibACL._updateRoleAssigner(LibConstants.ROLE_CAPITAL_PROVIDER, LibConstants.GROUP_SYSTEM_MANAGERS);
        LibACL._updateRoleAssigner(LibConstants.ROLE_BROKER, LibConstants.GROUP_SYSTEM_MANAGERS);
        LibACL._updateRoleAssigner(LibConstants.ROLE_INSURED_PARTY, LibConstants.GROUP_SYSTEM_MANAGERS);
        LibACL._updateRoleAssigner(LibConstants.ROLE_UNDERWRITER, LibConstants.GROUP_SYSTEM_MANAGERS);
        LibACL._updateRoleAssigner(LibConstants.ROLE_CLAIMS_ADMIN, LibConstants.GROUP_SYSTEM_MANAGERS);
        LibACL._updateRoleAssigner(LibConstants.ROLE_TRADER, LibConstants.GROUP_SYSTEM_MANAGERS);
        LibACL._updateRoleAssigner(LibConstants.ROLE_SEGREGATED_ACCOUNT, LibConstants.GROUP_SYSTEM_MANAGERS);
        LibACL._updateRoleAssigner(LibConstants.ROLE_SERVICE_PROVIDER, LibConstants.GROUP_SYSTEM_MANAGERS);

        // dissalow creating an object with ID of 0
        s.existingObjects[0] = true;

        // assign msg.sender as a Nayms System Admin
        bytes32 userId = LibHelpers._getIdForAddress(msg.sender);
        s.existingObjects[userId] = true;

        LibACL._assignRole(userId, LibAdmin._getSystemId(), LibHelpers._stringToBytes32(LibConstants.ROLE_SYSTEM_ADMIN));

        // Set Commissions (all are in basis points)
        s.tradingCommissionTotalBP = 40;
        s.tradingCommissionNaymsLtdBP = 5000;
        s.tradingCommissionNDFBP = 2500;
        s.tradingCommissionSTMBP = 2500;
        s.tradingCommissionMakerBP; // init 0

        s.premiumCommissionNaymsLtdBP = 40;
        s.premiumCommissionNDFBP = 40;
        s.premiumCommissionSTMBP = 40;

        s.naymsTokenId = LibHelpers._getIdForAddress(address(this));
        s.naymsToken = address(this);
        s.maxDividendDenominations = 1;
        s.targetNaymsAllocation = 20;
        s.equilibriumLevel = 20;
        s.maxDiscount = 10;
        s.discountToken = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; //wETH
        s.poolFee = 3000;
        s.lpAddress = 0x7a25c38594D8EA261B6C5f76b0024249e95Efe1C;
        emit InitializeDiamond(msg.sender, userId);
    }
}
