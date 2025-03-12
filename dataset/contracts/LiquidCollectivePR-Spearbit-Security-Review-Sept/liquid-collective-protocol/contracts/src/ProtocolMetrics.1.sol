//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {ISharesManagerV1} from "./interfaces/components/ISharesManager.1.sol";
import {Initializable} from "./Initializable.sol";
import {RiverAddress} from "./state/shared/RiverAddress.sol";

contract ProtocolMetricsV1 is Initializable {
    function initProtocolMetricsV1(address river) external init(0) {
        RiverAddress.set(river);
    }

    // @dev Returns an 18 decimal fixed point number that is the exchange rate of the token to some other underlying
    //      token. The meaning of this rate depends on the context.
    function getRate() external view returns (uint256) {
        return ISharesManagerV1(RiverAddress.get()).underlyingBalanceFromShares(1e18);
    }
}
