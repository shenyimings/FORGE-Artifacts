// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import './interfaces/IResetAccountConnector.sol';
import '../modules/FoldingAccount/FoldingAccountStorage.sol';
import '../modules/StopLoss/StopLossStorage.sol';
import '../modules/PNL/PNLStorage.sol';

contract ResetAccountConnector is IResetAccountConnector, FoldingAccountStorage, StopLossStorage, PNLStorage {
    ///@dev Reference to the NFT that is allowed to reset this account
    address immutable ownershipNFT;

    constructor(address _nft) public {
        ownershipNFT = _nft;
    }

    function resetAccount(
        address oldOwner,
        address newOwner,
        uint256
    ) external override {
        require(msg.sender == ownershipNFT, 'FA3');

        emit OwnerChanged(aStore().owner, newOwner);
        aStore().owner = newOwner;
        if (oldOwner != address(0)) {
            StopLossStore storage store = stopLossStore();
            store.unwindFactor = 0;
            store.slippageIncentive = 0;
            store.collateralUsageLimit = 0;

            delete pnlStore().pnlSettings;
        }
    }
}
