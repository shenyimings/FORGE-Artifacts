// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract ExecutorTransferMock is ERC721Holder, ERC1155Holder {
    address public govAddress;
    address public mock20Address;

    uint256 public amount20;

    constructor(address _govAddress, address _mock20Address) {
        govAddress = _govAddress;
        mock20Address = _mock20Address;
    }

    function setTransferAmount(uint256 _amount20) external {
        amount20 = _amount20;
    }

    function execute() external payable {
        address _govAddress = govAddress;

        if (amount20 > 0) {
            IERC20(mock20Address).transferFrom(_govAddress, address(this), amount20);
        }
    }
}
