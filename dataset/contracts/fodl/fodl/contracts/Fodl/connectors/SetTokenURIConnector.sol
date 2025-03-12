// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '../modules/FoldingAccount/FoldingAccountStorage.sol';
import '../core/interfaces/IFodlNFTProvider.sol';
import '../core/interfaces/IFodlNFT.sol';

contract SetTokenURIConnector is FoldingAccountStorage {
    string private constant ETH_SIGN_PREFIX = '\x19Ethereum Signed Message:\n32';

    address public immutable authoriser;

    constructor(address _authoriser) public {
        authoriser = _authoriser;
    }

    function setTokenURI(
        string memory tokenURI,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external onlyAccountOwner {
        bytes32 h = keccak256(abi.encodePacked(ETH_SIGN_PREFIX, keccak256(abi.encodePacked(address(this), tokenURI))));
        require(ecrecover(h, v, r, s) == authoriser, 'Invalid authoriser signature');

        IFodlNFT(IFodlNFTProvider(aStore().foldingRegistry).fodlNFT()).setTokenUri(tokenURI);
    }
}
