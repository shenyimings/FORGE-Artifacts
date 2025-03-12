// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../libraries/SwapServiceLib.sol";
import "../../../dependencies/stargate/IStargateLpStaking.sol";
import "../../../dependencies/stargate/IStargatePool.sol";
import "../../../dependencies/stargate/IStargateRouter.sol";

import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

struct StargateStorage {
    IStargateRouter router;
    IStargatePool pool;
    IStargateLpStaking lpStaking;
    IERC20Upgradeable poolDepositToken;
    IERC20Upgradeable lpToken;
    IERC20Upgradeable stgToken;
    uint256 poolId;
    uint256 farmId;
    SwapService swapServiceForStgToken; // $STG is not supported by TraderJoe V2 yet.
    mapping(IERC20Upgradeable => mapping(IERC20Upgradeable => uint256)) binSteps;
}

library StargateStorageLib {
    // keccak256("brokkr.storage.stargate.strategy");
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant storagePosition =
        0x071adf0c31586d6b8e30500aaef8199ce8b6f5b9ab08c1bafcf48809f1191b74;

    function getStorage() internal pure returns (StargateStorage storage ts) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ts.slot := storagePosition
        }
    }
}
