// SPDX-License-Identifier: MIT

/**
 __      __  _____ _______________________________________   
/  \    /  \/  _  \\______   \______   \_   _____/\______ \  
\   \/\/   /  /_\  \|       _/|     ___/|    __)_  |    |  \ 
 \        /    |    \    |   \|    |    |        \ |    `   \
  \__/\  /\____|__  /____|_  /|____|   /_______  //_______  /
       \/         \/       \/                  \/         \/ 
 */

pragma solidity 0.8.18;

import {ERC1155PresetMinterPauser} from "@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";

contract ERC1155Stub is ERC1155PresetMinterPauser {
    constructor()
        ERC1155PresetMinterPauser(
            "https://starlink.mypinata.cloud/ipfs/QmXQm4BDGdhJjPRjiJmSScs7XuRWz6pTRKeuUE2xgBAhFS/"
        )
    // solhint-disable-next-line no-empty-blocks
    {

    }
}
