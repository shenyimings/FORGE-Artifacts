// SPDX-License-Identifier: MIT



//  ██████╗ ██████╗ ███╗   ███╗██╗   ██╗███████╗     ██████╗ ██████╗ ██╗███╗   ██╗
// ██╔════╝██╔═══██╗████╗ ████║╚██╗ ██╔╝╚══███╔╝    ██╔════╝██╔═══██╗██║████╗  ██║
// ██║     ██║   ██║██╔████╔██║ ╚████╔╝   ███╔╝     ██║     ██║   ██║██║██╔██╗ ██║
// ██║     ██║   ██║██║╚██╔╝██║  ╚██╔╝   ███╔╝      ██║     ██║   ██║██║██║╚██╗██║
// ╚██████╗╚██████╔╝██║ ╚═╝ ██║   ██║   ███████╗    ╚██████╗╚██████╔╝██║██║ ╚████║
//  ╚═════╝ ╚═════╝ ╚═╝     ╚═╝   ╚═╝   ╚══════╝     ╚═════╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝

// https://www.comyz.org
// https://www.twitter.com/ComyzCoin
// https://www.t.me/ComyzCoin
// 40% presale on PinkSale, follow us on Twitter for more info.

pragma solidity ^0.8.7;

import "./Comyz.sol";

contract ComyzSupply is Comyz {
  constructor() Comyz('Comyz Coin', 'CMZ') {
    _mint(msg.sender, 1000000000 * 10 ** 18);
  }
}
