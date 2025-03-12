// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../libraries/SwapServiceLib.sol";
import "../../../dependencies/traderjoe/ITraderJoeLBPair.sol";
import "../../../dependencies/traderjoe/ITraderJoeLBRouter.sol";
import "../../../dependencies/traderjoe/ITraderJoeMasterChef.sol";
import "../../../dependencies/traderjoe/ITraderJoePair.sol";
import "../../../dependencies/traderjoe/ITraderJoeRouter.sol";

import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

struct TraderJoeStorage {
    ITraderJoeRouter router; // Obsolete.
    ITraderJoeMasterChef masterChef; // Obsolete.
    IERC20Upgradeable pairDepositToken;
    ITraderJoePair lpToken; // Obsolete.
    IERC20Upgradeable joeToken; // Obsolete.
    uint256 farmId; // Obsolete.
    IERC20Upgradeable depositToken; // To make it accessible from other libraries.
    SwapService swapService; // To make it accessible from other libraries.
    ITraderJoeLBPair lbPair;
    ITraderJoeLBRouter lbRouter;
    IERC20Upgradeable tokenX;
    IERC20Upgradeable tokenY;
    uint256 binStep;
    uint256[] binIds;
    uint256[] binAllocations;
}

library TraderJoeStorageLib {
    // keccak256("brokkr.storage.traderjoe.strategy");
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant storagePosition =
        0x2c18a668c6ed16d1abb08a50aa4bef7a42b8953231af749500b07f3b5a121f25;

    function getStorage() internal pure returns (TraderJoeStorage storage ts) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ts.slot := storagePosition
        }
    }
}
