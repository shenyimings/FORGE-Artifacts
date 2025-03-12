// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';

import '../dependencies/cryptopunk/ICryptoPunk.sol';
import '../dependencies/cryptopunk/IWrappedPunk.sol';

import '../interfaces/IOpenSkySettings.sol';
import '../interfaces/IOpenSkyPool.sol';
import '../interfaces/IOpenSkyLoan.sol';
import '../interfaces/IOpenSkyPunkGateway.sol';

import '../libraries/types/DataTypes.sol';

contract OpenSkyPunkGateway is Context, ERC721Holder, IOpenSkyPunkGateway {
    IOpenSkySettings public SETTINGS;
    ICryptoPunk public PUNK;
    IWrappedPunk public WPUNK;

    address public WPUNK_PROXY_ADDRESS;

    constructor(
        address SETTINGS_,
        address PUNK_,
        address WPUNK_
    ) {
        SETTINGS = IOpenSkySettings(SETTINGS_);
        PUNK = ICryptoPunk(PUNK_);
        WPUNK = IWrappedPunk(WPUNK_);

        WPUNK.registerProxy();
        WPUNK_PROXY_ADDRESS = WPUNK.proxyInfo(address(this));

        IERC721(address(WPUNK)).setApprovalForAll(SETTINGS.poolAddress(), true);
    }

    // Gateway borrow from pool onbehalf of sender
    function borrow(
        uint256 reserveId,
        uint256 amount,
        uint256 duration,
        uint256 punkIndex
    ) external override {
        address owner = PUNK.punkIndexToAddress(punkIndex);
        require(owner == _msgSender(), 'DEPOSIT_PUNK_NOT_OWNER_OF_PUNK');

        // deposit punk
        PUNK.buyPunk(punkIndex);
        PUNK.transferPunk(WPUNK_PROXY_ADDRESS, punkIndex);
        WPUNK.mint(punkIndex);

        // borrow
       uint256 loanId =  IOpenSkyPool(SETTINGS.poolAddress()).borrow(
            reserveId,
            amount,
            duration,
            address(WPUNK),
            punkIndex,
            _msgSender()
        );

        emit Borrow(reserveId, owner, amount, duration, punkIndex, loanId);
    }

    // Only loan nft owner can repay
    function repay(uint256 loanId) external payable override {
        IOpenSkyLoan loanNFT = IOpenSkyLoan(SETTINGS.loanAddress());
        DataTypes.LoanData memory loanData = loanNFT.getLoanData(loanId);
        address owner = IERC721(SETTINGS.loanAddress()).ownerOf(loanId);
        require(_msgSender() == owner, 'REPAY_USER_NOT_OWN_THE_LOAN');
        require(loanData.nftAddress == address(WPUNK), 'REPAY_NOT_A_PUNK_LOAN');

        IOpenSkyPool(SETTINGS.poolAddress()).repay{value: msg.value}(loanId);

        //withdrawPunk
        WPUNK.burn(loanData.tokenId);
        PUNK.transferPunk(owner, loanData.tokenId);

        emit Repay(loanData.reserveId, _msgSender(), loanData.tokenId, loanId);
    }

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
