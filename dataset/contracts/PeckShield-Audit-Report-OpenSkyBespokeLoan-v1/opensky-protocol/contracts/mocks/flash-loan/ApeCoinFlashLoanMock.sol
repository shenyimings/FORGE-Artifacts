// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../../interfaces/IOpenSkyFlashClaimReceiver.sol';
import './ApeCoinMock.sol';

contract ApeCoinFlashLoanMock is IOpenSkyFlashClaimReceiver, ERC721Holder {
    address public immutable apeCoinAirdropAddress;

    constructor(address _apeCoinAirdropAddress) {
        apeCoinAirdropAddress = _apeCoinAirdropAddress;
    }

    function executeOperation(
        address[] calldata nftAddresses,
        uint256[] calldata tokenIds,
        address initiator,
        address operator,
        bytes calldata params
    ) external override returns (bool) {
        params;

        require(nftAddresses.length != 0 && nftAddresses.length == tokenIds.length, 'PARAMS_ERROR');
        require(initiator != address(0));
        require(operator != address(0));

        for (uint256 i = 0; i < nftAddresses.length; i++) {
            IAirdrop(apeCoinAirdropAddress).claimRewards(tokenIds[i], initiator);

            IERC721(nftAddresses[i]).approve(operator, tokenIds[i]);
        }

        return true;
    }

}