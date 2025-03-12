// `7MM"""Yp,   .g8""8q. `7MMF'      `7MM"""Yb.       `7MM"""Mq.   .g8""8q. `7MMF'`7MN.   `7MF'MMP""MM""YMM 
//   MM    Yb .dP'    `YM. MM          MM    `Yb.       MM   `MM..dP'    `YM. MM    MMN.    M  P'   MM   `7 
//   MM    dP dM'      `MM MM          MM     `Mb       MM   ,M9 dM'      `MM MM    M YMb   M       MM      
//   MM"""bg. MM        MM MM          MM      MM       MMmmdM9  MM        MM MM    M  `MN. M       MM      
//   MM    `Y MM.      ,MP MM      ,   MM     ,MP       MM       MM.      ,MP MM    M   `MM.M       MM      
//   MM    ,9 `Mb.    ,dP' MM     ,M   MM    ,dP'       MM       `Mb.    ,dP' MM    M     YMM       MM      
// .JMMmmmd9    `"bmmd"' .JMMmmmmMMM .JMMmmmdP'       .JMML.       `"bmmd"' .JMML..JML.    YM     .JMML.    


// SPDX-License-Identifier: MIT
// solhint-disable func-visibility
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";                                                                                                         
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BoldPointToken is ERC20, ERC20Burnable, ERC20Permit, ERC20Pausable, Ownable {
    constructor() ERC20("Bold Point Token", "BPT") ERC20Permit("Bold Point Token") {
        _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}