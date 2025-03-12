// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../../interfaces/IPriceOracle.sol";
import "../../libraries/SwapServiceLib.sol";

import "../../../dependencies/vector/IVectorPoolHelperJoe.sol";
import "../../../dependencies/pangolin/IPangolinMiniChef.sol";
import "../../../dependencies/pangolin/IPangolinPair.sol";
import "../../../dependencies/pangolin/IPangolinRouter.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/core-v3/contracts/misc/AaveProtocolDataProvider.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoeRouter02.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoePair.sol";

struct DnsVectorStorage {
    uint256 safetyFactor;
    IERC20Upgradeable aaveSupplyToken;
    IERC20Upgradeable aAaveSupplyToken;
    ERC20Upgradeable aaveBorrowToken;
    IERC20Upgradeable vAaveBorrowToken;
    IERC20Upgradeable ammPairDepositToken;
    IERC20Upgradeable joeToken; // Obsolete.
    IPool aavePool;
    AaveProtocolDataProvider aaveProtocolDataProvider;
    IJoeRouter02 traderJoeRouter; // Obsolete.
    IJoePair traderJoePair; // Obsolete.
    IVectorPoolHelperJoe vectorPoolHelperJoe; // Obsolete.
    IPriceOracle priceOracle; // To be used in library without receiving extra parameters.
    SwapService swapService; // To be used in library without receiving extra parameters.
    IERC20Upgradeable depositToken; // To be used in library without receiving extra parameters.
    IERC20Upgradeable pngToken;
    IPangolinRouter pangolinRouter;
    IPangolinMiniChef pangolinMiniChef;
    IPangolinPair pangolinPair;
    uint256 pangolinPoolId;
}

library DnsVectorStorageLib {
    // keccak256("brokkr.storage.dns.vector.strategy");
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant storagePosition =
        0x4237030a40a92a0fc4b8b6a6ef53b6cec5c13de00b648c0968c3070e93d90ada;

    function getStorage() internal pure returns (DnsVectorStorage storage ts) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ts.slot := storagePosition
        }
    }
}
