// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../../interfaces/gov/proposals/ITokenSaleProposal.sol";
import "../../interfaces/gov/IGovPool.sol";

contract GovTokenSaleAttackerMock {
    function attackExecuteUnlockToken(
        IGovPool govPool,
        uint256 proposalId,
        ITokenSaleProposal tokenSale,
        uint256 tierId,
        address tokenToFlashloan,
        uint256 amount
    ) external {
        IERC20(tokenToFlashloan).approve(address(tokenSale), amount);
        tokenSale.lockParticipationTokens(tierId, tokenToFlashloan, amount);
        govPool.execute(proposalId);
        tokenSale.unlockParticipationTokens(tierId, tokenToFlashloan, amount);
    }

    function attackExecuteUnlockNft(
        IGovPool govPool,
        uint256 proposalId,
        ITokenSaleProposal tokenSale,
        uint256 tierId,
        address nftToFlashloan,
        uint256[] calldata ids
    ) external {
        IERC721(nftToFlashloan).setApprovalForAll(address(tokenSale), true);
        tokenSale.lockParticipationNft(tierId, nftToFlashloan, ids);
        govPool.execute(proposalId);
        tokenSale.unlockParticipationNft(tierId, nftToFlashloan, ids);
    }
}
