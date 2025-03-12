// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

/*
 _____ _         _____               
|     |_|___ ___|   __|_ _ _ ___ ___ 
| | | | |   | . |__   | | | | .'| . |
|_|_|_|_|_|_|___|_____|_____|__,|  _|
                                |_| 
*
* MIT License
* ===========
*
* Copyright (c) 2022 MinoSwap
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE

*/

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IIFCPool.sol";

contract IFC is ERC1155Supply, Ownable {

    mapping (uint => uint) public maxSupply;

    IIFCPool public ifcPool;

    constructor() ERC1155("https://api.minoswap.finance/metadata/{id}") {
        maxSupply[0] = 30;
        maxSupply[1] = 30;
        maxSupply[2] = 60;
        maxSupply[3] = 60;
        maxSupply[4] = 400;
        maxSupply[5] = 400;

        _mint(msg.sender, 0, 30, "");
        _mint(msg.sender, 1, 30, "");
        _mint(msg.sender, 2, 60, "");
        _mint(msg.sender, 3, 60, "");
        _mint(msg.sender, 4, 400, "");
        _mint(msg.sender, 5, 400, "");
    }

    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        super._afterTokenTransfer(operator, from, to, ids, amounts, data);
        if (address(ifcPool) != address(0)) {
            ifcPool.updateRewardDebtAfterTransfer(from, to);
        } 
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        ERC1155Supply._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        if (address(ifcPool) != address(0)) {
            ifcPool.sendRewardBeforeTransfer(from, to);
        }
    }

    function setIfcPool(address _ifcPool) external onlyOwner {
        require(address(ifcPool) == address(0));
        ifcPool = IIFCPool(_ifcPool);
    }
}
