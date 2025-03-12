// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../dependencies/weth/IWETH.sol";
import "../interfaces/IOpenSkySettings.sol";
import "../interfaces/IOpenSkyPool.sol";
import "../interfaces/IOpenSkyLoan.sol";
import "hardhat/console.sol";

contract OpenSkyLoanHelper is ERC721Holder {
    IWETH public immutable WETH;
    IOpenSkySettings public immutable SETTINGS;

    event Received(address indexed sender, uint256 amount);

    constructor(IWETH weth, IOpenSkySettings settings) {
        WETH = weth;
        SETTINGS = settings;
    }

    function repay(uint256 loanId) external payable {
        IOpenSkyLoan loanNFT = IOpenSkyLoan(SETTINGS.loanAddress());
        loanNFT.safeTransferFrom(msg.sender, address(this), loanId);

        WETH.deposit{value: msg.value}();
        
        WETH.approve(SETTINGS.poolAddress(), msg.value);

        IOpenSkyPool pool = IOpenSkyPool(SETTINGS.poolAddress());

        DataTypes.LoanData memory loan = loanNFT.getLoanData(loanId);

        DataTypes.WhitelistInfo memory whitelistInfo = SETTINGS.getWhitelistDetail(loan.reserveId, loan.nftAddress);
        pool.extend(loanId, 0.01 ether, whitelistInfo.minBorrowDuration, address(this));

        pool.repay(loanNFT.getLoanId(loan.nftAddress, loan.tokenId));

        uint256 refundAmount = WETH.balanceOf(address(this));
        if (refundAmount > 0) {
            WETH.withdraw(refundAmount);
            _safeTransferETH(msg.sender, refundAmount);
        }

        IERC721(loan.nftAddress).safeTransferFrom(address(this), msg.sender, loan.tokenId);
    }

    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "ETH_TRANSFER_FAILED");
    }

    receive() external payable {
        require(msg.sender == address(WETH), "RECEIVE_NOT_ALLOWED");
        emit Received(msg.sender, msg.value);
    }

}