// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '../connectors/interfaces/IResetAccountConnector.sol';
import '../core/FodlNFT.sol';

contract FodlNFTAccountMock is IResetAccountConnector {
    function resetAccount(
        address,
        address,
        uint256
    ) external override {
        return;
    }

    function changeTokenUri(address nft, string memory newUri) external {
        FodlNFT(nft).setTokenUri(newUri);
    }
}
