// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import '../libraries/BespokeTypes.sol';

contract StrategyTokenId {
    function validate(BespokeTypes.Offer memory offerData, BespokeTypes.TakeLendInfoForStrategy memory takeInfo)
        external
        view
    {
        require(offerData.nonceMaxTimes == 1, 'BM_STRATEGY_TOKEN_ID_NONCE_MAXTIMES_INVALID');
        require(offerData.tokenId == takeInfo.tokenId, 'BM_STRATEGY_TOKEN_ID_NOT_MATCH');
    }
}
